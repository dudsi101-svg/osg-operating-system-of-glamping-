-- OSG Folio semantic layer v0.1
-- Commercial balance, not economic profit and not bank cash balance.

create or replace view osg_folio_balance as
with charge_totals as (
  select
    f.organization_id,
    f.id as folio_id,
    f.currency,
    coalesce(sum(c.gross_amount) filter (
      where c.status in ('POSTED','RECOGNIZED','REVERSED')),0) as net_charges
  from folio f
  left join charge c
    on c.organization_id=f.organization_id and c.folio_id=f.id
  group by f.organization_id,f.id,f.currency
), payment_totals as (
  select
    f.organization_id,
    f.id as folio_id,
    coalesce(sum(p.amount) filter (
      where p.status in ('CONFIRMED','PARTIALLY_REFUNDED','REFUNDED')),0) as gross_payments,
    coalesce(sum(r.amount) filter (
      where r.status='CONFIRMED'),0) as confirmed_refunds
  from folio f
  left join payment p
    on p.organization_id=f.organization_id and p.folio_id=f.id
  left join refund r
    on r.organization_id=p.organization_id and r.payment_id=p.id
  group by f.organization_id,f.id
)
select
  f.organization_id,
  f.id as folio_id,
  f.reservation_id,
  f.stay_id,
  f.currency,
  f.status,
  ct.net_charges,
  pt.gross_payments,
  pt.confirmed_refunds,
  (pt.gross_payments-pt.confirmed_refunds) as net_collected,
  ct.net_charges-(pt.gross_payments-pt.confirmed_refunds) as balance_due
from folio f
join charge_totals ct
  on ct.organization_id=f.organization_id and ct.folio_id=f.id
join payment_totals pt
  on pt.organization_id=f.organization_id and pt.folio_id=f.id;

-- Interpretation:
-- balance_due > 0 : guest/payer still owes Folio
-- balance_due = 0 : commercially settled
-- balance_due < 0 : credit/overpayment owed back or awaiting allocation
--
-- A REFUNDED Payment still counts as historical gross payment. The linked Refund
-- subtracts it from net collected. This preserves cash/commerce history.
