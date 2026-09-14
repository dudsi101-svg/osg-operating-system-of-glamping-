-- OSG Folio semantic layer v0.2
-- Commercial balance, not economic profit and not bank cash balance.
-- Requires Charge correction contract: final Charges stay POSTED/RECOGNIZED;
-- reversals are separate opposite-sign Charges.

create or replace view osg_folio_balance as
with charge_totals as (
  select
    f.organization_id,
    f.id as folio_id,
    f.currency,
    coalesce(sum(c.gross_amount) filter (
      where c.status in ('POSTED','RECOGNIZED')),0) as net_charges,
    count(c.id) filter (where c.status='PENDING') as pending_charge_count
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
      where r.status='CONFIRMED'),0) as confirmed_refunds,
    count(p.id) filter (where p.status='PENDING') as pending_payment_count,
    count(r.id) filter (where r.status='PENDING') as pending_refund_count
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
  ct.net_charges-(pt.gross_payments-pt.confirmed_refunds) as balance_due,
  ct.pending_charge_count,
  pt.pending_payment_count,
  pt.pending_refund_count,
  (ct.pending_charge_count + pt.pending_payment_count + pt.pending_refund_count) as pending_commercial_items
from folio f
join charge_totals ct
  on ct.organization_id=f.organization_id and ct.folio_id=f.id
join payment_totals pt
  on pt.organization_id=f.organization_id and pt.folio_id=f.id;

-- Interpretation:
-- balance_due > 0 : payer still owes Folio
-- balance_due = 0 : commercially settled, assuming no blocking pending items
-- balance_due < 0 : credit/overpayment owed back or awaiting explicit correction
--
-- A REFUNDED Payment remains historical gross payment. Confirmed Refund subtracts it
-- from net collected. Original/reversing Charges net through signed amounts.
