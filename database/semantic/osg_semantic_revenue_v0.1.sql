-- OSG Revenue semantic reference v0.1
-- Depends on osg_semantic_occupancy_v0.2 semantics.
-- PRE-FREEZE reference. Not yet materialized/optimized.

-- Revenue truth:
-- recognized revenue = POSTED EconomicEvent(event_type='REVENUE') by economic_date.
-- Accommodation revenue is identified by source Charge of type ACCOMMODATION.
-- Service/other revenue is recognized independently and contributes to TRevPAR.

create or replace function osg_property_revenue_metrics(
  p_property_id uuid,
  p_from_date date,
  p_to_date date
)
returns table (
  property_id uuid,
  from_date date,
  to_date date,
  accommodation_revenue numeric,
  total_revenue numeric,
  sold_unit_nights bigint,
  sellable_unit_nights bigint,
  adr numeric,
  revpar numeric,
  trevpar numeric
)
language sql
stable
as $$
with night_facts as (
  select *
  from osg_unit_night_facts(p_property_id, p_from_date, p_to_date)
),
capacity as (
  select
    count(*) filter (where occupied) as sold_unit_nights,
    count(*) filter (where sellable_capacity) as sellable_unit_nights
  from night_facts
),
recognized as (
  select
    coalesce(sum(ee.amount) filter (
      where ee.event_type = 'REVENUE'
        and c.charge_type = 'ACCOMMODATION'
    ),0)::numeric as accommodation_revenue,
    coalesce(sum(ee.amount) filter (
      where ee.event_type = 'REVENUE'
    ),0)::numeric as total_revenue
  from economic_event ee
  left join charge c
    on c.organization_id = ee.organization_id
   and c.id = ee.source_charge_id
  where ee.property_id = p_property_id
    and ee.status = 'POSTED'
    and ee.economic_date between p_from_date and p_to_date
)
select
  p_property_id,
  p_from_date,
  p_to_date,
  r.accommodation_revenue,
  r.total_revenue,
  c.sold_unit_nights,
  c.sellable_unit_nights,
  r.accommodation_revenue / nullif(c.sold_unit_nights,0) as adr,
  r.accommodation_revenue / nullif(c.sellable_unit_nights,0) as revpar,
  r.total_revenue / nullif(c.sellable_unit_nights,0) as trevpar
from recognized r cross join capacity c;
$$;

-- Notes:
-- ADR denominator is actual occupied/sold unit-nights from StaySegments.
-- RevPAR/TRevPAR denominator is sellable unit-nights.
-- A confirmed Reservation without executed Stay does not enter sold-unit-night denominator.
-- Cancellation/no-show revenue, if recognized by policy, can enter total revenue without creating a fake occupied night.
-- Taxes/pass-through amounts should be excluded from REVENUE EconomicEvents used for managerial KPI if policy requires net revenue view.
