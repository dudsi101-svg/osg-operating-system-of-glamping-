-- OSG Operations semantic layer v0.1
-- Reference queries for Operations Center. No business state is owned by these views.

create or replace function osg_expected_arrivals(
  p_property_id uuid,
  p_local_date date
)
returns table (
  reservation_id uuid,
  reservation_item_id uuid,
  stay_id uuid,
  unit_id uuid,
  unit_name text,
  guest_name text,
  expected_at timestamptz,
  commercial_status text,
  stay_status text,
  total_guests integer
)
language sql
stable
as $$
  with pol as (
    select * from osg_property_stay_policy_for_date(p_property_id, p_local_date)
  )
  select
    r.id,
    ri.id,
    s.id,
    ri.assigned_unit_id,
    u.name,
    pa.display_name,
    ((ri.arrival_date::text || ' ' || pol.default_checkin_time::text)::timestamp at time zone pol.timezone),
    r.commercial_status,
    s.status,
    (ri.adults + ri.children + ri.infants)
  from reservation r
  join reservation_item ri
    on ri.organization_id = r.organization_id
   and ri.reservation_id = r.id
  left join stay s
    on s.organization_id = ri.organization_id
   and s.reservation_item_id = ri.id
   and s.status <> 'CANCELLED'
  left join unit u
    on u.organization_id = ri.organization_id
   and u.id = ri.assigned_unit_id
  left join guest_profile gp
    on gp.organization_id = r.organization_id
   and gp.id = r.primary_guest_id
  left join party pa
    on pa.organization_id = gp.organization_id
   and pa.id = gp.party_id
  cross join pol
  where r.property_id = p_property_id
    and ri.arrival_date = p_local_date
    and ri.status = 'ACTIVE'
    and r.commercial_status in ('HELD','CONFIRMED')
  order by expected_at, unit_name;
$$;

create or replace function osg_expected_departures(
  p_property_id uuid,
  p_local_date date
)
returns table (
  reservation_id uuid,
  reservation_item_id uuid,
  stay_id uuid,
  unit_id uuid,
  unit_name text,
  guest_name text,
  expected_at timestamptz,
  stay_status text
)
language sql
stable
as $$
  with pol as (
    select * from osg_property_stay_policy_for_date(p_property_id, p_local_date)
  )
  select
    r.id,
    ri.id,
    s.id,
    coalesce(last_seg.unit_id, ri.assigned_unit_id),
    u.name,
    pa.display_name,
    ((ri.departure_date::text || ' ' || pol.default_checkout_time::text)::timestamp at time zone pol.timezone),
    s.status
  from reservation r
  join reservation_item ri
    on ri.organization_id = r.organization_id
   and ri.reservation_id = r.id
  left join stay s
    on s.organization_id = ri.organization_id
   and s.reservation_item_id = ri.id
   and s.status <> 'CANCELLED'
  left join lateral (
    select ss.unit_id
    from stay_segment ss
    where ss.organization_id = s.organization_id
      and ss.stay_id = s.id
      and ss.status='ACTIVE'
    order by ss.end_at desc
    limit 1
  ) last_seg on true
  left join unit u
    on u.organization_id = ri.organization_id
   and u.id = coalesce(last_seg.unit_id, ri.assigned_unit_id)
  left join guest_profile gp
    on gp.organization_id = r.organization_id
   and gp.id = r.primary_guest_id
  left join party pa
    on pa.organization_id = gp.organization_id
   and pa.id = gp.party_id
  cross join pol
  where r.property_id = p_property_id
    and ri.departure_date = p_local_date
    and ri.status = 'ACTIVE'
    and r.commercial_status = 'CONFIRMED'
  order by expected_at, unit_name;
$$;

create or replace view osg_turnover_attention as
select
  t.organization_id,
  t.property_id,
  t.id as turnover_id,
  t.unit_id,
  u.name as unit_name,
  t.status,
  t.priority,
  t.ready_deadline,
  t.next_stay_id,
  case
    when t.status='BLOCKED' then 'BLOCKED'
    when t.status<>'READY' and t.ready_deadline < now() then 'OVERDUE'
    when t.status<>'READY' and t.ready_deadline <= now() + interval '60 minutes' then 'AT_RISK'
    else 'ON_TRACK'
  end as attention_status
from turnover t
join unit u
  on u.organization_id=t.organization_id and u.id=t.unit_id
where t.status not in ('READY','CANCELLED');

create or replace view osg_open_incident_attention as
select
  i.organization_id,
  i.property_id,
  i.id as incident_id,
  i.unit_id,
  i.resource_id,
  i.asset_id,
  i.severity,
  i.status,
  i.title,
  i.guest_impact,
  i.safety_related,
  i.reported_at,
  extract(epoch from (now()-i.reported_at))/3600.0 as age_hours
from incident i
where i.status not in ('RESOLVED','CLOSED');

-- Operations Center should combine these projections with today's confirmed
-- ServiceBookings/ResourceReservations. It must not own Reservation, Stay,
-- Turnover or Incident state itself.
