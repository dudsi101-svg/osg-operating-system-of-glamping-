-- OSG Data Quality canonical checks v0.1
-- These views surface violations/anomalies. They do not silently repair data.

-- ---------------------------------------------------------------
-- Posted EconomicEvent allocation mismatch
-- ---------------------------------------------------------------
create or replace view osg_dq_unbalanced_posted_economic_event as
select
  ee.organization_id,
  ee.property_id,
  ee.id as economic_event_id,
  ee.amount as event_amount,
  coalesce(sum(a.amount),0) as allocation_sum,
  ee.amount - coalesce(sum(a.amount),0) as difference,
  'CRITICAL'::text as severity
from economic_event ee
left join allocation a
  on a.organization_id=ee.organization_id
 and a.economic_event_id=ee.id
where ee.status='POSTED'
group by ee.organization_id, ee.property_id, ee.id, ee.amount
having ee.amount <> coalesce(sum(a.amount),0);

-- ---------------------------------------------------------------
-- Payment overallocation
-- ---------------------------------------------------------------
create or replace view osg_dq_payment_overallocated as
select
  p.organization_id,
  p.id as payment_id,
  p.amount as payment_amount,
  coalesce(sum(pa.amount),0) as allocated_amount,
  coalesce(sum(pa.amount),0) - p.amount as overallocated_by,
  'CRITICAL'::text as severity
from payment p
left join payment_allocation pa
  on pa.organization_id=p.organization_id
 and pa.payment_id=p.id
group by p.organization_id,p.id,p.amount
having coalesce(sum(pa.amount),0) > p.amount;

-- ---------------------------------------------------------------
-- Settlement overapplication
-- ---------------------------------------------------------------
create or replace view osg_dq_settlement_overapplied as
select
  se.organization_id,
  se.id as settlement_entry_id,
  se.amount as settlement_amount,
  coalesce(sum(sa.amount),0) as applied_amount,
  coalesce(sum(sa.amount),0)-se.amount as overapplied_by,
  'CRITICAL'::text as severity
from settlement_entry se
left join settlement_application sa
  on sa.organization_id=se.organization_id
 and sa.settlement_entry_id=se.id
where se.status <> 'REVERSED'
group by se.organization_id,se.id,se.amount
having coalesce(sum(sa.amount),0) > se.amount;

-- ---------------------------------------------------------------
-- CAPEX without InvestmentProject
-- Threshold approval remains configurable; this view exposes every case.
-- ---------------------------------------------------------------
create or replace view osg_dq_capex_without_investment_project as
select
  af.organization_id,
  af.property_id,
  af.allocation_id,
  af.economic_event_id,
  af.amount,
  af.economic_date,
  af.confidence,
  'HIGH'::text as severity
from osg_allocation_fact af
where af.classification='CAPEX'
  and af.investment_project_id is null;

-- ---------------------------------------------------------------
-- Actual occupancy overlapping non-sellable block
-- This can be legitimate during incident escalation but must be visible.
-- ---------------------------------------------------------------
create or replace view osg_dq_occupied_non_sellable_overlap as
select distinct
  ss.organization_id,
  u.property_id,
  ss.stay_id,
  ss.id as stay_segment_id,
  ss.unit_id,
  ab.id as availability_block_id,
  ab.reason_type,
  ab.guest_impact,
  'HIGH'::text as severity
from stay_segment ss
join unit u
  on u.organization_id=ss.organization_id and u.id=ss.unit_id
join availability_block ab
  on ab.organization_id=ss.organization_id
 and ab.unit_id=ss.unit_id
 and ab.status='ACTIVE'
 and ab.sellability_impact=true
 and tstzrange(ab.start_at,ab.end_at,'[)') && tstzrange(ss.start_at,ss.end_at,'[)')
where ss.status='ACTIVE';

-- ---------------------------------------------------------------
-- Confirmed reservation approaching arrival without assigned Unit
-- ---------------------------------------------------------------
create or replace view osg_dq_unassigned_near_arrival as
select
  r.organization_id,
  r.property_id,
  r.id as reservation_id,
  ri.id as reservation_item_id,
  ri.arrival_date,
  ri.unit_type_id,
  'HIGH'::text as severity
from reservation r
join reservation_item ri
  on ri.organization_id=r.organization_id and ri.reservation_id=r.id
where r.commercial_status='CONFIRMED'
  and ri.status='ACTIVE'
  and ri.assigned_unit_id is null
  and ri.arrival_date <= ((now() at time zone 'UTC')::date + 1);

-- NOTE: the UTC-based near-arrival rule above is only a generic scan.
-- Property-timezone-aware operational alerts should use the Operations semantic layer.

-- ---------------------------------------------------------------
-- Unreconciled verified CashMovement older than 7 days
-- ReconciliationLink is supporting schema.
-- ---------------------------------------------------------------
create or replace view osg_dq_stale_unreconciled_cash as
select
  cm.organization_id,
  cm.id as cash_movement_id,
  cm.occurred_at,
  cm.amount,
  cm.currency,
  cm.external_reference,
  'MEDIUM'::text as severity
from cash_movement cm
where cm.status='VERIFIED'
  and cm.occurred_at < now()-interval '7 days'
  and not exists (
    select 1 from reconciliation_link rl
    where rl.organization_id=cm.organization_id
      and rl.cash_movement_id=cm.id
      and rl.match_status in ('MATCHED','PARTIAL')
  );

-- ---------------------------------------------------------------
-- Financial data confidence below reference threshold
-- ---------------------------------------------------------------
create or replace view osg_dq_low_confidence_allocation as
select
  af.organization_id,
  af.property_id,
  af.allocation_id,
  af.economic_event_id,
  af.amount,
  af.classification,
  af.confidence,
  af.rationale,
  case when af.confidence='UNKNOWN' then 'HIGH' else 'MEDIUM' end as severity
from osg_allocation_fact af
where af.confidence in ('UNKNOWN','ESTIMATED','MANUAL');

-- ---------------------------------------------------------------
-- Data-quality engine should convert rows from these canonical checks into
-- DataQualityIssue records idempotently using a stable fingerprint:
-- check_code + organization_id + subject ids + semantic version.
-- Resolution occurs when the source view no longer returns the condition,
-- unless human review explicitly marks it IGNORED with rationale.
-- ---------------------------------------------------------------
