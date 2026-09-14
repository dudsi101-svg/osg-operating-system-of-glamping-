-- OSG Financial Truth semantic layer v0.2
-- PRE-FREEZE reference SQL. Requires v0.98 economic direction patch.
-- Managerial economic result is driven by POSTED EconomicEvent Allocations,
-- not by FinancialDocument totals and not by CashMovement.

-- -----------------------------------------------------------------
-- Canonical allocation fact
-- -----------------------------------------------------------------
create or replace view osg_allocation_fact as
select
  a.organization_id,
  a.id as allocation_id,
  a.economic_event_id,
  ee.property_id as event_property_id,
  a.property_id,
  a.unit_id,
  a.stay_id,
  a.resource_id,
  a.asset_id,
  a.service_id,
  a.channel_id,
  a.investment_project_id,
  a.cost_center_id,
  a.paid_by_party_id,
  a.economic_bearer_party_id,
  ee.event_type,
  ee.effect_direction,
  ee.reverses_event_id,
  ee.economic_date,
  ee.currency,
  ee.status as economic_event_status,
  a.amount,
  a.allocation_type,
  a.classification,
  a.confidence,
  a.allocation_method,
  a.rationale,

  case when ee.effect_direction='REVERSAL' then -1 else 1 end as direction_multiplier,

  -- Category amount remains in its original category; REVERSAL changes polarity.
  a.amount * (case when ee.effect_direction='REVERSAL' then -1 else 1 end)
    as signed_category_amount,

  case
    when a.classification = 'REVENUE' then
      a.amount * (case when ee.effect_direction='REVERSAL' then -1 else 1 end)
    when a.classification = 'OPEX' then
      -a.amount * (case when ee.effect_direction='REVERSAL' then -1 else 1 end)
    else 0::numeric
  end as operating_result_effect,

  case
    when a.classification = 'CAPEX' then
      a.amount * (case when ee.effect_direction='REVERSAL' then -1 else 1 end)
    else 0::numeric
  end as capex_amount,

  case
    when a.classification = 'NON_BUSINESS' then
      a.amount * (case when ee.effect_direction='REVERSAL' then -1 else 1 end)
    else 0::numeric
  end as non_business_amount,

  case a.confidence
    when 'VERIFIED' then 1.00
    when 'SYSTEM_DERIVED' then 0.95
    when 'ESTIMATED' then 0.60
    when 'MANUAL' then 0.50
    when 'UNKNOWN' then 0.00
    else 0.00
  end::numeric(5,2) as confidence_weight
from allocation a
join economic_event ee
  on ee.organization_id = a.organization_id
 and ee.id = a.economic_event_id
where ee.status = 'POSTED';

-- -----------------------------------------------------------------
-- Property economic result for a period
-- -----------------------------------------------------------------
create or replace function osg_property_economic_result(
  p_property_id uuid,
  p_from_date date,
  p_to_date date
)
returns table (
  property_id uuid,
  from_date date,
  to_date date,
  net_allocated_revenue numeric,
  net_allocated_opex numeric,
  economic_operating_result numeric,
  net_capex numeric,
  non_business_excluded numeric,
  weighted_data_confidence numeric
)
language sql
stable
as $$
  select
    p_property_id,
    p_from_date,
    p_to_date,
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0),
    coalesce(sum(af.signed_category_amount) filter (where af.classification='OPEX'),0),
    coalesce(sum(af.operating_result_effect),0),
    coalesce(sum(af.capex_amount),0),
    coalesce(sum(af.non_business_amount),0),
    case
      when coalesce(sum(abs(af.amount)) filter (
        where af.classification in ('REVENUE','OPEX','CAPEX')),0)=0 then null
      else
        sum(abs(af.amount) * af.confidence_weight)
          filter (where af.classification in ('REVENUE','OPEX','CAPEX'))
        / nullif(sum(abs(af.amount))
          filter (where af.classification in ('REVENUE','OPEX','CAPEX')),0)
    end
  from osg_allocation_fact af
  where af.property_id = p_property_id
    and af.economic_date between p_from_date and p_to_date;
$$;

-- -----------------------------------------------------------------
-- Unit economics for a period
-- -----------------------------------------------------------------
create or replace function osg_unit_economics(
  p_property_id uuid,
  p_from_date date,
  p_to_date date
)
returns table (
  unit_id uuid,
  net_revenue numeric,
  net_direct_opex numeric,
  net_shared_opex numeric,
  net_overhead numeric,
  contribution_margin numeric,
  operating_margin numeric,
  net_capex numeric,
  data_confidence numeric
)
language sql
stable
as $$
  select
    af.unit_id,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='REVENUE'),0) as net_revenue,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='OPEX' and af.allocation_type='DIRECT'),0) as net_direct_opex,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='OPEX' and af.allocation_type='SHARED'),0) as net_shared_opex,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='OPEX' and af.allocation_type='OVERHEAD'),0) as net_overhead,
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0)
      - coalesce(sum(af.signed_category_amount) filter (
          where af.classification='OPEX' and af.allocation_type='DIRECT'),0)
      as contribution_margin,
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0)
      - coalesce(sum(af.signed_category_amount) filter (
          where af.classification='OPEX' and af.allocation_type in ('DIRECT','SHARED','OVERHEAD')),0)
      as operating_margin,
    coalesce(sum(af.capex_amount),0) as net_capex,
    case when sum(abs(af.amount)) filter (
      where af.classification in ('REVENUE','OPEX','CAPEX')) > 0
      then sum(abs(af.amount) * af.confidence_weight)
        filter (where af.classification in ('REVENUE','OPEX','CAPEX'))
        / nullif(sum(abs(af.amount))
          filter (where af.classification in ('REVENUE','OPEX','CAPEX')),0)
      else null end as data_confidence
  from osg_allocation_fact af
  where af.property_id = p_property_id
    and af.unit_id is not null
    and af.economic_date between p_from_date and p_to_date
  group by af.unit_id;
$$;

-- -----------------------------------------------------------------
-- Stay contribution margin
-- -----------------------------------------------------------------
create or replace function osg_stay_contribution_margin(p_stay_id uuid)
returns table (
  stay_id uuid,
  net_revenue numeric,
  net_direct_variable_cost numeric,
  contribution_margin numeric,
  data_confidence numeric
)
language sql
stable
as $$
  select
    p_stay_id,
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0),
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='OPEX' and af.allocation_type='DIRECT'),0),
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0)
      - coalesce(sum(af.signed_category_amount) filter (
          where af.classification='OPEX' and af.allocation_type='DIRECT'),0),
    case when sum(abs(af.amount)) filter (where af.classification in ('REVENUE','OPEX')) > 0
      then sum(abs(af.amount) * af.confidence_weight)
        filter (where af.classification in ('REVENUE','OPEX'))
        / nullif(sum(abs(af.amount)) filter (where af.classification in ('REVENUE','OPEX')),0)
      else null end
  from osg_allocation_fact af
  where af.stay_id = p_stay_id;
$$;

-- -----------------------------------------------------------------
-- Settlement balances
-- -----------------------------------------------------------------
create or replace view osg_settlement_balance as
select
  se.organization_id,
  se.id as settlement_entry_id,
  se.creditor_party_id,
  se.debtor_party_id,
  se.currency,
  se.amount as original_amount,
  coalesce(sum(sa.amount),0) as applied_amount,
  se.amount - coalesce(sum(sa.amount),0) as open_amount,
  case
    when coalesce(sum(sa.amount),0) = 0 then 'OPEN'
    when coalesce(sum(sa.amount),0) < se.amount then 'PARTIALLY_SETTLED'
    when coalesce(sum(sa.amount),0) = se.amount then 'SETTLED'
    else 'OVERAPPLIED_ERROR'
  end as derived_status
from settlement_entry se
left join settlement_application sa
  on sa.organization_id = se.organization_id
 and sa.settlement_entry_id = se.id
where se.status <> 'REVERSED'
group by
  se.organization_id, se.id, se.creditor_party_id, se.debtor_party_id,
  se.currency, se.amount;

-- -----------------------------------------------------------------
-- Economic vs cash remain intentionally separate.
-- A cost reversal stays in OPEX with opposite direction; it is not disguised
-- as REVENUE. A revenue reversal stays REVENUE with opposite direction.
-- -----------------------------------------------------------------
