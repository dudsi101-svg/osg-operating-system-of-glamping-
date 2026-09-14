-- OSG semantic occupancy reference v0.2
-- Pre-freeze reference SQL. Requires:
-- - osg_schema_v0.96_stay_policy_patch.sql
-- - osg_schema_v0.97_availability_impact_patch.sql
-- Goal: distinguish physical capacity, sellable capacity and actual occupied nights.

-- Business semantics:
-- 1. Unit-night D uses the property-local stay window:
--    [D at default_checkin_time, D+1 at default_checkout_time).
-- 2. A unit-night is NON-SELLABLE when an ACTIVE AvailabilityBlock with
--    sellability_impact=true overlaps that operational window.
-- 3. Actual occupancy comes from StaySegment execution, not Reservation plan.
-- 4. Physical capacity, sellable capacity and occupancy are separate facts.

create or replace view osg_property_stay_policy_current as
select distinct on (p.id)
  p.organization_id,
  p.id as property_id,
  p.timezone,
  spp.default_checkin_time,
  spp.default_checkout_time,
  spp.readiness_buffer
from property p
join property_stay_policy spp
  on spp.organization_id = p.organization_id
 and spp.property_id = p.id
where spp.active = true
  and spp.valid_from <= current_date
  and (spp.valid_to is null or spp.valid_to >= current_date)
order by p.id, spp.valid_from desc, spp.version_no desc;

create or replace function osg_property_stay_policy_for_date(
  p_property_id uuid,
  p_local_date date
)
returns table (
  organization_id uuid,
  property_id uuid,
  timezone text,
  default_checkin_time time,
  default_checkout_time time,
  readiness_buffer interval
)
language sql
stable
as $$
  select p.organization_id,
         p.id,
         p.timezone,
         spp.default_checkin_time,
         spp.default_checkout_time,
         spp.readiness_buffer
  from property p
  join property_stay_policy spp
    on spp.organization_id = p.organization_id
   and spp.property_id = p.id
  where p.id = p_property_id
    and spp.active = true
    and spp.valid_from <= p_local_date
    and (spp.valid_to is null or spp.valid_to >= p_local_date)
  order by spp.valid_from desc, spp.version_no desc
  limit 1;
$$;

create or replace function osg_unit_night_facts(
  p_property_id uuid,
  p_from_date date,
  p_to_date date
)
returns table (
  organization_id uuid,
  property_id uuid,
  unit_id uuid,
  local_night_date date,
  operational_start_at timestamptz,
  operational_end_at timestamptz,
  physical_capacity boolean,
  sellable_capacity boolean,
  occupied boolean
)
language plpgsql
stable
as $$
declare
  d date;
  u record;
  pol record;
  start_ts timestamptz;
  end_ts timestamptz;
begin
  if p_to_date < p_from_date then
    raise exception 'INVALID_DATE_RANGE';
  end if;

  for d in select generate_series(p_from_date, p_to_date, interval '1 day')::date loop
    select * into pol from osg_property_stay_policy_for_date(p_property_id, d);
    if pol.property_id is null then
      raise exception 'STAY_POLICY_NOT_FOUND property=% date=%', p_property_id, d;
    end if;

    -- Night D begins at local check-in D and ends at local check-out D+1.
    start_ts := ((d::text || ' ' || pol.default_checkin_time::text)::timestamp at time zone pol.timezone);
    end_ts   := (((d + 1)::text || ' ' || pol.default_checkout_time::text)::timestamp at time zone pol.timezone);

    for u in
      select un.organization_id, un.property_id, un.id, un.lifecycle_status,
             un.commissioned_at, un.retired_at
      from unit un
      where un.property_id = p_property_id
    loop
      organization_id := u.organization_id;
      property_id := u.property_id;
      unit_id := u.id;
      local_night_date := d;
      operational_start_at := start_ts;
      operational_end_at := end_ts;

      -- Physical capacity is historical: planned/not-yet-commissioned and retired
      -- units must not inflate old/new denominators.
      physical_capacity :=
        u.lifecycle_status <> 'PLANNED'
        and (u.commissioned_at is null or u.commissioned_at <= d)
        and (u.retired_at is null or u.retired_at > d);

      sellable_capacity := physical_capacity
        and u.lifecycle_status <> 'OUT_OF_SERVICE'
        and not exists (
          select 1
          from availability_block ab
          where ab.organization_id = u.organization_id
            and ab.unit_id = u.id
            and ab.status = 'ACTIVE'
            and ab.sellability_impact = true
            and tstzrange(ab.start_at, ab.end_at, '[)')
                && tstzrange(start_ts, end_ts, '[)')
        );

      occupied := exists (
        select 1
        from stay_segment ss
        where ss.organization_id = u.organization_id
          and ss.unit_id = u.id
          and ss.status = 'ACTIVE'
          and tstzrange(ss.start_at, ss.end_at, '[)')
              && tstzrange(start_ts, end_ts, '[)')
      );

      return next;
    end loop;
  end loop;
end;
$$;

-- Canonical metric examples:
-- Occupancy = occupied sellable unit-nights / sellable unit-nights.
-- Physical utilization = occupied unit-nights / physical unit-nights.
--
-- select
--   count(*) filter (where sellable_capacity) as sellable_unit_nights,
--   count(*) filter (where occupied and sellable_capacity) as occupied_sellable_unit_nights,
--   count(*) filter (where physical_capacity) as physical_unit_nights,
--   count(*) filter (where occupied) as occupied_unit_nights,
--   count(*) filter (where occupied and sellable_capacity)::numeric
--     / nullif(count(*) filter (where sellable_capacity),0) as occupancy,
--   count(*) filter (where occupied)::numeric
--     / nullif(count(*) filter (where physical_capacity),0) as physical_utilization
-- from osg_unit_night_facts(<property_id>, date '2026-09-01', date '2026-09-30');

-- Important:
-- - Reservation confirmation is not occupancy truth.
-- - Lack of booking does not mean sellable.
-- - Occupied + non-sellable is possible in an emergency/incident and should be
--   surfaced as a data/operations conflict rather than silently normalized.
