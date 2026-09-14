-- OSG Financial Truth semantic/reference views v0.1
-- PRE-FREEZE PROOF. Views are derived projections, never sources of truth.
-- Requires schema v0.95 + v0.96 patches.

-- ================================================================
-- Canonical posted economic allocations
-- ================================================================

create or replace view v_osg_posted_allocation as
select
  a.id as allocation_id,
  a.organization_id,
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
  e.id as economic_event_id,
  e.event_type,
  e.economic_date,
  e.financial_period_id,
  e.relates_to_financial_period_id,
  e.adjustment_reason,
  e.currency,
  a.amount,
  a.allocation_type,
  a.classification,
  a.confidence,
  a.allocation_method,
  a.rationale,
  case when a.classification = 'REVENUE' then a.amount else 0::numeric end as revenue_amount,
  case when a.classification = 'OPEX' then a.amount else 0::numeric end as opex_amount,
  case when a.classification = 'CAPEX' then a.amount else 0::numeric end as capex_amount,
  case when a.classification = 'NON_BUSINESS' then a.amount else 0::numeric end as non_business_amount,
  case
    when a.classification = 'REVENUE' then a.amount
    when a.classification = 'OPEX' then -a.amount
    else 0::numeric
  end as economic_operating_impact
from allocation a
join economic_event e
  on e.organization_id = a.organization_id
 and e.id = a.economic_event_id
where e.status = 'POSTED';

-- ================================================================
-- Property monthly economic summary
-- Uses allocation.property_id, not source Event property_id, because Allocation
-- is the source of economic ownership. NON_BUSINESS allocations with no property
-- are therefore excluded from a property's operating result.
-- ================================================================

create or replace view v_osg_property_economic_monthly as
select
  organization_id,
  property_id,
  date_trunc('month', economic_date)::date as month,
  currency,
  sum(revenue_amount) as revenue,
  sum(opex_amount) as opex,
  sum(capex_amount) as capex,
  sum(economic_operating_impact) as economic_operating_result,
  sum(case when event_type = 'ADJUSTMENT' then economic_operating_impact else 0 end) as prior_or_manual_adjustment_impact,
  count(distinct economic_event_id) as economic_event_count
from v_osg_posted_allocation
where property_id is not null
  and classification <> 'NON_BUSINESS'
group by organization_id, property_id, date_trunc('month', economic_date)::date, currency;

-- ================================================================
-- Unit monthly economics
-- ================================================================

create or replace view v_osg_unit_economic_monthly as
select
  organization_id,
  property_id,
  unit_id,
  date_trunc('month', economic_date)::date as month,
  currency,
  sum(revenue_amount) as allocated_revenue,
  sum(case when classification = 'OPEX' and allocation_type = 'DIRECT' then amount else 0 end) as direct_opex,
  sum(case when classification = 'OPEX' and allocation_type in ('SHARED','OVERHEAD') then amount else 0 end) as shared_or_overhead_opex,
  sum(capex_amount) as capex,
  sum(revenue_amount)
    - sum(case when classification = 'OPEX' then amount else 0 end) as unit_operating_margin
from v_osg_posted_allocation
where unit_id is not null
  and classification <> 'NON_BUSINESS'
group by organization_id, property_id, unit_id, date_trunc('month', economic_date)::date, currency;

-- ================================================================
-- Settlement balance projection
-- ================================================================

create or replace view v_osg_settlement_balance as
select
  se.id as settlement_entry_id,
  se.organization_id,
  se.creditor_party_id,
  se.debtor_party_id,
  se.currency,
  se.amount as original_amount,
  coalesce(sum(sa.amount),0)::numeric(14,2) as applied_amount,
  (se.amount - coalesce(sum(sa.amount),0))::numeric(14,2) as open_amount,
  case
    when coalesce(sum(sa.amount),0) = 0 then 'OPEN'
    when coalesce(sum(sa.amount),0) < se.amount then 'PARTIALLY_SETTLED'
    when coalesce(sum(sa.amount),0) = se.amount then 'SETTLED'
    else 'INVALID_OVER_APPLIED'
  end as derived_status,
  se.created_at
from settlement_entry se
left join settlement_application sa
  on sa.organization_id = se.organization_id
 and sa.settlement_entry_id = se.id
where se.status <> 'REVERSED'
group by se.id, se.organization_id, se.creditor_party_id, se.debtor_party_id, se.currency, se.amount, se.created_at;

-- ================================================================
-- Allocation confidence exposure
-- This is not a universal 0–100 truth score. It exposes the monetary basis
-- of confidence categories so the semantic layer can apply a versioned model.
-- ================================================================

create or replace view v_osg_allocation_confidence_monthly as
select
  organization_id,
  property_id,
  date_trunc('month', economic_date)::date as month,
  currency,
  sum(amount) filter (where confidence = 'VERIFIED') as verified_amount,
  sum(amount) filter (where confidence = 'SYSTEM_DERIVED') as system_derived_amount,
  sum(amount) filter (where confidence = 'ESTIMATED') as estimated_amount,
  sum(amount) filter (where confidence = 'MANUAL') as manual_amount,
  sum(amount) filter (where confidence = 'UNKNOWN') as unknown_amount,
  sum(amount) as total_amount,
  case
    when sum(amount) = 0 then null
    else round(
      100 * (
        coalesce(sum(amount) filter (where confidence in ('VERIFIED','SYSTEM_DERIVED')),0)
        / nullif(sum(amount),0)
      ), 2
    )
  end as high_confidence_value_share_pct
from v_osg_posted_allocation
where property_id is not null
  and classification <> 'NON_BUSINESS'
group by organization_id, property_id, date_trunc('month', economic_date)::date, currency;

-- ================================================================
-- Investment summary
-- ================================================================

create or replace view v_osg_investment_project_summary as
select
  ip.id as investment_project_id,
  ip.organization_id,
  ip.property_id,
  ip.name,
  ip.status,
  ip.budget,
  pa.currency,
  coalesce(sum(pa.capex_amount),0) as allocated_capex,
  case
    when ip.budget is null then null
    else ip.budget - coalesce(sum(pa.capex_amount),0)
  end as budget_remaining
from investment_project ip
left join v_osg_posted_allocation pa
  on pa.organization_id = ip.organization_id
 and pa.investment_project_id = ip.id
 and pa.classification = 'CAPEX'
group by ip.id, ip.organization_id, ip.property_id, ip.name, ip.status, ip.budget, pa.currency;

-- Notes:
-- * Accounting view and Cash view require their own semantic views and must not
--   be inferred from this Economic view.
-- * Tax/VAT semantics are intentionally not encoded here yet.
-- * Currency aggregation assumes one currency per grouped row; no FX conversion
--   occurs implicitly.
