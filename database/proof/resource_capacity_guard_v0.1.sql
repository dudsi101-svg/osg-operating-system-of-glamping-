-- OSG resource capacity guard v0.1
-- DEV PROOF ONLY. Capacity > 1 cannot be guaranteed by a simple exclusion constraint.

create or replace function osg_assert_resource_capacity(
  p_resource_id uuid,
  p_start timestamptz,
  p_end timestamptz,
  p_capacity_used integer,
  p_exclude_reservation_id uuid default null,
  p_as_of timestamptz default now()
)
returns void language plpgsql as $$
declare
  v_capacity integer;
  v_booking_mode text;
  v_used integer;
begin
  if p_end <= p_start then
    raise exception 'OSG_RESOURCE_INVALID_RANGE';
  end if;
  if p_capacity_used <= 0 then
    raise exception 'OSG_RESOURCE_INVALID_CAPACITY_REQUEST';
  end if;

  -- Serialize competing capacity calculations for this resource.
  select capacity, booking_mode into v_capacity, v_booking_mode
  from resource
  where id = p_resource_id
  for update;

  if v_capacity is null then
    raise exception 'OSG_RESOURCE_NOT_FOUND';
  end if;

  if v_booking_mode = 'EXCLUSIVE' then
    v_capacity := 1;
    p_capacity_used := 1;
  end if;

  select coalesce(sum(rr.capacity_used),0)::integer into v_used
  from resource_reservation rr
  where rr.resource_id = p_resource_id
    and (p_exclude_reservation_id is null or rr.id <> p_exclude_reservation_id)
    and (
      rr.status in ('CONFIRMED','IN_PROGRESS')
      or (rr.status = 'HELD' and (rr.expires_at is null or rr.expires_at > p_as_of))
    )
    and tstzrange(rr.effective_start_at, rr.effective_end_at, '[)')
        && tstzrange(p_start, p_end, '[)');

  if v_used + p_capacity_used > v_capacity then
    raise exception 'OSG_RESOURCE_CAPACITY_EXCEEDED resource=% capacity=% used=% requested=%',
      p_resource_id, v_capacity, v_used, p_capacity_used;
  end if;
end $$;

-- Required write workflow:
-- BEGIN;
-- SELECT/guard locks Resource;
-- CALL osg_assert_resource_capacity(...);
-- INSERT/UPDATE ResourceReservation;
-- COMMIT;
--
-- The capacity check and mutation MUST share the same transaction and lock.
-- Separate `check availability` HTTP calls are advisory only and never guarantee a slot.
