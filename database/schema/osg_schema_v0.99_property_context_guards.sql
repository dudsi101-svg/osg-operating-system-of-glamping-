-- OSG v0.99 Property Context Integrity guards
-- PRE-FREEZE / DEV candidate.
-- Tenant equality alone is insufficient in multi-property Organizations.

-- -----------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------
create or replace function osg_reservation_property(p_reservation_id uuid)
returns uuid language sql stable as $$
  select property_id from reservation where id=p_reservation_id
$$;

create or replace function osg_reservation_item_property(p_reservation_item_id uuid)
returns uuid language sql stable as $$
  select r.property_id
  from reservation_item ri
  join reservation r
    on r.organization_id=ri.organization_id and r.id=ri.reservation_id
  where ri.id=p_reservation_item_id
$$;

create or replace function osg_stay_property(p_stay_id uuid)
returns uuid language sql stable as $$
  select r.property_id
  from stay s
  join reservation_item ri
    on ri.organization_id=s.organization_id and ri.id=s.reservation_item_id
  join reservation r
    on r.organization_id=ri.organization_id and r.id=ri.reservation_id
  where s.id=p_stay_id
$$;

-- -----------------------------------------------------------------
-- ReservationItem → Reservation Property
-- -----------------------------------------------------------------
create or replace function osg_guard_reservation_item_property_context()
returns trigger language plpgsql as $$
declare
  v_property uuid;
  v_ref_property uuid;
begin
  select property_id into v_property
  from reservation
  where organization_id=new.organization_id and id=new.reservation_id;

  select property_id into v_ref_property
  from unit_type
  where organization_id=new.organization_id and id=new.unit_type_id;

  if v_ref_property is distinct from v_property then
    raise exception 'PROPERTY_CONTEXT_MISMATCH reservation_item.unit_type';
  end if;

  if new.assigned_unit_id is not null then
    select property_id into v_ref_property
    from unit
    where organization_id=new.organization_id and id=new.assigned_unit_id;

    if v_ref_property is distinct from v_property then
      raise exception 'PROPERTY_CONTEXT_MISMATCH reservation_item.assigned_unit';
    end if;
  end if;

  return new;
end $$;

create trigger trg_reservation_item_property_context
before insert or update on reservation_item
for each row execute function osg_guard_reservation_item_property_context();

-- -----------------------------------------------------------------
-- StaySegment Unit → Stay Property
-- -----------------------------------------------------------------
create or replace function osg_guard_stay_segment_property_context()
returns trigger language plpgsql as $$
declare
  v_stay_property uuid;
  v_unit_property uuid;
begin
  v_stay_property := osg_stay_property(new.stay_id);

  select property_id into v_unit_property
  from unit
  where organization_id=new.organization_id and id=new.unit_id;

  if v_stay_property is null or v_unit_property is distinct from v_stay_property then
    raise exception 'PROPERTY_CONTEXT_MISMATCH stay_segment.unit';
  end if;
  return new;
end $$;

create trigger trg_stay_segment_property_context
before insert or update on stay_segment
for each row execute function osg_guard_stay_segment_property_context();

-- -----------------------------------------------------------------
-- ServiceBooking references
-- -----------------------------------------------------------------
create or replace function osg_guard_service_booking_property_context()
returns trigger language plpgsql as $$
declare
  v_ref_property uuid;
begin
  select property_id into v_ref_property
  from service
  where organization_id=new.organization_id and id=new.service_id;
  if v_ref_property is distinct from new.property_id then
    raise exception 'PROPERTY_CONTEXT_MISMATCH service_booking.service';
  end if;

  if new.reservation_id is not null then
    select property_id into v_ref_property
    from reservation
    where organization_id=new.organization_id and id=new.reservation_id;
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH service_booking.reservation';
    end if;
  end if;

  if new.stay_id is not null then
    v_ref_property := osg_stay_property(new.stay_id);
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH service_booking.stay';
    end if;
  end if;

  return new;
end $$;

create trigger trg_service_booking_property_context
before insert or update on service_booking
for each row execute function osg_guard_service_booking_property_context();

-- ResourceReservation when linked to ServiceBooking.
create or replace function osg_guard_resource_reservation_property_context()
returns trigger language plpgsql as $$
declare
  v_resource_property uuid;
  v_service_property uuid;
begin
  if new.service_booking_id is null then
    return new;
  end if;

  select property_id into v_resource_property
  from resource
  where organization_id=new.organization_id and id=new.resource_id;

  select property_id into v_service_property
  from service_booking
  where organization_id=new.organization_id and id=new.service_booking_id;

  if v_resource_property is distinct from v_service_property then
    raise exception 'PROPERTY_CONTEXT_MISMATCH resource_reservation';
  end if;
  return new;
end $$;

create trigger trg_resource_reservation_property_context
before insert or update on resource_reservation
for each row execute function osg_guard_resource_reservation_property_context();

-- -----------------------------------------------------------------
-- Turnover
-- -----------------------------------------------------------------
create or replace function osg_guard_turnover_property_context()
returns trigger language plpgsql as $$
declare
  v_ref_property uuid;
begin
  select property_id into v_ref_property from unit
  where organization_id=new.organization_id and id=new.unit_id;
  if v_ref_property is distinct from new.property_id then
    raise exception 'PROPERTY_CONTEXT_MISMATCH turnover.unit';
  end if;

  if new.previous_stay_id is not null then
    v_ref_property := osg_stay_property(new.previous_stay_id);
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH turnover.previous_stay';
    end if;
  end if;

  if new.next_stay_id is not null then
    v_ref_property := osg_stay_property(new.next_stay_id);
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH turnover.next_stay';
    end if;
  end if;

  return new;
end $$;

create trigger trg_turnover_property_context
before insert or update on turnover
for each row execute function osg_guard_turnover_property_context();

-- -----------------------------------------------------------------
-- Incident physical references
-- -----------------------------------------------------------------
create or replace function osg_guard_incident_property_context()
returns trigger language plpgsql as $$
declare
  v_ref_property uuid;
begin
  if new.unit_id is not null then
    select property_id into v_ref_property from unit
    where organization_id=new.organization_id and id=new.unit_id;
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH incident.unit';
    end if;
  end if;

  if new.resource_id is not null then
    select property_id into v_ref_property from resource
    where organization_id=new.organization_id and id=new.resource_id;
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH incident.resource';
    end if;
  end if;

  if new.asset_id is not null then
    select property_id into v_ref_property from asset
    where organization_id=new.organization_id and id=new.asset_id;
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH incident.asset';
    end if;
  end if;

  return new;
end $$;

create trigger trg_incident_property_context
before insert or update on incident
for each row execute function osg_guard_incident_property_context();

-- -----------------------------------------------------------------
-- Allocation dimensions
-- -----------------------------------------------------------------
create or replace function osg_guard_allocation_property_context()
returns trigger language plpgsql as $$
declare
  v_event_property uuid;
  v_ref_property uuid;
begin
  select property_id into v_event_property
  from economic_event
  where organization_id=new.organization_id and id=new.economic_event_id;

  -- Property-owned business allocations inherit the event Property.
  if new.classification <> 'NON_BUSINESS' and v_event_property is not null then
    if new.property_id is null or new.property_id is distinct from v_event_property then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.property';
    end if;
  end if;

  -- Organization-level facts may omit Property, but cannot point dimensions at
  -- a Property while claiming a different explicit Allocation.property_id.
  if new.unit_id is not null then
    select property_id into v_ref_property from unit
    where organization_id=new.organization_id and id=new.unit_id;
    if new.property_id is null or v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.unit';
    end if;
  end if;

  if new.stay_id is not null then
    v_ref_property := osg_stay_property(new.stay_id);
    if new.property_id is null or v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.stay';
    end if;
  end if;

  if new.resource_id is not null then
    select property_id into v_ref_property from resource
    where organization_id=new.organization_id and id=new.resource_id;
    if new.property_id is null or v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.resource';
    end if;
  end if;

  if new.asset_id is not null then
    select property_id into v_ref_property from asset
    where organization_id=new.organization_id and id=new.asset_id;
    if new.property_id is null or v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.asset';
    end if;
  end if;

  if new.service_id is not null then
    select property_id into v_ref_property from service
    where organization_id=new.organization_id and id=new.service_id;
    if new.property_id is null or v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.service';
    end if;
  end if;

  if new.channel_id is not null then
    select property_id into v_ref_property from channel
    where organization_id=new.organization_id and id=new.channel_id;
    if new.property_id is null or v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.channel';
    end if;
  end if;

  if new.investment_project_id is not null then
    select property_id into v_ref_property from investment_project
    where organization_id=new.organization_id and id=new.investment_project_id;
    if new.property_id is null or v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.investment_project';
    end if;
  end if;

  if new.cost_center_id is not null then
    select property_id into v_ref_property from cost_center
    where organization_id=new.organization_id and id=new.cost_center_id;
    -- Organization-level CostCenter may have property_id NULL and is allowed.
    if v_ref_property is not null
       and (new.property_id is null or v_ref_property is distinct from new.property_id) then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.cost_center';
    end if;
  end if;

  return new;
end $$;

create trigger trg_allocation_property_context
before insert or update on allocation
for each row execute function osg_guard_allocation_property_context();

-- Stable application/domain error mapping for all exceptions above:
-- PROPERTY_CONTEXT_MISMATCH
