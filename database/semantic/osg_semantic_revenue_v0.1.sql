-- OSG Revenue semantic reference v0.2
-- Depends on:
-- - osg_semantic_occupancy_v0.2
-- - osg_semantic_financial_truth_v0.2
-- PRE-FREEZE reference. Not yet materialized/optimized.

-- Revenue truth is derived from POSTED revenue Allocations.
-- EconomicEvent/Charge identify origin and category, but Allocation decides
-- what belongs economically to the Property/Unit/Stay.

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
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='REVENUE'
        and c.charge_type='ACCOMMODATION'
    ),0)::numeric as accommodation_revenue,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='REVENUE'
    ),0)::numeric as total_revenue
  from osg_allocation_fact af
  join economic_event ee
    on ee.organization_id=af.organization_id
   and ee.id=af.economic_event_id
  left join charge c
    on c.organization_id=ee.organization_id
   and c.id=ee.source_charge_id
  where af.property_id=p_property_id
    and af.economic_date between p_from_date and p_to_date
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

-- -----------------------------------------------------------------
-- Booking/channel acquisition metrics.
-- Period is booking-created period, not stay/economic-recognition period.
-- -----------------------------------------------------------------
create or replace function osg_channel_booking_metrics(
  p_property_id uuid,
  p_from_date date,
  p_to_date date
)
returns table (
  total_confirmed_bookings bigint,
  direct_confirmed_bookings bigint,
  ota_confirmed_bookings bigint,
  direct_booking_share numeric
)
language sql
stable
as $$
  select
    count(*) filter (where r.commercial_status='CONFIRMED'),
    count(*) filter (
      where r.commercial_status='CONFIRMED'
        and ch.channel_type in ('DIRECT','DIRECT_ASSISTED')),
    count(*) filter (
      where r.commercial_status='CONFIRMED'
        and ch.channel_type='OTA'),
    count(*) filter (
      where r.commercial_status='CONFIRMED'
        and ch.channel_type in ('DIRECT','DIRECT_ASSISTED'))::numeric
      / nullif(count(*) filter (where r.commercial_status='CONFIRMED'),0)
  from reservation r
  left join channel ch
    on ch.organization_id=r.organization_id
   and ch.id=r.channel_id
  join property p
    on p.organization_id=r.organization_id and p.id=r.property_id
  where r.property_id=p_property_id
    and (r.booked_at at time zone p.timezone)::date between p_from_date and p_to_date;
$$;

-- -----------------------------------------------------------------
-- Stay revenue / upsell metrics.
-- Only economically allocated revenue linked to a Stay is counted.
-- -----------------------------------------------------------------
create or replace function osg_stay_revenue_metrics(p_stay_id uuid)
returns table (
  stay_id uuid,
  accommodation_revenue numeric,
  upsell_revenue numeric,
  total_stay_revenue numeric,
  actual_guest_count integer,
  revenue_per_guest numeric
)
language sql
stable
as $$
with r as (
  select
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='REVENUE' and c.charge_type='ACCOMMODATION'),0) as accommodation,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='REVENUE'
        and (af.service_id is not null or c.charge_type in ('SERVICE','FEE'))),0) as upsell,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='REVENUE'),0) as total
  from osg_allocation_fact af
  join economic_event ee
    on ee.organization_id=af.organization_id and ee.id=af.economic_event_id
  left join charge c
    on c.organization_id=ee.organization_id and c.id=ee.source_charge_id
  where af.stay_id=p_stay_id
), s as (
  select guest_count_actual from stay where id=p_stay_id
)
select
  p_stay_id,
  r.accommodation,
  r.upsell,
  r.total,
  s.guest_count_actual,
  r.total / nullif(s.guest_count_actual,0)
from r cross join s;
$$;

-- -----------------------------------------------------------------
-- Period upsell per eligible completed stay/booking execution.
-- -----------------------------------------------------------------
create or replace function osg_property_upsell_metrics(
  p_property_id uuid,
  p_from_date date,
  p_to_date date
)
returns table (
  completed_stays bigint,
  upsell_revenue numeric,
  upsell_per_completed_stay numeric
)
language sql
stable
as $$
with completed as (
  select s.id
  from stay s
  join reservation_item ri
    on ri.organization_id=s.organization_id and ri.id=s.reservation_item_id
  join reservation r
    on r.organization_id=ri.organization_id and r.id=ri.reservation_id
  join property p
    on p.organization_id=r.organization_id and p.id=r.property_id
  where r.property_id=p_property_id
    and s.status='CHECKED_OUT'
    and (s.actual_checkout_at at time zone p.timezone)::date between p_from_date and p_to_date
), upsell as (
  select coalesce(sum(af.signed_category_amount),0) as amount
  from osg_allocation_fact af
  join economic_event ee
    on ee.organization_id=af.organization_id and ee.id=af.economic_event_id
  left join charge c
    on c.organization_id=ee.organization_id and c.id=ee.source_charge_id
  where af.property_id=p_property_id
    and af.economic_date between p_from_date and p_to_date
    and af.classification='REVENUE'
    and (af.service_id is not null or c.charge_type in ('SERVICE','FEE'))
)
select
  (select count(*) from completed),
  upsell.amount,
  upsell.amount / nullif((select count(*) from completed),0)
from upsell;
$$;

-- Important:
-- - Reversals reduce the original category rather than being relabeled.
-- - ADR denominator is actual occupied unit-nights.
-- - RevPAR/TRevPAR denominator is sellable unit-nights.
-- - Booking-channel metrics use booking-created period and must not be confused
--   with stay-date/revenue-recognition metrics.
