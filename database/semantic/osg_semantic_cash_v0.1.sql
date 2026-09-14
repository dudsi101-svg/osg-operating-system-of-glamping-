-- OSG Cash semantic layer v0.1
-- Cash truth is deliberately separate from economic/accounting truth.

create or replace view osg_cash_leg as
select
  cm.organization_id,
  cm.id as cash_movement_id,
  cm.occurred_at,
  cm.currency,
  cm.status,
  cm.external_reference,
  cm.from_money_account_id as money_account_id,
  -cm.amount as signed_amount,
  'OUT'::text as direction
from cash_movement cm
where cm.from_money_account_id is not null
  and cm.status <> 'IGNORED'

union all

select
  cm.organization_id,
  cm.id,
  cm.occurred_at,
  cm.currency,
  cm.status,
  cm.external_reference,
  cm.to_money_account_id,
  cm.amount,
  'IN'::text
from cash_movement cm
where cm.to_money_account_id is not null
  and cm.status <> 'IGNORED';

create or replace view osg_money_account_balance as
select
  ma.organization_id,
  ma.property_id,
  ma.id as money_account_id,
  ma.name,
  ma.account_type,
  ma.currency,
  coalesce(sum(cl.signed_amount) filter (where cl.status in ('IMPORTED','VERIFIED')),0) as calculated_balance_delta
from money_account ma
left join osg_cash_leg cl
  on cl.organization_id = ma.organization_id
 and cl.money_account_id = ma.id
 and cl.currency = ma.currency
group by ma.organization_id, ma.property_id, ma.id, ma.name, ma.account_type, ma.currency;

create or replace function osg_property_cash_flow(
  p_property_id uuid,
  p_from_ts timestamptz,
  p_to_ts timestamptz
)
returns table (
  property_id uuid,
  cash_in numeric,
  cash_out numeric,
  net_cash_change numeric
)
language sql
stable
as $$
  select
    p_property_id,
    coalesce(sum(cl.signed_amount) filter (where cl.signed_amount > 0),0),
    coalesce(sum(-cl.signed_amount) filter (where cl.signed_amount < 0),0),
    coalesce(sum(cl.signed_amount),0)
  from osg_cash_leg cl
  join money_account ma
    on ma.organization_id = cl.organization_id
   and ma.id = cl.money_account_id
  where ma.property_id = p_property_id
    and cl.occurred_at >= p_from_ts
    and cl.occurred_at < p_to_ts
    and cl.status in ('IMPORTED','VERIFIED');
$$;

-- Internal transfer caveat:
-- Summing legs across every account belonging to the same property nets internal
-- transfers to zero. Filtering to only one bank/cash account intentionally shows
-- that account's movement, not business cash flow.
--
-- CashMovement never becomes revenue/cost solely because money moved.
