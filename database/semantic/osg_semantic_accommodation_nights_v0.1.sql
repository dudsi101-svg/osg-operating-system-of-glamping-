-- OSG Commercial Accommodation Night semantic layer v0.1
-- Implements ADR-011.
-- Requires PropertyStayPolicy + overnight_anchor_time.

-- Historical/commercial night is not identical to physical StaySegment overlap.
-- It represents one delivered accommodation night, attributed to the Unit that
-- hosted the overnight anchor for that night.

create or replace function osg_commercial_accommodation_nights(
  p_property_id uuid,
  p_from_date date,
  p_to_date date
)
returns table (
  organization_id uuid,
  property_id uuid,
  stay_id uuid,
  reservation_item_id uuid,
  night_date date,
  unit_id uuid,
  anchor_at timestamptz,
  finality text,
  attribution_status text
)
language plpgsql
stable
as $$
declare
  rec record;
  d date;
  pol record;
  v_end_exclusive date;
  v_local_checkout_date date;
  v_local_now_date date;
  v_local_now_time time;
  v_anchor timestamptz;
  v_unit uuid;
begin
  if p_to_date < p_from_date then
    raise exception 'INVALID_DATE_RANGE';
  end if;

  for rec in
    select
      s.organization_id,
      s.id as stay_id,
      s.status as stay_status,
      s.actual_checkout_at,
      ri.id as reservation_item_id,
      ri.arrival_date,
      ri.departure_date,
      r.property_id,
      p.timezone
    from stay s
    join reservation_item ri
      on ri.organization_id=s.organization_id and ri.id=s.reservation_item_id
    join reservation r
      on r.organization_id=ri.organization_id and r.id=ri.reservation_id
    join property p
      on p.organization_id=r.organization_id and p.id=r.property_id
    where r.property_id=p_property_id
      and s.status in ('CHECKED_IN','CHECKED_OUT')
      and ri.status='ACTIVE'
      and r.commercial_status='CONFIRMED'
      and ri.arrival_date <= p_to_date
      and ri.departure_date > p_from_date
  loop
    if rec.stay_status='CHECKED_OUT' then
      v_local_checkout_date := (rec.actual_checkout_at at time zone rec.timezone)::date;
      -- Early checkout can reduce executed accommodation nights, but late checkout
      -- never invents an extra night beyond the commercial departure date.
      v_end_exclusive := least(rec.departure_date, greatest(rec.arrival_date, v_local_checkout_date));
    else
      v_local_now_date := (now() at time zone rec.timezone)::date;
      v_local_now_time := (now() at time zone rec.timezone)::time;

      select * into pol from osg_property_stay_policy_for_date(rec.property_id,v_local_now_date);
      if pol.property_id is null then
        raise exception 'STAY_POLICY_NOT_FOUND property=% date=%',rec.property_id,v_local_now_date;
      end if;

      -- For an active Stay, include the current commercial night only once the
      -- local check-in boundary for that night has started.
      v_end_exclusive := least(
        rec.departure_date,
        v_local_now_date + case when v_local_now_time >= pol.default_checkin_time then 1 else 0 end
      );
    end if;

    if v_end_exclusive <= rec.arrival_date then
      continue;
    end if;

    for d in
      select generate_series(
        greatest(rec.arrival_date,p_from_date),
        least(v_end_exclusive-1,p_to_date),
        interval '1 day'
      )::date
    loop
      select * into pol from osg_property_stay_policy_for_date(rec.property_id,d);
      if pol.property_id is null then
        raise exception 'STAY_POLICY_NOT_FOUND property=% date=%',rec.property_id,d;
      end if;

      -- Requires helper to expose overnight_anchor_time after ADR-011 patch.
      select
        (((d+1)::text || ' ' || spp.overnight_anchor_time::text)::timestamp at time zone p.timezone)
      into v_anchor
      from property p
      join property_stay_policy spp
        on spp.organization_id=p.organization_id and spp.property_id=p.id
      where p.id=rec.property_id
        and spp.active=true
        and spp.valid_from<=d
        and (spp.valid_to is null or spp.valid_to>=d)
      order by spp.valid_from desc,spp.version_no desc
      limit 1;

      select ss.unit_id into v_unit
      from stay_segment ss
      where ss.organization_id=rec.organization_id
        and ss.stay_id=rec.stay_id
        and ss.status='ACTIVE'
        and ss.start_at <= v_anchor
        and ss.end_at > v_anchor
      order by ss.start_at desc
      limit 1;

      organization_id := rec.organization_id;
      property_id := rec.property_id;
      stay_id := rec.stay_id;
      reservation_item_id := rec.reservation_item_id;
      night_date := d;
      unit_id := v_unit;
      anchor_at := v_anchor;
      finality := case when rec.stay_status='CHECKED_OUT' then 'FINAL' else 'PROVISIONAL' end;
      attribution_status := case when v_unit is null then 'UNRESOLVED' else 'RESOLVED' end;
      return next;
    end loop;
  end loop;
end;
$$;

-- Standard historical occupancy should use FINAL facts for closed reporting
-- periods; real-time dashboards may include PROVISIONAL facts with a label.

create or replace function osg_property_occupancy_metrics(
  p_property_id uuid,
  p_from_date date,
  p_to_date date,
  p_include_provisional boolean default false
)
returns table (
  property_id uuid,
  commercial_nights bigint,
  resolved_commercial_nights bigint,
  sellable_unit_nights bigint,
  effective_capacity_nights bigint,
  occupancy numeric,
  unresolved_nights bigint
)
language sql
stable
as $$
with commercial as (
  select *
  from osg_commercial_accommodation_nights(p_property_id,p_from_date,p_to_date)
  where p_include_provisional or finality='FINAL'
), capacity as (
  select * from osg_unit_night_facts(p_property_id,p_from_date,p_to_date)
), joined as (
  select
    c.*,
    exists (
      select 1 from commercial cn
      where cn.unit_id=c.unit_id and cn.night_date=c.local_night_date
        and cn.attribution_status='RESOLVED'
    ) as commercially_occupied
  from capacity c
)
select
  p_property_id,
  (select count(*) from commercial),
  (select count(*) from commercial where attribution_status='RESOLVED'),
  count(*) filter (where sellable_capacity),
  count(*) filter (where sellable_capacity or commercially_occupied),
  (select count(*) from commercial where attribution_status='RESOLVED')::numeric
    / nullif(count(*) filter (where sellable_capacity or commercially_occupied),0),
  (select count(*) from commercial where attribution_status='UNRESOLVED')
from joined;
$$;

-- effective_capacity_nights uses (sellable OR already commercially occupied)
-- so a retrospective AvailabilityBlock cannot shrink denominator below nights
-- that were already delivered. Such overlap is still surfaced by Data Quality.
