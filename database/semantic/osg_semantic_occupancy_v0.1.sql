-- OSG capacity / physical-utilization semantic reference v0.3
-- Requires:
-- - PropertyStayPolicy + overnight anchor patch
-- - Availability impact patch
-- - ADR-012 Unit lifecycle semantics
--
-- Standard commercial Occupancy is defined separately in
-- osg_semantic_accommodation_nights_v0.1.sql.

create or replace view osg_property_stay_policy_current as
select distinct on (p.id)
  p.organization_id,
  p.id as property_id,
  p.timezone,
  spp.default_checkin_time,
  spp.default_checkout_time,
  spp.readiness_buffer,
  spp.overnight_anchor_time,
  spp.version_no
from property p
join property_stay_policy spp
  on spp.organization_id=p.organization_id
 and spp.property_id=p.id
where spp.active=true
  and spp.valid_from<=current_date
  and (spp.valid_to is null or spp.valid_to>=current_date)
order by p.id,spp.valid_from desc,spp.version_no desc;

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
  readiness_buffer interval,
  overnight_anchor_time time,
  policy_version integer
)
language sql
stable
as $$
  select p.organization_id,
         p.id,
         p.timezone,
         spp.default_checkin_time,
         spp.default_checkout_time,
         spp.readiness_buffer,
         spp.overnight_anchor_time,
         spp.version_no
  from property p
  join property_stay_policy spp
    on spp.organization_id=p.organization_id
   and spp.property_id=p.id
  where p.id=p_property_id
    and spp.active=true
    and spp.valid_from<=p_local_date
    and (spp.valid_to is null or spp.valid_to>=p_local_date)
  order by spp.valid_from desc,spp.version_no desc
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
  physically_occupied boolean
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
  if p_to_date<p_from_date then
    raise exception 'INVALID_DATE_RANGE';
  end if;

  for d in select generate_series(p_from_date,p_to_date,interval '1 day')::date loop
    select * into pol from osg_property_stay_policy_for_date(p_property_id,d);
    if pol.property_id is null then
      raise exception 'STAY_POLICY_NOT_FOUND property=% date=%',p_property_id,d;
    end if;

    start_ts := ((d::text || ' ' || pol.default_checkin_time::text)::timestamp at time zone pol.timezone);
    end_ts   := (((d+1)::text || ' ' || pol.default_checkout_time::text)::timestamp at time zone pol.timezone);

    for u in
      select un.organization_id,un.property_id,un.id,un.lifecycle_status,
             un.commissioned_at,un.retired_at
      from unit un
      where un.property_id=p_property_id
    loop
      organization_id := u.organization_id;
      property_id := u.property_id;
      unit_id := u.id;
      local_night_date := d;
      operational_start_at := start_ts;
      operational_end_at := end_ts;

      -- Lifecycle describes existence only. Temporary OOS belongs to AvailabilityBlock.
      physical_capacity :=
        u.lifecycle_status in ('ACTIVE','RETIRED')
        and (u.commissioned_at is null or u.commissioned_at<=d)
        and (u.retired_at is null or u.retired_at>d);

      sellable_capacity := physical_capacity
        and not exists (
          select 1
          from availability_block ab
          where ab.organization_id=u.organization_id
            and ab.unit_id=u.id
            and ab.status='ACTIVE'
            and ab.sellability_impact=true
            and tstzrange(ab.start_at,ab.end_at,'[)')
                && tstzrange(start_ts,end_ts,'[)')
        );

      physically_occupied := exists (
        select 1
        from stay_segment ss
        where ss.organization_id=u.organization_id
          and ss.unit_id=u.id
          and ss.status='ACTIVE'
          and tstzrange(ss.start_at,ss.end_at,'[)')
              && tstzrange(start_ts,end_ts,'[)')
      );

      return next;
    end loop;
  end loop;
end;
$$;

-- Physical utilization example:
-- count(*) filter (where physically_occupied)
-- / count(*) filter (where physical_capacity)
--
-- Do NOT use physically_occupied as the canonical ADR/standard Occupancy sold-night fact.
-- Commercial Accommodation Night semantics live in osg_commercial_accommodation_nights().
