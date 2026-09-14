-- OSG semantic occupancy reference v0.1
-- Pre-freeze reference SQL. Requires PropertyStayPolicy patch.
-- Goal: distinguish physical capacity, sellable capacity and sold/occupied nights.

-- Assumptions:
-- 1. A unit-night is defined by property-local operational stay window:
--    [local_date + checkout_time, next_local_date + checkout_time)
--    for availability purposes.
-- 2. A unit-night is NON-SELLABLE if an active AvailabilityBlock overlaps the
--    operational window in a way that materially prevents sale/occupancy.
-- 3. Detailed partial-block policy is resolved through reason/configuration;
--    current reference treats any overlapping block marked sellability_impact=true
--    as non-sellable.
-- 4. Occupied nights come from StaySegment actual execution, not Reservation plan.

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

-- Historical helper function: returns the policy valid for a given local date.
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

-- Reference fact generator for a bounded date range.
-- This function is intentionally explicit instead of materializing infinite calendar rows.
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

    start_ts := ((d::text || ' ' || pol.default_checkout_time::text)::timestamp at time zone pol.timezone);
    end_ts   := (((d + 1)::text || ' ' || pol.default_checkout_time::text)::timestamp at time zone pol.timezone);

    for u in
      select un.organization_id, un.property_id, un.id, un.lifecycle_status
      from unit un
      where un.property_id = p_property_id
    loop
      organization_id := u.organization_id;
      property_id := u.property_id;
      unit_id := u.id;
      local_night_date := d;
      operational_start_at := start_ts;
      operational_end_at := end_ts;
      physical_capacity := (u.lifecycle_status in ('ACTIVE','OUT_OF_SERVICE'));

      sellable_capacity := physical_capacity
        and not exists (
          select 1
          from availability_block ab
          where ab.organization_id = u.organization_id
            and ab.unit_id = u.id
            and ab.status in ('ACTIVE','OPEN')
            and tstzrange(ab.start_at, ab.end_at, '[)') && tstzrange(start_ts, end_ts, '[)')
            and coalesce((ab.metadata->>'sellability_impact')::boolean, true) = true
        );

      occupied := exists (
        select 1
        from stay_segment ss
        where ss.organization_id = u.organization_id
          and ss.unit_id = u.id
          and ss.status = 'ACTIVE'
          and tstzrange(ss.start_at, ss.end_at, '[)') && tstzrange(start_ts, end_ts, '[)')
      );

      return next;
    end loop;
  end loop;
end;
$$;

-- Example metric query:
-- select
--   sum(case when sellable_capacity then 1 else 0 end) as sellable_unit_nights,
--   sum(case when occupied then 1 else 0 end) as occupied_unit_nights,
--   sum(case when occupied then 1 else 0 end)::numeric
--     / nullif(sum(case when sellable_capacity then 1 else 0 end),0) as occupancy
-- from osg_unit_night_facts(<property_id>, date '2026-09-01', date '2026-09-30');

-- Important:
-- Reservation confirmation is not used as occupancy truth.
-- Actual StaySegment determines physical occupancy.
-- Sellability is not inferred from lack of booking; it is an independent fact.
