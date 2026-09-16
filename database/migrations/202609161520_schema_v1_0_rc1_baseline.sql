--
-- PostgreSQL database dump
--


-- Dumped from database version 16.15 (Debian 16.15-1.pgdg13+2)
-- Dumped by pg_dump version 16.15 (Ubuntu 16.15-1.pgdg24.04+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: osg_assert_economic_event_balanced(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_assert_economic_event_balanced(p_event_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_amount numeric(14,2);
  v_status text;
  v_sum numeric(14,2);
begin
  select amount, status into v_amount, v_status
  from economic_event where id = p_event_id for update;

  if v_status = 'POSTED' then
    select coalesce(sum(amount),0) into v_sum
    from allocation where economic_event_id = p_event_id;
    if v_sum <> v_amount then
      raise exception 'OSG_ALLOCATION_NOT_BALANCED event=% expected=% actual=%', p_event_id, v_amount, v_sum;
    end if;
  end if;
end $$;


--
-- Name: osg_assert_payment_not_overallocated(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_assert_payment_not_overallocated(p_payment_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_amount numeric(14,2);
  v_allocated numeric(14,2);
begin
  select amount into v_amount
  from payment
  where id = p_payment_id
  for update;

  if v_amount is null then
    raise exception 'OSG_PAYMENT_NOT_FOUND';
  end if;

  select coalesce(sum(amount),0) into v_allocated
  from payment_allocation
  where payment_id = p_payment_id;

  if v_allocated > v_amount then
    raise exception 'OSG_PAYMENT_OVERALLOCATED payment=% amount=% allocated=%', p_payment_id, v_amount, v_allocated;
  end if;
end $$;


--
-- Name: osg_assert_resource_capacity(uuid, timestamp with time zone, timestamp with time zone, integer, uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_assert_resource_capacity(p_resource_id uuid, p_start timestamp with time zone, p_end timestamp with time zone, p_capacity_used integer, p_exclude_reservation_id uuid DEFAULT NULL::uuid, p_as_of timestamp with time zone DEFAULT now()) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: osg_assert_settlement_not_overapplied(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_assert_settlement_not_overapplied(p_settlement_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_amount numeric(14,2);
  v_applied numeric(14,2);
begin
  select amount into v_amount
  from settlement_entry
  where id = p_settlement_id
  for update;

  if v_amount is null then
    raise exception 'OSG_SETTLEMENT_NOT_FOUND';
  end if;

  select coalesce(sum(amount),0) into v_applied
  from settlement_application
  where settlement_entry_id = p_settlement_id;

  if v_applied > v_amount then
    raise exception 'OSG_SETTLEMENT_OVER_APPLIED settlement=% amount=% applied=%', p_settlement_id, v_amount, v_applied;
  end if;
end $$;


--
-- Name: osg_assert_target_period_open_for_post(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_assert_target_period_open_for_post(p_event_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_period_status text;
begin
  select fp.status into v_period_status
  from economic_event ee
  left join financial_period fp
    on fp.organization_id=ee.organization_id and fp.id=ee.financial_period_id
  where ee.id=p_event_id;

  if v_period_status='HARD_CLOSED' then
    raise exception 'OSG_FINANCIAL_PERIOD_HARD_CLOSED';
  end if;
end $$;


--
-- Name: osg_canonical_guest_profile(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_canonical_guest_profile(p_organization_id uuid, p_guest_profile_id uuid) RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select coalesce(
    (select canonical_guest_profile_id
     from guest_profile_alias
     where organization_id=p_organization_id
       and alias_guest_profile_id=p_guest_profile_id
       and active=true
     limit 1),
    p_guest_profile_id
  )
$$;


--
-- Name: osg_channel_booking_metrics(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_channel_booking_metrics(p_property_id uuid, p_from_date date, p_to_date date) RETURNS TABLE(total_confirmed_bookings bigint, direct_confirmed_bookings bigint, ota_confirmed_bookings bigint, direct_booking_share numeric)
    LANGUAGE sql STABLE
    AS $$
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


--
-- Name: osg_charge_applied_amount(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_charge_applied_amount(p_charge_id uuid) RETURNS numeric
    LANGUAGE sql STABLE
    AS $$
  select coalesce(sum(pa.amount),0)::numeric
  from payment_allocation pa
  join payment p on p.id = pa.payment_id
  where pa.charge_id = p_charge_id
    and p.status in ('CONFIRMED','PARTIALLY_REFUNDED');
$$;


--
-- Name: osg_commercial_accommodation_nights(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_commercial_accommodation_nights(p_property_id uuid, p_from_date date, p_to_date date) RETURNS TABLE(organization_id uuid, property_id uuid, stay_id uuid, reservation_item_id uuid, night_date date, unit_id uuid, anchor_at timestamp with time zone, finality text, attribution_status text)
    LANGUAGE plpgsql STABLE
    AS $$
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


--
-- Name: osg_expected_arrivals(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_expected_arrivals(p_property_id uuid, p_local_date date) RETURNS TABLE(reservation_id uuid, reservation_item_id uuid, stay_id uuid, unit_id uuid, unit_name text, guest_name text, expected_at timestamp with time zone, commercial_status text, stay_status text, total_guests integer)
    LANGUAGE sql STABLE
    AS $$
  with pol as (
    select * from osg_property_stay_policy_for_date(p_property_id, p_local_date)
  )
  select
    r.id as reservation_id,
    ri.id as reservation_item_id,
    s.id as stay_id,
    ri.assigned_unit_id as unit_id,
    u.name as unit_name,
    pa.display_name as guest_name,
    ((ri.arrival_date::text || ' ' || pol.default_checkin_time::text)::timestamp at time zone pol.timezone) as expected_at,
    r.commercial_status as commercial_status,
    s.status as stay_status,
    (ri.adults + ri.children + ri.infants) as total_guests
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
  order by 7, 5;
$$;


--
-- Name: osg_expected_departures(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_expected_departures(p_property_id uuid, p_local_date date) RETURNS TABLE(reservation_id uuid, reservation_item_id uuid, stay_id uuid, unit_id uuid, unit_name text, guest_name text, expected_at timestamp with time zone, stay_status text)
    LANGUAGE sql STABLE
    AS $$
  with pol as (
    select * from osg_property_stay_policy_for_date(p_property_id, p_local_date)
  )
  select
    r.id as reservation_id,
    ri.id as reservation_item_id,
    s.id as stay_id,
    coalesce(last_seg.unit_id, ri.assigned_unit_id) as unit_id,
    u.name as unit_name,
    pa.display_name as guest_name,
    ((ri.departure_date::text || ' ' || pol.default_checkout_time::text)::timestamp at time zone pol.timezone) as expected_at,
    s.status as stay_status
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
  order by 7, 5;
$$;


--
-- Name: osg_guard_allocation_of_posted_event(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_allocation_of_posted_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_event_id uuid;
  v_status text;
begin
  if tg_op = 'DELETE' then
    v_event_id := old.economic_event_id;
  else
    v_event_id := new.economic_event_id;
  end if;

  select status into v_status
  from economic_event
  where id = v_event_id
  for share;

  if v_status = 'POSTED' then
    raise exception 'OSG_POSTED_ALLOCATION_IMMUTABLE';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end $$;


--
-- Name: osg_guard_allocation_property_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_allocation_property_context() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_event_property uuid;
  v_ref_property uuid;
begin
  select property_id into v_event_property
  from economic_event
  where organization_id=new.organization_id and id=new.economic_event_id;

  if new.classification <> 'NON_BUSINESS' and v_event_property is not null then
    if new.property_id is null or new.property_id is distinct from v_event_property then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.property';
    end if;
  end if;

  if new.unit_id is not null then
    select property_id into v_ref_property from unit
    where organization_id=new.organization_id and id=new.unit_id;
    if new.property_id is null or v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.unit';
    end if;
  end if;

  if new.stay_id is not null then
    v_ref_property := osg_stay_property(new.organization_id,new.stay_id);
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
    if v_ref_property is not null
       and (new.property_id is null or v_ref_property is distinct from new.property_id) then
      raise exception 'PROPERTY_CONTEXT_MISMATCH allocation.cost_center';
    end if;
  end if;

  return new;
end $$;


--
-- Name: osg_guard_charge_reversal(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_charge_reversal() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_original_folio uuid;
  v_original_amount numeric(14,2);
  v_existing_reversal numeric(14,2);
begin
  if new.reverses_charge_id is null then
    return new;
  end if;

  -- The original Charge is the aggregate serialization point for all of its
  -- reversals. FOR UPDATE is intentional even though the original row is not
  -- mutated: concurrent reversal transactions for the same original must not
  -- both calculate the remaining reversible amount from the same snapshot.
  -- Different originals remain independent and can proceed concurrently.
  select folio_id,gross_amount
    into v_original_folio,v_original_amount
  from charge
  where organization_id=new.organization_id
    and id=new.reverses_charge_id
  for update;

  if not found then
    raise exception 'OSG_ORIGINAL_CHARGE_NOT_FOUND';
  end if;

  if new.folio_id <> v_original_folio then
    raise exception 'OSG_CHARGE_REVERSAL_FOLIO_MISMATCH';
  end if;

  if new.gross_amount=0 or sign(new.gross_amount)=sign(v_original_amount) then
    raise exception 'OSG_CHARGE_REVERSAL_SIGN_INVALID';
  end if;

  select coalesce(sum(abs(gross_amount)),0)
    into v_existing_reversal
  from charge
  where organization_id=new.organization_id
    and reverses_charge_id=new.reverses_charge_id
    and id is distinct from new.id
    and status in ('POSTED','RECOGNIZED');

  if new.status in ('POSTED','RECOGNIZED')
     and v_existing_reversal + abs(new.gross_amount) > abs(v_original_amount) + 0.01 then
    raise exception 'OSG_CHARGE_OVER_REVERSED';
  end if;

  return new;
end $$;


--
-- Name: osg_guard_closed_period_event(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_closed_period_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_status text;
begin
  if new.financial_period_id is not null then
    select status into v_status
    from financial_period
    where id = new.financial_period_id
      and organization_id = new.organization_id;

    if v_status = 'HARD_CLOSED' and new.status in ('REVIEWED','POSTED') then
      raise exception 'OSG_FINANCIAL_PERIOD_HARD_CLOSED';
    end if;
  end if;
  return new;
end $$;


--
-- Name: osg_guard_economic_event_period_assignment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_economic_event_period_assignment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_period_property uuid;
  v_period_start date;
  v_period_end date;
  v_period_status text;
  v_related_property uuid;
begin
  if new.status in ('REVIEWED','POSTED') then
    if new.financial_period_id is null then
      new.financial_period_id := osg_resolve_financial_period(
        new.organization_id,
        new.property_id,
        new.economic_date
      );
    end if;

    select property_id,period_start,period_end,status
      into v_period_property,v_period_start,v_period_end,v_period_status
    from financial_period
    where organization_id=new.organization_id
      and id=new.financial_period_id;

    if not found then
      raise exception 'OSG_FINANCIAL_PERIOD_REQUIRED';
    end if;

    if v_period_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH economic_event.financial_period';
    end if;

    if new.economic_date < v_period_start or new.economic_date > v_period_end then
      raise exception 'OSG_ECONOMIC_DATE_OUTSIDE_FINANCIAL_PERIOD';
    end if;

    if v_period_status='HARD_CLOSED' then
      raise exception 'OSG_FINANCIAL_PERIOD_HARD_CLOSED';
    end if;
  end if;

  if new.relates_to_financial_period_id is not null then
    select property_id into v_related_property
    from financial_period
    where organization_id=new.organization_id
      and id=new.relates_to_financial_period_id;

    if not found then
      raise exception 'OSG_RELATED_FINANCIAL_PERIOD_NOT_FOUND';
    end if;

    if v_related_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH economic_event.relates_to_period';
    end if;

    if new.adjustment_reason is null or length(trim(new.adjustment_reason))=0 then
      raise exception 'OSG_ADJUSTMENT_REASON_REQUIRED';
    end if;
  end if;

  return new;
end $$;


--
-- Name: osg_guard_economic_event_reporting_currency(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_economic_event_reporting_currency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_expected_currency char(3);
begin
  if new.status in ('REVIEWED','POSTED') then
    if new.property_id is not null then
      select currency into v_expected_currency
      from property
      where organization_id=new.organization_id and id=new.property_id;
    else
      select default_currency into v_expected_currency
      from organization
      where id=new.organization_id;
    end if;

    if v_expected_currency is null then
      raise exception 'OSG_REPORTING_CURRENCY_NOT_CONFIGURED';
    end if;

    if new.currency <> v_expected_currency then
      raise exception 'OSG_ECONOMIC_EVENT_CURRENCY_MISMATCH expected=% actual=%',
        v_expected_currency,new.currency;
    end if;
  end if;

  return new;
end $$;


--
-- Name: osg_guard_external_reference_target_tenant(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_external_reference_target_tenant() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_target_organization_id uuid;
begin
  case new.osg_entity_type
    when 'Reservation' then
      select organization_id into v_target_organization_id
      from reservation
      where id = new.osg_entity_id;

    when 'Stay' then
      select organization_id into v_target_organization_id
      from stay
      where id = new.osg_entity_id;

    when 'GuestProfile' then
      select organization_id into v_target_organization_id
      from guest_profile
      where id = new.osg_entity_id;

    when 'Folio' then
      select organization_id into v_target_organization_id
      from folio
      where id = new.osg_entity_id;

    when 'Charge' then
      select organization_id into v_target_organization_id
      from charge
      where id = new.osg_entity_id;

    when 'Payment' then
      select organization_id into v_target_organization_id
      from payment
      where id = new.osg_entity_id;

    when 'CashMovement' then
      select organization_id into v_target_organization_id
      from cash_movement
      where id = new.osg_entity_id;

    when 'FinancialDocument' then
      select organization_id into v_target_organization_id
      from financial_document
      where id = new.osg_entity_id;

    when 'EconomicEvent' then
      select organization_id into v_target_organization_id
      from economic_event
      where id = new.osg_entity_id;

    when 'SettlementEntry' then
      select organization_id into v_target_organization_id
      from settlement_entry
      where id = new.osg_entity_id;

    when 'Unit' then
      select organization_id into v_target_organization_id
      from unit
      where id = new.osg_entity_id;

    when 'Resource' then
      select organization_id into v_target_organization_id
      from resource
      where id = new.osg_entity_id;

    when 'Asset' then
      select organization_id into v_target_organization_id
      from asset
      where id = new.osg_entity_id;

    else
      raise exception 'OSG_EXTERNAL_REFERENCE_UNSUPPORTED_ENTITY_TYPE type=%',
        new.osg_entity_type;
  end case;

  if v_target_organization_id is null then
    raise exception 'OSG_EXTERNAL_REFERENCE_TARGET_NOT_FOUND type=% id=%',
      new.osg_entity_type,new.osg_entity_id;
  end if;

  if v_target_organization_id is distinct from new.organization_id then
    raise exception 'OSG_EXTERNAL_REFERENCE_TENANT_MISMATCH type=% id=%',
      new.osg_entity_type,new.osg_entity_id;
  end if;

  return new;
end;
$$;


--
-- Name: osg_guard_final_charge_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_final_charge_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if old.status in ('POSTED','RECOGNIZED') then
    raise exception 'OSG_FINAL_CHARGE_IMMUTABLE';
  end if;
  return old;
end $$;


--
-- Name: osg_guard_final_charge_immutability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_final_charge_immutability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if old.status in ('POSTED','RECOGNIZED') then
    if new.folio_id is distinct from old.folio_id
       or new.charge_type is distinct from old.charge_type
       or new.description is distinct from old.description
       or new.quantity is distinct from old.quantity
       or new.unit_price is distinct from old.unit_price
       or new.gross_amount is distinct from old.gross_amount
       or new.net_amount is distinct from old.net_amount
       or new.tax_amount is distinct from old.tax_amount
       or new.reverses_charge_id is distinct from old.reverses_charge_id then
      raise exception 'OSG_FINAL_CHARGE_IMMUTABLE';
    end if;
  end if;
  return new;
end $$;


--
-- Name: osg_guard_financial_period_transition(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_financial_period_transition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_controlled_reopen text;
begin
  v_controlled_reopen := current_setting('osg.controlled_period_reopen', true);

  -- Boundaries of a HARD_CLOSED period are immutable unless controlled reopen.
  if old.status='HARD_CLOSED' then
    if new.period_start is distinct from old.period_start
       or new.period_end is distinct from old.period_end
       or new.property_id is distinct from old.property_id then
      if coalesce(v_controlled_reopen,'off') <> 'on' then
        raise exception 'OSG_FINANCIAL_PERIOD_HARD_CLOSED';
      end if;
    end if;

    if new.status is distinct from old.status
       and coalesce(v_controlled_reopen,'off') <> 'on' then
      raise exception 'OSG_CONTROLLED_REOPEN_REQUIRED';
    end if;
  end if;

  -- Reopening SOFT_CLOSED to OPEN is also controlled.
  if old.status='SOFT_CLOSED' and new.status='OPEN'
     and coalesce(v_controlled_reopen,'off') <> 'on' then
    raise exception 'OSG_CONTROLLED_REOPEN_REQUIRED';
  end if;

  -- Normal forward transitions only.
  if old.status='OPEN' and new.status not in ('OPEN','SOFT_CLOSED','HARD_CLOSED') then
    raise exception 'OSG_INVALID_PERIOD_TRANSITION';
  end if;
  if old.status='SOFT_CLOSED' and new.status not in ('SOFT_CLOSED','HARD_CLOSED','OPEN') then
    raise exception 'OSG_INVALID_PERIOD_TRANSITION';
  end if;

  if new.status in ('SOFT_CLOSED','HARD_CLOSED') then
    if new.closed_at is null then new.closed_at := now(); end if;
  elsif new.status='OPEN' and old.status<> 'OPEN' then
    -- controlled reopen resets close timestamp; audit/domain workflow preserves history.
    new.closed_at := null;
  end if;

  return new;
end $$;


--
-- Name: osg_guard_folio_close_balance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_folio_close_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_balance numeric;
  v_pending integer;
begin
  if old.status <> 'CLOSED' and new.status='CLOSED' then
    select balance_due,pending_commercial_items
      into v_balance,v_pending
    from osg_folio_balance
    where organization_id=new.organization_id and folio_id=new.id;

    if v_balance is null then
      raise exception 'OSG_FOLIO_BALANCE_UNAVAILABLE';
    end if;

    if abs(v_balance) > 0.01 then
      raise exception 'OSG_FOLIO_BALANCE_NOT_ZERO balance=%',v_balance;
    end if;

    if coalesce(v_pending,0) > 0 then
      raise exception 'OSG_FOLIO_PENDING_ITEMS count=%',v_pending;
    end if;

    if new.closed_at is null then new.closed_at:=now(); end if;
  end if;

  if old.status='CLOSED' and new.status='OPEN' then
    if coalesce(current_setting('osg.controlled_folio_reopen',true),'off') <> 'on' then
      raise exception 'OSG_CONTROLLED_FOLIO_REOPEN_REQUIRED';
    end if;
    new.closed_at:=null;
  end if;

  return new;
end $$;


--
-- Name: osg_guard_guest_profile_alias(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_guest_profile_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_target_alias uuid;
  v_source_alias uuid;
begin
  if new.alias_guest_profile_id = new.canonical_guest_profile_id then
    raise exception 'OSG_GUEST_ALIAS_SELF_REFERENCE';
  end if;

  if new.active then
    -- Canonical target must itself be canonical, not an alias.
    select canonical_guest_profile_id into v_target_alias
    from guest_profile_alias
    where organization_id=new.organization_id
      and alias_guest_profile_id=new.canonical_guest_profile_id
      and active=true
      and id is distinct from new.id
    limit 1;

    if v_target_alias is not null then
      raise exception 'OSG_GUEST_ALIAS_TARGET_NOT_CANONICAL';
    end if;

    -- A canonical profile cannot simultaneously be an alias source and a target
    -- for another active alias; this keeps the mapping one-level/flattened.
    select canonical_guest_profile_id into v_source_alias
    from guest_profile_alias
    where organization_id=new.organization_id
      and canonical_guest_profile_id=new.alias_guest_profile_id
      and active=true
      and id is distinct from new.id
    limit 1;

    if v_source_alias is not null then
      raise exception 'OSG_GUEST_ALIAS_CHAIN_NOT_ALLOWED';
    end if;

    -- Direct two-node cycle defense.
    if exists (
      select 1 from guest_profile_alias ga
      where ga.organization_id=new.organization_id
        and ga.alias_guest_profile_id=new.canonical_guest_profile_id
        and ga.canonical_guest_profile_id=new.alias_guest_profile_id
        and ga.active=true
        and ga.id is distinct from new.id
    ) then
      raise exception 'OSG_GUEST_ALIAS_CYCLE';
    end if;
  end if;

  return new;
end $$;


--
-- Name: osg_guard_hard_closed_existing_event(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_hard_closed_existing_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_period_status text;
begin
  if old.financial_period_id is not null then
    select status into v_period_status
    from financial_period
    where organization_id=old.organization_id
      and id=old.financial_period_id;

    if v_period_status='HARD_CLOSED' then
      raise exception 'OSG_FINANCIAL_PERIOD_HARD_CLOSED';
    end if;
  end if;

  if tg_op='DELETE' then return old; end if;
  return new;
end $$;


--
-- Name: osg_guard_incident_property_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_incident_property_context() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: osg_guard_payment_folio_currency(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_payment_folio_currency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_folio_currency char(3);
begin
  select currency into v_folio_currency
  from folio
  where organization_id=new.organization_id and id=new.folio_id;

  if not found then raise exception 'OSG_FOLIO_NOT_FOUND'; end if;
  if new.currency <> v_folio_currency then
    raise exception 'OSG_FOLIO_CURRENCY_MISMATCH expected=% actual=%',v_folio_currency,new.currency;
  end if;
  return new;
end $$;


--
-- Name: osg_guard_posted_economic_event(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_posted_economic_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if old.status = 'POSTED' then
    if new.amount is distinct from old.amount
       or new.currency is distinct from old.currency
       or new.economic_date is distinct from old.economic_date
       or new.event_type is distinct from old.event_type
       or new.organization_id is distinct from old.organization_id
       or new.property_id is distinct from old.property_id then
      raise exception 'OSG_POSTED_EVENT_IMMUTABLE';
    end if;
  end if;
  return new;
end $$;


--
-- Name: osg_guard_posted_economic_event_v098(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_posted_economic_event_v098() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if old.status = 'POSTED' then
    if new.amount is distinct from old.amount
       or new.currency is distinct from old.currency
       or new.economic_date is distinct from old.economic_date
       or new.event_type is distinct from old.event_type
       or new.effect_direction is distinct from old.effect_direction
       or new.organization_id is distinct from old.organization_id
       or new.property_id is distinct from old.property_id
       or new.reverses_event_id is distinct from old.reverses_event_id then
      raise exception 'OSG_POSTED_EVENT_IMMUTABLE';
    end if;
  end if;
  return new;
end $$;


--
-- Name: osg_guard_refund_payment_currency_and_amount(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_refund_payment_currency_and_amount() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_payment_currency char(3);
  v_payment_amount numeric(14,2);
  v_other_refunds numeric(14,2);
begin
  select currency,amount into v_payment_currency,v_payment_amount
  from payment
  where organization_id=new.organization_id and id=new.payment_id
  for update;

  if not found then raise exception 'OSG_PAYMENT_NOT_FOUND'; end if;
  if new.currency <> v_payment_currency then
    raise exception 'OSG_REFUND_CURRENCY_MISMATCH expected=% actual=%',v_payment_currency,new.currency;
  end if;

  select coalesce(sum(amount),0) into v_other_refunds
  from refund
  where organization_id=new.organization_id
    and payment_id=new.payment_id
    and status='CONFIRMED'
    and id is distinct from new.id;

  if new.status='CONFIRMED' and v_other_refunds + new.amount > v_payment_amount then
    raise exception 'OSG_REFUND_EXCEEDS_PAYMENT';
  end if;
  return new;
end $$;


--
-- Name: osg_guard_reservation_item_property_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_reservation_item_property_context() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_property uuid;
  v_ref_property uuid;
begin
  v_property := osg_reservation_property(new.organization_id,new.reservation_id);

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


--
-- Name: osg_guard_resource_reservation_property_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_resource_reservation_property_context() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_resource_property uuid;
  v_service_property uuid;
begin
  if new.service_booking_id is null then return new; end if;

  select property_id into v_resource_property
  from resource where organization_id=new.organization_id and id=new.resource_id;

  select property_id into v_service_property
  from service_booking where organization_id=new.organization_id and id=new.service_booking_id;

  if v_resource_property is distinct from v_service_property then
    raise exception 'PROPERTY_CONTEXT_MISMATCH resource_reservation';
  end if;
  return new;
end $$;


--
-- Name: osg_guard_service_booking_property_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_service_booking_property_context() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
    v_ref_property := osg_reservation_property(new.organization_id,new.reservation_id);
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH service_booking.reservation';
    end if;
  end if;

  if new.stay_id is not null then
    v_ref_property := osg_stay_property(new.organization_id,new.stay_id);
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH service_booking.stay';
    end if;
  end if;

  return new;
end $$;


--
-- Name: osg_guard_stay_segment_property_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_stay_segment_property_context() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_stay_property uuid;
  v_unit_property uuid;
begin
  v_stay_property := osg_stay_property(new.organization_id,new.stay_id);

  select property_id into v_unit_property
  from unit
  where organization_id=new.organization_id and id=new.unit_id;

  if v_stay_property is null or v_unit_property is distinct from v_stay_property then
    raise exception 'PROPERTY_CONTEXT_MISMATCH stay_segment.unit';
  end if;
  return new;
end $$;


--
-- Name: osg_guard_turnover_property_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_guard_turnover_property_context() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_ref_property uuid;
begin
  select property_id into v_ref_property from unit
  where organization_id=new.organization_id and id=new.unit_id;
  if v_ref_property is distinct from new.property_id then
    raise exception 'PROPERTY_CONTEXT_MISMATCH turnover.unit';
  end if;

  if new.previous_stay_id is not null then
    v_ref_property := osg_stay_property(new.organization_id,new.previous_stay_id);
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH turnover.previous_stay';
    end if;
  end if;

  if new.next_stay_id is not null then
    v_ref_property := osg_stay_property(new.organization_id,new.next_stay_id);
    if v_ref_property is distinct from new.property_id then
      raise exception 'PROPERTY_CONTEXT_MISMATCH turnover.next_stay';
    end if;
  end if;

  return new;
end $$;


--
-- Name: osg_post_economic_event_v02(uuid, uuid, uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_post_economic_event_v02(p_organization_id uuid, p_event_id uuid, p_actor_user_id uuid, p_domain_event_id uuid, p_outbox_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_status text;
  v_amount numeric(14,2);
  v_allocated numeric(14,2);
  v_property_id uuid;
  v_economic_date date;
  v_financial_period_id uuid;
  v_allocation_count integer;
begin
  -- 1. Lock aggregate root in tenant scope.
  select status,amount,property_id,economic_date,financial_period_id
    into v_status,v_amount,v_property_id,v_economic_date,v_financial_period_id
  from economic_event
  where organization_id=p_organization_id and id=p_event_id
  for update;

  if not found then
    raise exception 'ECONOMIC_EVENT_NOT_FOUND';
  end if;

  if v_status not in ('DRAFT','REVIEWED') then
    raise exception 'ECONOMIC_EVENT_INVALID_STATE';
  end if;

  -- 2. Lock current Allocation set and compute conservation.
  perform 1
  from allocation
  where organization_id=p_organization_id
    and economic_event_id=p_event_id
  order by id
  for update;

  select coalesce(sum(amount),0),count(*)
    into v_allocated,v_allocation_count
  from allocation
  where organization_id=p_organization_id
    and economic_event_id=p_event_id;

  if round(v_allocated,2) <> round(v_amount,2) then
    raise exception 'OSG_ALLOCATION_NOT_BALANCED event=% expected=% actual=%',
      p_event_id,v_amount,v_allocated;
  end if;

  if v_allocation_count=0 and v_amount<>0 then
    raise exception 'OSG_ALLOCATION_REQUIRED';
  end if;

  -- 3. Ensure a valid period exists before final state transition.
  if v_financial_period_id is null then
    v_financial_period_id := osg_resolve_financial_period(
      p_organization_id,v_property_id,v_economic_date
    );

    update economic_event
      set financial_period_id=v_financial_period_id
    where organization_id=p_organization_id and id=p_event_id;
  end if;

  perform osg_assert_target_period_open_for_post(p_event_id);

  -- 4. Approval-policy evaluation is performed by application/domain layer before
  -- entering this function. DB approval artifacts remain auditable and permission
  -- checks are not delegated to this proof function.

  -- 5. Final state transition. Period/property/immutability triggers execute here.
  update economic_event
  set status='POSTED',
      posted_at=now(),
      posted_by_user_id=p_actor_user_id,
      row_version=row_version+1
  where organization_id=p_organization_id and id=p_event_id;

  -- Defense-in-depth after status transition; transaction rolls back on failure.
  perform osg_assert_economic_event_balanced(p_event_id);

  -- 6. Domain event written in same transaction as state.
  insert into domain_event (
    id,organization_id,property_id,event_type,event_version,
    aggregate_type,aggregate_id,aggregate_version,occurred_at,
    actor_type,actor_id,payload
  )
  select
    p_domain_event_id,
    ee.organization_id,
    ee.property_id,
    'EconomicEvent.Posted',
    1,
    'EconomicEvent',
    ee.id,
    ee.row_version,
    now(),
    'USER',
    p_actor_user_id,
    jsonb_build_object(
      'economic_event_id',ee.id,
      'event_type',ee.event_type,
      'effect_direction',ee.effect_direction,
      'economic_date',ee.economic_date,
      'amount',ee.amount,
      'currency',ee.currency,
      'financial_period_id',ee.financial_period_id,
      'allocation_count',v_allocation_count
    )
  from economic_event ee
  where ee.organization_id=p_organization_id and ee.id=p_event_id;

  -- 7. Outbox record guarantees post-commit delivery/retry.
  insert into outbox_event (
    id,organization_id,domain_event_id,status,available_at,attempts
  ) values (
    p_outbox_id,p_organization_id,p_domain_event_id,'PENDING',now(),0
  );
end;
$$;


--
-- Name: osg_property_cash_flow(uuid, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_property_cash_flow(p_property_id uuid, p_from_ts timestamp with time zone, p_to_ts timestamp with time zone) RETURNS TABLE(property_id uuid, cash_in numeric, cash_out numeric, net_cash_change numeric)
    LANGUAGE sql STABLE
    AS $$
  select
    p_property_id,
    coalesce(sum(cl.signed_amount) filter (where cl.signed_amount > 0),0),
    coalesce(sum(-cl.signed_amount) filter (where cl.signed_amount < 0),0),
    coalesce(sum(cl.signed_amount),0)
  from osg_cash_leg cl
  join money_account ma
    on ma.organization_id = cl.organization_id
   and ma.id = cl.money_account_id
  where ma.property_id = p_property_id
    and cl.occurred_at >= p_from_ts
    and cl.occurred_at < p_to_ts
    and cl.status in ('IMPORTED','VERIFIED');
$$;


--
-- Name: osg_property_economic_result(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_property_economic_result(p_property_id uuid, p_from_date date, p_to_date date) RETURNS TABLE(property_id uuid, from_date date, to_date date, net_allocated_revenue numeric, net_allocated_opex numeric, economic_operating_result numeric, net_capex numeric, non_business_excluded numeric, weighted_data_confidence numeric)
    LANGUAGE sql STABLE
    AS $$
  select
    p_property_id,
    p_from_date,
    p_to_date,
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0),
    coalesce(sum(af.signed_category_amount) filter (where af.classification='OPEX'),0),
    coalesce(sum(af.operating_result_effect),0),
    coalesce(sum(af.capex_amount),0),
    coalesce(sum(af.non_business_amount),0),
    case
      when coalesce(sum(abs(af.amount)) filter (
        where af.classification in ('REVENUE','OPEX','CAPEX')),0)=0 then null
      else
        sum(abs(af.amount) * af.confidence_weight)
          filter (where af.classification in ('REVENUE','OPEX','CAPEX'))
        / nullif(sum(abs(af.amount))
          filter (where af.classification in ('REVENUE','OPEX','CAPEX')),0)
    end
  from osg_allocation_fact af
  where af.property_id = p_property_id
    and af.economic_date between p_from_date and p_to_date;
$$;


--
-- Name: osg_property_occupancy_metrics(uuid, date, date, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_property_occupancy_metrics(p_property_id uuid, p_from_date date, p_to_date date, p_include_provisional boolean DEFAULT false) RETURNS TABLE(property_id uuid, commercial_nights bigint, resolved_commercial_nights bigint, sellable_unit_nights bigint, effective_capacity_nights bigint, occupancy numeric, unresolved_nights bigint)
    LANGUAGE sql STABLE
    AS $$
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


--
-- Name: osg_property_revenue_metrics(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_property_revenue_metrics(p_property_id uuid, p_from_date date, p_to_date date) RETURNS TABLE(property_id uuid, from_date date, to_date date, accommodation_revenue numeric, total_revenue numeric, commercial_accommodation_nights bigint, raw_sellable_unit_nights bigint, effective_capacity_unit_nights bigint, adr numeric, revpar numeric, trevpar numeric)
    LANGUAGE sql STABLE
    AS $$
with occ as (
  select *
  from osg_property_occupancy_metrics(p_property_id,p_from_date,p_to_date,false)
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
  o.resolved_commercial_nights,
  o.sellable_unit_nights,
  o.effective_capacity_nights,
  r.accommodation_revenue / nullif(o.resolved_commercial_nights,0) as adr,
  r.accommodation_revenue / nullif(o.effective_capacity_nights,0) as revpar,
  r.total_revenue / nullif(o.effective_capacity_nights,0) as trevpar
from recognized r cross join occ o;
$$;


--
-- Name: osg_property_stay_policy_for_date(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_property_stay_policy_for_date(p_property_id uuid, p_local_date date) RETURNS TABLE(organization_id uuid, property_id uuid, timezone text, default_checkin_time time without time zone, default_checkout_time time without time zone, readiness_buffer interval, overnight_anchor_time time without time zone, policy_version integer)
    LANGUAGE sql STABLE
    AS $$
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


--
-- Name: osg_property_upsell_metrics(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_property_upsell_metrics(p_property_id uuid, p_from_date date, p_to_date date) RETURNS TABLE(completed_stays bigint, upsell_revenue numeric, upsell_per_completed_stay numeric)
    LANGUAGE sql STABLE
    AS $$
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


--
-- Name: osg_repeat_guest_rate(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_repeat_guest_rate(p_property_id uuid, p_from_date date, p_to_date date) RETURNS TABLE(property_id uuid, eligible_completed_stays bigint, returning_guest_stays bigint, repeat_guest_rate numeric)
    LANGUAGE sql STABLE
    AS $$
with property_ctx as (
  select timezone from property where id=p_property_id
), target_stays as (
  select f.*
  from osg_completed_stay_guest_fact f
  cross join property_ctx p
  where f.property_id=p_property_id
    and (f.actual_checkout_at at time zone p.timezone)::date between p_from_date and p_to_date
), classified as (
  select
    ts.*,
    exists (
      select 1
      from osg_completed_stay_guest_fact prev
      where prev.organization_id=ts.organization_id
        and prev.canonical_guest_profile_id=ts.canonical_guest_profile_id
        and prev.actual_checkout_at < ts.actual_checkout_at
        and prev.stay_id <> ts.stay_id
    ) as is_returning
  from target_stays ts
)
select
  p_property_id,
  count(*),
  count(*) filter (where is_returning),
  count(*) filter (where is_returning)::numeric / nullif(count(*),0)
from classified;
$$;


--
-- Name: osg_reservation_item_property(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_reservation_item_property(p_organization_id uuid, p_reservation_item_id uuid) RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select r.property_id
  from reservation_item ri
  join reservation r
    on r.organization_id=ri.organization_id and r.id=ri.reservation_id
  where ri.organization_id=p_organization_id and ri.id=p_reservation_item_id
$$;


--
-- Name: osg_reservation_property(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_reservation_property(p_organization_id uuid, p_reservation_id uuid) RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select property_id
  from reservation
  where organization_id=p_organization_id and id=p_reservation_id
$$;


--
-- Name: osg_resolve_financial_period(uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_resolve_financial_period(p_organization_id uuid, p_property_id uuid, p_economic_date date) RETURNS uuid
    LANGUAGE plpgsql STABLE
    AS $$
declare
  v_id uuid;
  v_count integer;
  v_status text;
begin
  select count(*)
    into v_count
  from financial_period
  where organization_id=p_organization_id
    and property_id is not distinct from p_property_id
    and p_economic_date between period_start and period_end;

  if v_count=0 then
    raise exception 'OSG_FINANCIAL_PERIOD_REQUIRED';
  elsif v_count>1 then
    raise exception 'OSG_FINANCIAL_PERIOD_AMBIGUOUS';
  end if;

  select id,status
    into v_id,v_status
  from financial_period
  where organization_id=p_organization_id
    and property_id is not distinct from p_property_id
    and p_economic_date between period_start and period_end;

  if v_status='HARD_CLOSED' then
    raise exception 'OSG_FINANCIAL_PERIOD_HARD_CLOSED';
  end if;

  return v_id;
end $$;


--
-- Name: osg_stay_contribution_margin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_stay_contribution_margin(p_stay_id uuid) RETURNS TABLE(stay_id uuid, net_revenue numeric, net_direct_variable_cost numeric, contribution_margin numeric, data_confidence numeric)
    LANGUAGE sql STABLE
    AS $$
  select
    p_stay_id,
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0),
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='OPEX' and af.allocation_type='DIRECT'),0),
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0)
      - coalesce(sum(af.signed_category_amount) filter (
          where af.classification='OPEX' and af.allocation_type='DIRECT'),0),
    case when sum(abs(af.amount)) filter (where af.classification in ('REVENUE','OPEX')) > 0
      then sum(abs(af.amount) * af.confidence_weight)
        filter (where af.classification in ('REVENUE','OPEX'))
        / nullif(sum(abs(af.amount)) filter (where af.classification in ('REVENUE','OPEX')),0)
      else null end
  from osg_allocation_fact af
  where af.stay_id = p_stay_id;
$$;


--
-- Name: osg_stay_property(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_stay_property(p_organization_id uuid, p_stay_id uuid) RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select r.property_id
  from stay s
  join reservation_item ri
    on ri.organization_id=s.organization_id and ri.id=s.reservation_item_id
  join reservation r
    on r.organization_id=ri.organization_id and r.id=ri.reservation_id
  where s.organization_id=p_organization_id and s.id=p_stay_id
$$;


--
-- Name: osg_stay_revenue_metrics(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_stay_revenue_metrics(p_stay_id uuid) RETURNS TABLE(stay_id uuid, accommodation_revenue numeric, upsell_revenue numeric, total_stay_revenue numeric, actual_guest_count integer, revenue_per_guest numeric)
    LANGUAGE sql STABLE
    AS $$
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


--
-- Name: osg_unit_economics(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_unit_economics(p_property_id uuid, p_from_date date, p_to_date date) RETURNS TABLE(unit_id uuid, net_revenue numeric, net_direct_opex numeric, net_shared_opex numeric, net_overhead numeric, contribution_margin numeric, operating_margin numeric, net_capex numeric, data_confidence numeric)
    LANGUAGE sql STABLE
    AS $$
  select
    af.unit_id,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='REVENUE'),0) as net_revenue,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='OPEX' and af.allocation_type='DIRECT'),0) as net_direct_opex,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='OPEX' and af.allocation_type='SHARED'),0) as net_shared_opex,
    coalesce(sum(af.signed_category_amount) filter (
      where af.classification='OPEX' and af.allocation_type='OVERHEAD'),0) as net_overhead,
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0)
      - coalesce(sum(af.signed_category_amount) filter (
          where af.classification='OPEX' and af.allocation_type='DIRECT'),0)
      as contribution_margin,
    coalesce(sum(af.signed_category_amount) filter (where af.classification='REVENUE'),0)
      - coalesce(sum(af.signed_category_amount) filter (
          where af.classification='OPEX' and af.allocation_type in ('DIRECT','SHARED','OVERHEAD')),0)
      as operating_margin,
    coalesce(sum(af.capex_amount),0) as net_capex,
    case when sum(abs(af.amount)) filter (
      where af.classification in ('REVENUE','OPEX','CAPEX')) > 0
      then sum(abs(af.amount) * af.confidence_weight)
        filter (where af.classification in ('REVENUE','OPEX','CAPEX'))
        / nullif(sum(abs(af.amount))
          filter (where af.classification in ('REVENUE','OPEX','CAPEX')),0)
      else null end as data_confidence
  from osg_allocation_fact af
  where af.property_id = p_property_id
    and af.unit_id is not null
    and af.economic_date between p_from_date and p_to_date
  group by af.unit_id;
$$;


--
-- Name: osg_unit_night_facts(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.osg_unit_night_facts(p_property_id uuid, p_from_date date, p_to_date date) RETURNS TABLE(organization_id uuid, property_id uuid, unit_id uuid, local_night_date date, operational_start_at timestamp with time zone, operational_end_at timestamp with time zone, physical_capacity boolean, sellable_capacity boolean, physically_occupied boolean)
    LANGUAGE plpgsql STABLE
    AS $$
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: allocation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allocation (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    economic_event_id uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    property_id uuid,
    unit_id uuid,
    stay_id uuid,
    resource_id uuid,
    asset_id uuid,
    service_id uuid,
    channel_id uuid,
    investment_project_id uuid,
    cost_center_id uuid,
    paid_by_party_id uuid,
    economic_bearer_party_id uuid,
    allocation_type text NOT NULL,
    classification text NOT NULL,
    confidence text NOT NULL,
    allocation_method text,
    rationale text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    allocation_rule_id uuid,
    CONSTRAINT allocation_allocation_type_check CHECK ((allocation_type = ANY (ARRAY['DIRECT'::text, 'SHARED'::text, 'OVERHEAD'::text, 'NON_BUSINESS'::text]))),
    CONSTRAINT allocation_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT allocation_check CHECK (((confidence <> ALL (ARRAY['ESTIMATED'::text, 'MANUAL'::text])) OR (rationale IS NOT NULL))),
    CONSTRAINT allocation_classification_check CHECK ((classification = ANY (ARRAY['REVENUE'::text, 'OPEX'::text, 'CAPEX'::text, 'NON_BUSINESS'::text, 'OTHER'::text]))),
    CONSTRAINT allocation_confidence_check CHECK ((confidence = ANY (ARRAY['VERIFIED'::text, 'SYSTEM_DERIVED'::text, 'ESTIMATED'::text, 'MANUAL'::text, 'UNKNOWN'::text])))
);


--
-- Name: allocation_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allocation_rule (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    code text NOT NULL,
    version_no integer NOT NULL,
    basis text NOT NULL,
    configuration jsonb DEFAULT '{}'::jsonb NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT allocation_rule_basis_check CHECK ((basis = ANY (ARRAY['EQUAL'::text, 'REVENUE_SHARE'::text, 'OCCUPIED_NIGHTS'::text, 'AVAILABLE_NIGHTS'::text, 'AREA_M2'::text, 'GUEST_NIGHTS'::text, 'USAGE_METER'::text, 'MANUAL_PERCENTAGE'::text, 'CUSTOM'::text]))),
    CONSTRAINT allocation_rule_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT allocation_rule_version_no_check CHECK ((version_no > 0))
);


--
-- Name: approval_decision; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_decision (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    approval_request_id uuid NOT NULL,
    approver_user_id uuid NOT NULL,
    decision text NOT NULL,
    reason text,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT approval_decision_decision_check CHECK ((decision = ANY (ARRAY['APPROVE'::text, 'REJECT'::text])))
);


--
-- Name: approval_policy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_policy (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    code text NOT NULL,
    version_no integer NOT NULL,
    conditions jsonb DEFAULT '{}'::jsonb NOT NULL,
    outcome text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    valid_from timestamp with time zone DEFAULT now() NOT NULL,
    valid_to timestamp with time zone,
    CONSTRAINT approval_policy_check CHECK (((valid_to IS NULL) OR (valid_to > valid_from))),
    CONSTRAINT approval_policy_outcome_check CHECK ((outcome = ANY (ARRAY['NO_APPROVAL'::text, 'SINGLE_APPROVAL'::text, 'DUAL_CONTROL'::text, 'OWNER_APPROVAL'::text, 'FINANCE_APPROVAL'::text, 'CUSTOM_CHAIN'::text]))),
    CONSTRAINT approval_policy_version_no_check CHECK ((version_no > 0))
);


--
-- Name: approval_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_request (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    subject_type text NOT NULL,
    subject_id uuid NOT NULL,
    subject_version bigint,
    policy_code text NOT NULL,
    policy_version integer NOT NULL,
    requested_by_user_id uuid NOT NULL,
    status text NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    risk_context jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT approval_request_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'APPROVED'::text, 'REJECTED'::text, 'EXPIRED'::text, 'CANCELLED'::text])))
);


--
-- Name: asset; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asset (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    unit_id uuid,
    resource_id uuid,
    zone_id uuid,
    name text NOT NULL,
    asset_type text NOT NULL,
    manufacturer text,
    model text,
    serial_number text,
    installed_at date,
    purchase_date date,
    warranty_until date,
    lifecycle_status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT asset_check CHECK ((num_nonnulls(unit_id, resource_id, zone_id) <= 1)),
    CONSTRAINT asset_lifecycle_status_check CHECK ((lifecycle_status = ANY (ARRAY['PLANNED'::text, 'ORDERED'::text, 'INSTALLED'::text, 'ACTIVE'::text, 'DEGRADED'::text, 'FAILED'::text, 'RETIRED'::text])))
);


--
-- Name: attachment_link; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachment_link (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    file_object_id uuid NOT NULL,
    context_type text NOT NULL,
    context_id uuid NOT NULL,
    purpose text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_event (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    actor_type text NOT NULL,
    actor_id uuid,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    action text NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id uuid,
    source text,
    changes jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: automation_execution; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.automation_execution (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    automation_rule_id uuid NOT NULL,
    trigger_event_id uuid NOT NULL,
    action_key text NOT NULL,
    status text NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    retry_count integer DEFAULT 0 NOT NULL,
    error text,
    result jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT automation_execution_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'RUNNING'::text, 'SUCCEEDED'::text, 'FAILED_RETRYABLE'::text, 'FAILED_FINAL'::text, 'SKIPPED'::text])))
);


--
-- Name: automation_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.automation_rule (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    code text NOT NULL,
    version_no integer NOT NULL,
    trigger_event_type text NOT NULL,
    conditions jsonb DEFAULT '{}'::jsonb NOT NULL,
    actions jsonb NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT automation_rule_version_no_check CHECK ((version_no > 0))
);


--
-- Name: availability_block; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.availability_block (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    unit_id uuid,
    resource_id uuid,
    start_at timestamp with time zone NOT NULL,
    end_at timestamp with time zone NOT NULL,
    reason_type text NOT NULL,
    reason_text text,
    source_incident_id uuid,
    status text DEFAULT 'ACTIVE'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    ended_at timestamp with time zone,
    sellability_impact boolean DEFAULT true NOT NULL,
    operations_impact boolean DEFAULT true NOT NULL,
    guest_impact boolean DEFAULT false NOT NULL,
    CONSTRAINT availability_block_check CHECK ((end_at > start_at)),
    CONSTRAINT availability_block_check1 CHECK ((num_nonnulls(unit_id, resource_id) = 1)),
    CONSTRAINT availability_block_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'ENDED'::text, 'CANCELLED'::text])))
);


--
-- Name: COLUMN availability_block.sellability_impact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.availability_block.sellability_impact IS 'If true, overlapping operational unit-night/resource window is unavailable for sale/capacity metrics.';


--
-- Name: COLUMN availability_block.operations_impact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.availability_block.operations_impact IS 'If true, block should surface in operations/maintenance workflows even when sale may remain possible.';


--
-- Name: COLUMN availability_block.guest_impact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.availability_block.guest_impact IS 'If true, current/expected guest experience is materially affected and conflict/escalation workflow should evaluate impact.';


--
-- Name: cash_movement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cash_movement (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    from_money_account_id uuid,
    to_money_account_id uuid,
    amount numeric(14,2) NOT NULL,
    currency character(3) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    external_reference text,
    source_fingerprint text,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cash_movement_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT cash_movement_check CHECK ((num_nonnulls(from_money_account_id, to_money_account_id) >= 1)),
    CONSTRAINT cash_movement_check1 CHECK (((from_money_account_id IS NULL) OR (to_money_account_id IS NULL) OR (from_money_account_id <> to_money_account_id))),
    CONSTRAINT cash_movement_status_check CHECK ((status = ANY (ARRAY['IMPORTED'::text, 'VERIFIED'::text, 'REVERSED'::text, 'IGNORED'::text])))
);


--
-- Name: channel; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channel (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    channel_type text NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: charge; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charge (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    folio_id uuid NOT NULL,
    charge_type text NOT NULL,
    description text NOT NULL,
    quantity numeric(12,3) DEFAULT 1 NOT NULL,
    unit_price numeric(14,2) NOT NULL,
    gross_amount numeric(14,2) NOT NULL,
    net_amount numeric(14,2),
    tax_amount numeric(14,2),
    recognized_at timestamp with time zone,
    status text NOT NULL,
    reverses_charge_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT charge_charge_type_check CHECK ((charge_type = ANY (ARRAY['ACCOMMODATION'::text, 'SERVICE'::text, 'FEE'::text, 'TAX'::text, 'DISCOUNT'::text, 'DAMAGE'::text, 'CANCELLATION'::text, 'OTHER'::text]))),
    CONSTRAINT charge_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'POSTED'::text, 'RECOGNIZED'::text])))
);


--
-- Name: command_idempotency; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.command_idempotency (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    principal_key text NOT NULL,
    command_name text NOT NULL,
    idempotency_key text NOT NULL,
    request_hash text NOT NULL,
    status text NOT NULL,
    aggregate_type text,
    aggregate_id uuid,
    http_status integer,
    response_body jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    expires_at timestamp with time zone,
    CONSTRAINT command_idempotency_http_status_check CHECK (((http_status IS NULL) OR ((http_status >= 100) AND (http_status <= 599)))),
    CONSTRAINT command_idempotency_idempotency_key_check CHECK ((length(idempotency_key) >= 8)),
    CONSTRAINT command_idempotency_status_check CHECK ((status = ANY (ARRAY['IN_PROGRESS'::text, 'SUCCEEDED'::text, 'FAILED_RETRYABLE'::text, 'FAILED_FINAL'::text])))
);


--
-- Name: commercial_policy_snapshot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commercial_policy_snapshot (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    reservation_id uuid NOT NULL,
    reservation_item_id uuid,
    version_no integer NOT NULL,
    currency character(3) NOT NULL,
    quoted_total numeric(14,2),
    cancellation_policy jsonb DEFAULT '{}'::jsonb NOT NULL,
    pricing_breakdown jsonb DEFAULT '{}'::jsonb NOT NULL,
    deposit_terms jsonb DEFAULT '{}'::jsonb NOT NULL,
    source_reference text,
    effective_at timestamp with time zone NOT NULL,
    supersedes_snapshot_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: commission_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commission_rule (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    channel_id uuid NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    commission_type text NOT NULL,
    percent_rate numeric(7,4),
    fixed_amount numeric(14,2),
    currency character(3),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT commission_rule_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT commission_rule_commission_type_check CHECK ((commission_type = ANY (ARRAY['PERCENT'::text, 'FIXED'::text, 'HYBRID'::text])))
);


--
-- Name: communication_consent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.communication_consent (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    guest_profile_id uuid NOT NULL,
    consent_type text NOT NULL,
    status text NOT NULL,
    content_version text,
    source text NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT communication_consent_status_check CHECK ((status = ANY (ARRAY['GRANTED'::text, 'WITHDRAWN'::text, 'NOT_REQUIRED'::text])))
);


--
-- Name: conflict_case; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conflict_case (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    availability_block_id uuid,
    reservation_item_id uuid,
    stay_id uuid,
    severity text NOT NULL,
    reason text NOT NULL,
    status text NOT NULL,
    resolution_type text,
    resolved_by_user_id uuid,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT conflict_case_severity_check CHECK ((severity = ANY (ARRAY['LOW'::text, 'MEDIUM'::text, 'HIGH'::text, 'CRITICAL'::text]))),
    CONSTRAINT conflict_case_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'IN_REVIEW'::text, 'RESOLVED'::text, 'CANCELLED'::text])))
);


--
-- Name: conversation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    guest_profile_id uuid,
    reservation_id uuid,
    stay_id uuid,
    status text DEFAULT 'OPEN'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT conversation_check CHECK ((num_nonnulls(guest_profile_id, reservation_id, stay_id) >= 1)),
    CONSTRAINT conversation_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'CLOSED'::text, 'ARCHIVED'::text])))
);


--
-- Name: cost_center; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cost_center (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    code text NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: data_quality_issue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_quality_issue (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    issue_type text NOT NULL,
    severity text NOT NULL,
    subject_type text,
    subject_id uuid,
    status text NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    detected_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    CONSTRAINT data_quality_issue_severity_check CHECK ((severity = ANY (ARRAY['INFO'::text, 'LOW'::text, 'MEDIUM'::text, 'HIGH'::text, 'CRITICAL'::text]))),
    CONSTRAINT data_quality_issue_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'ACKNOWLEDGED'::text, 'RESOLVED'::text, 'IGNORED'::text])))
);


--
-- Name: domain_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.domain_event (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    event_type text NOT NULL,
    event_version integer DEFAULT 1 NOT NULL,
    aggregate_type text NOT NULL,
    aggregate_id uuid NOT NULL,
    aggregate_version bigint,
    occurred_at timestamp with time zone NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    correlation_id uuid,
    causation_id uuid,
    actor_type text,
    actor_id uuid,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT domain_event_event_version_check CHECK ((event_version > 0))
);


--
-- Name: economic_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economic_event (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    financial_period_id uuid,
    event_type text NOT NULL,
    economic_date date NOT NULL,
    amount numeric(14,2) NOT NULL,
    currency character(3) NOT NULL,
    source_document_line_id uuid,
    source_charge_id uuid,
    reverses_event_id uuid,
    status text NOT NULL,
    posted_at timestamp with time zone,
    posted_by_user_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    relates_to_financial_period_id uuid,
    adjustment_reason text,
    effect_direction text DEFAULT 'NORMAL'::text NOT NULL,
    CONSTRAINT economic_event_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT economic_event_effect_direction_check CHECK ((effect_direction = ANY (ARRAY['NORMAL'::text, 'REVERSAL'::text]))),
    CONSTRAINT economic_event_event_type_check CHECK ((event_type = ANY (ARRAY['REVENUE'::text, 'OPEX'::text, 'CAPEX'::text, 'OTA_COMMISSION'::text, 'PAYMENT_FEE'::text, 'REFUND'::text, 'TAX'::text, 'OWNER_CONTRIBUTION'::text, 'OWNER_WITHDRAWAL'::text, 'TRANSFER'::text, 'SETTLEMENT'::text, 'WRITE_OFF'::text, 'ROUNDING'::text, 'ADJUSTMENT'::text]))),
    CONSTRAINT economic_event_status_check CHECK ((status = ANY (ARRAY['DRAFT'::text, 'REVIEWED'::text, 'POSTED'::text, 'REVERSED'::text])))
);


--
-- Name: COLUMN economic_event.effect_direction; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.economic_event.effect_direction IS 'NORMAL applies the natural effect of Allocation.classification; REVERSAL applies the opposite effect while preserving the original economic category.';


--
-- Name: external_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_record (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    integration_id uuid NOT NULL,
    external_type text NOT NULL,
    external_id text NOT NULL,
    source_version text,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    payload_hash text NOT NULL,
    payload jsonb,
    processing_status text NOT NULL,
    CONSTRAINT external_record_processing_status_check CHECK ((processing_status = ANY (ARRAY['RECEIVED'::text, 'PROCESSING'::text, 'MAPPED'::text, 'REJECTED'::text, 'DUPLICATE'::text, 'FAILED'::text])))
);


--
-- Name: external_reference; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_reference (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    integration_id uuid NOT NULL,
    external_type text NOT NULL,
    external_id text NOT NULL,
    osg_entity_type text NOT NULL,
    osg_entity_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: extraction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.extraction (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    file_object_id uuid NOT NULL,
    extractor text NOT NULL,
    extractor_version text,
    confidence numeric(5,4),
    result jsonb NOT NULL,
    validation_status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT extraction_confidence_check CHECK (((confidence IS NULL) OR ((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)))),
    CONSTRAINT extraction_validation_status_check CHECK ((validation_status = ANY (ARRAY['UNVALIDATED'::text, 'VALIDATED'::text, 'REJECTED'::text])))
);


--
-- Name: file_object; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.file_object (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    storage_key text NOT NULL,
    mime_type text NOT NULL,
    size_bytes bigint NOT NULL,
    checksum_sha256 text NOT NULL,
    classification text NOT NULL,
    retention_class text,
    uploaded_by_user_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    archived_at timestamp with time zone,
    CONSTRAINT file_object_classification_check CHECK ((classification = ANY (ARRAY['PUBLIC'::text, 'INTERNAL'::text, 'CONFIDENTIAL'::text, 'PERSONAL'::text, 'SENSITIVE_OPERATIONAL'::text, 'FINANCIAL'::text, 'SECURITY'::text]))),
    CONSTRAINT file_object_size_bytes_check CHECK ((size_bytes >= 0))
);


--
-- Name: financial_document; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.financial_document (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    document_type text NOT NULL,
    document_number text,
    issuer_party_id uuid,
    recipient_party_id uuid,
    issue_date date,
    service_date date,
    due_date date,
    currency character(3) NOT NULL,
    gross_total numeric(14,2) NOT NULL,
    net_total numeric(14,2),
    tax_total numeric(14,2),
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT financial_document_status_check CHECK ((status = ANY (ARRAY['DRAFT'::text, 'VERIFIED'::text, 'POSTED'::text, 'CORRECTED'::text])))
);


--
-- Name: financial_document_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.financial_document_line (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    financial_document_id uuid NOT NULL,
    line_no integer,
    description text NOT NULL,
    quantity numeric(12,3),
    gross_amount numeric(14,2) NOT NULL,
    net_amount numeric(14,2),
    tax_amount numeric(14,2)
);


--
-- Name: financial_period; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.financial_period (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    period_start date NOT NULL,
    period_end date NOT NULL,
    status text NOT NULL,
    closed_at timestamp with time zone,
    closed_by_user_id uuid,
    CONSTRAINT financial_period_check CHECK ((period_end >= period_start)),
    CONSTRAINT financial_period_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'SOFT_CLOSED'::text, 'HARD_CLOSED'::text])))
);


--
-- Name: folio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folio (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    reservation_id uuid NOT NULL,
    stay_id uuid,
    currency character(3) NOT NULL,
    status text NOT NULL,
    opened_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT folio_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'CLOSED'::text, 'VOID'::text])))
);


--
-- Name: guest_identity_signal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guest_identity_signal (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    guest_profile_id uuid NOT NULL,
    signal_type text NOT NULL,
    normalized_value text,
    value_hash text,
    source text NOT NULL,
    confidence text DEFAULT 'UNKNOWN'::text NOT NULL,
    verified_at timestamp with time zone,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT guest_identity_signal_check CHECK ((num_nonnulls(normalized_value, value_hash) >= 1)),
    CONSTRAINT guest_identity_signal_confidence_check CHECK ((confidence = ANY (ARRAY['VERIFIED'::text, 'SYSTEM_DERIVED'::text, 'ESTIMATED'::text, 'MANUAL'::text, 'UNKNOWN'::text]))),
    CONSTRAINT guest_identity_signal_signal_type_check CHECK ((signal_type = ANY (ARRAY['EMAIL'::text, 'PHONE'::text, 'EXTERNAL_CUSTOMER_ID'::text, 'HASHED_SOURCE_ID'::text, 'OTHER'::text])))
);


--
-- Name: guest_match_candidate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guest_match_candidate (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    guest_profile_a_id uuid NOT NULL,
    guest_profile_b_id uuid NOT NULL,
    match_method text NOT NULL,
    method_version text,
    confidence numeric(5,4),
    evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    reviewed_at timestamp with time zone,
    reviewed_by_user_id uuid,
    CONSTRAINT guest_match_candidate_check CHECK ((guest_profile_a_id <> guest_profile_b_id)),
    CONSTRAINT guest_match_candidate_confidence_check CHECK (((confidence IS NULL) OR ((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)))),
    CONSTRAINT guest_match_candidate_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'CONFIRMED_MATCH'::text, 'REJECTED'::text, 'EXPIRED'::text])))
);


--
-- Name: guest_merge_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guest_merge_event (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    canonical_guest_profile_id uuid NOT NULL,
    merged_guest_profile_id uuid NOT NULL,
    match_candidate_id uuid,
    action text NOT NULL,
    reason text NOT NULL,
    actor_user_id uuid,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT guest_merge_event_action_check CHECK ((action = ANY (ARRAY['MERGE'::text, 'UNDO_MERGE'::text]))),
    CONSTRAINT guest_merge_event_check CHECK ((canonical_guest_profile_id <> merged_guest_profile_id))
);


--
-- Name: guest_profile; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guest_profile (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    party_id uuid NOT NULL,
    preferred_language text,
    crm_status text DEFAULT 'ACTIVE'::text NOT NULL,
    first_seen_at timestamp with time zone,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT guest_profile_crm_status_check CHECK ((crm_status = ANY (ARRAY['ACTIVE'::text, 'BLOCKED'::text, 'ARCHIVED'::text])))
);


--
-- Name: guest_profile_alias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guest_profile_alias (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    alias_guest_profile_id uuid NOT NULL,
    canonical_guest_profile_id uuid NOT NULL,
    active boolean DEFAULT true NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT guest_profile_alias_check CHECK ((alias_guest_profile_id <> canonical_guest_profile_id)),
    CONSTRAINT guest_profile_alias_check1 CHECK (((effective_to IS NULL) OR (effective_to > effective_from)))
);


--
-- Name: incident; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incident (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    unit_id uuid,
    resource_id uuid,
    asset_id uuid,
    severity text NOT NULL,
    status text NOT NULL,
    title text NOT NULL,
    description text,
    guest_impact boolean DEFAULT false NOT NULL,
    safety_related boolean DEFAULT false NOT NULL,
    reported_at timestamp with time zone NOT NULL,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT incident_severity_check CHECK ((severity = ANY (ARRAY['LOW'::text, 'MEDIUM'::text, 'HIGH'::text, 'CRITICAL'::text]))),
    CONSTRAINT incident_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'TRIAGED'::text, 'IN_REPAIR'::text, 'RESOLVED'::text, 'CLOSED'::text])))
);


--
-- Name: integration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    provider text NOT NULL,
    integration_type text NOT NULL,
    status text NOT NULL,
    sync_mode text NOT NULL,
    credentials_reference text,
    last_success_at timestamp with time zone,
    last_failure_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT integration_integration_type_check CHECK ((integration_type = ANY (ARRAY['RESERVATION_SOURCE'::text, 'CHANNEL_MANAGER'::text, 'PAYMENT_PROVIDER'::text, 'BANK'::text, 'ACCOUNTING'::text, 'MESSAGING'::text, 'IDENTITY'::text, 'FILE_OCR'::text, 'ANALYTICS_EXPORT'::text, 'OTHER'::text]))),
    CONSTRAINT integration_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'DEGRADED'::text, 'DISABLED'::text, 'ERROR'::text]))),
    CONSTRAINT integration_sync_mode_check CHECK ((sync_mode = ANY (ARRAY['WEBHOOK_PRIMARY'::text, 'POLLING'::text, 'MANUAL_IMPORT'::text, 'BATCH_FILE'::text, 'HYBRID'::text])))
);


--
-- Name: integration_processing_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_processing_record (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    integration_id uuid NOT NULL,
    external_event_id text NOT NULL,
    action_key text DEFAULT 'default'::text NOT NULL,
    status text NOT NULL,
    result_reference text,
    attempts integer DEFAULT 0 NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_attempt_at timestamp with time zone,
    last_error text,
    CONSTRAINT integration_processing_record_status_check CHECK ((status = ANY (ARRAY['RECEIVED'::text, 'PROCESSING'::text, 'SUCCEEDED'::text, 'FAILED_RETRYABLE'::text, 'FAILED_FINAL'::text, 'DUPLICATE'::text])))
);


--
-- Name: inventory_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_item (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    category text,
    unit_of_measure text NOT NULL,
    track_mode text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT inventory_item_track_mode_check CHECK ((track_mode = ANY (ARRAY['COUNTED'::text, 'ESTIMATED'::text, 'NON_TRACKED'::text])))
);


--
-- Name: inventory_location; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_location (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    zone_id uuid,
    code text NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: investment_project; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.investment_project (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    name text NOT NULL,
    status text NOT NULL,
    budget numeric(14,2),
    planned_start date,
    actual_start date,
    planned_end date,
    actual_end date,
    CONSTRAINT investment_project_status_check CHECK ((status = ANY (ARRAY['PLANNED'::text, 'APPROVED'::text, 'IN_PROGRESS'::text, 'COMPLETED'::text, 'CANCELLED'::text])))
);


--
-- Name: maintenance_plan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maintenance_plan (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    asset_id uuid,
    resource_id uuid,
    task_template_id uuid NOT NULL,
    maintenance_type text NOT NULL,
    schedule_type text NOT NULL,
    schedule_config jsonb NOT NULL,
    next_due_at timestamp with time zone,
    criticality text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT maintenance_plan_check CHECK ((num_nonnulls(asset_id, resource_id) = 1)),
    CONSTRAINT maintenance_plan_criticality_check CHECK ((criticality = ANY (ARRAY['LOW'::text, 'MEDIUM'::text, 'HIGH'::text, 'CRITICAL'::text]))),
    CONSTRAINT maintenance_plan_maintenance_type_check CHECK ((maintenance_type = ANY (ARRAY['PREVENTIVE'::text, 'INSPECTION'::text, 'SAFETY'::text, 'WARRANTY'::text, 'UPGRADE'::text]))),
    CONSTRAINT maintenance_plan_schedule_type_check CHECK ((schedule_type = ANY (ARRAY['CALENDAR'::text, 'USAGE'::text, 'MANUAL'::text])))
);


--
-- Name: message; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    conversation_id uuid NOT NULL,
    template_id uuid,
    channel text NOT NULL,
    direction text NOT NULL,
    sender_party_id uuid,
    recipient_party_id uuid,
    subject text,
    body text NOT NULL,
    delivery_status text DEFAULT 'QUEUED'::text NOT NULL,
    provider_message_id text,
    deduplication_key text,
    sent_at timestamp with time zone,
    received_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT message_channel_check CHECK ((channel = ANY (ARRAY['EMAIL'::text, 'SMS'::text, 'WHATSAPP'::text, 'PORTAL'::text, 'INTERNAL'::text, 'OTHER'::text]))),
    CONSTRAINT message_delivery_status_check CHECK ((delivery_status = ANY (ARRAY['QUEUED'::text, 'SENT'::text, 'DELIVERED'::text, 'FAILED'::text, 'BOUNCED'::text, 'READ'::text, 'RECEIVED'::text]))),
    CONSTRAINT message_direction_check CHECK ((direction = ANY (ARRAY['INBOUND'::text, 'OUTBOUND'::text])))
);


--
-- Name: message_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_template (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    code text NOT NULL,
    version_no integer NOT NULL,
    channel text NOT NULL,
    language text DEFAULT 'pl'::text NOT NULL,
    subject_template text,
    body_template text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: money_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.money_account (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    name text NOT NULL,
    account_type text NOT NULL,
    currency character(3) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT money_account_account_type_check CHECK ((account_type = ANY (ARRAY['BANK'::text, 'CASH'::text, 'PAYMENT_PROVIDER_CLEARING'::text, 'OTA_CLEARING'::text, 'OWNER_FUNDS'::text, 'OPERATOR_FUNDS'::text, 'INTERNAL_CLEARING'::text, 'OTHER'::text])))
);


--
-- Name: notification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    target_user_id uuid,
    target_role_id uuid,
    severity text NOT NULL,
    category text NOT NULL,
    title text NOT NULL,
    body text,
    subject_type text,
    subject_id uuid,
    action_url text,
    deduplication_key text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    acknowledged_at timestamp with time zone,
    expires_at timestamp with time zone,
    CONSTRAINT notification_check CHECK ((num_nonnulls(target_user_id, target_role_id) >= 1)),
    CONSTRAINT notification_severity_check CHECK ((severity = ANY (ARRAY['INFO'::text, 'ACTION_REQUIRED'::text, 'WARNING'::text, 'CRITICAL'::text])))
);


--
-- Name: organization; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organization (
    id uuid NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    default_currency character(3) DEFAULT 'PLN'::bpchar NOT NULL,
    default_timezone text DEFAULT 'Europe/Warsaw'::text NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT organization_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'SUSPENDED'::text, 'ARCHIVED'::text])))
);


--
-- Name: osg_allocation_fact; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_allocation_fact AS
 SELECT a.organization_id,
    a.id AS allocation_id,
    a.economic_event_id,
    ee.property_id AS event_property_id,
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
    ee.event_type,
    ee.effect_direction,
    ee.reverses_event_id,
    ee.economic_date,
    ee.currency,
    ee.status AS economic_event_status,
    a.amount,
    a.allocation_type,
    a.classification,
    a.confidence,
    a.allocation_method,
    a.rationale,
        CASE
            WHEN (ee.effect_direction = 'REVERSAL'::text) THEN '-1'::integer
            ELSE 1
        END AS direction_multiplier,
    (a.amount * (
        CASE
            WHEN (ee.effect_direction = 'REVERSAL'::text) THEN '-1'::integer
            ELSE 1
        END)::numeric) AS signed_category_amount,
        CASE
            WHEN (a.classification = 'REVENUE'::text) THEN (a.amount * (
            CASE
                WHEN (ee.effect_direction = 'REVERSAL'::text) THEN '-1'::integer
                ELSE 1
            END)::numeric)
            WHEN (a.classification = 'OPEX'::text) THEN ((- a.amount) * (
            CASE
                WHEN (ee.effect_direction = 'REVERSAL'::text) THEN '-1'::integer
                ELSE 1
            END)::numeric)
            ELSE (0)::numeric
        END AS operating_result_effect,
        CASE
            WHEN (a.classification = 'CAPEX'::text) THEN (a.amount * (
            CASE
                WHEN (ee.effect_direction = 'REVERSAL'::text) THEN '-1'::integer
                ELSE 1
            END)::numeric)
            ELSE (0)::numeric
        END AS capex_amount,
        CASE
            WHEN (a.classification = 'NON_BUSINESS'::text) THEN (a.amount * (
            CASE
                WHEN (ee.effect_direction = 'REVERSAL'::text) THEN '-1'::integer
                ELSE 1
            END)::numeric)
            ELSE (0)::numeric
        END AS non_business_amount,
    (
        CASE a.confidence
            WHEN 'VERIFIED'::text THEN 1.00
            WHEN 'SYSTEM_DERIVED'::text THEN 0.95
            WHEN 'ESTIMATED'::text THEN 0.60
            WHEN 'MANUAL'::text THEN 0.50
            WHEN 'UNKNOWN'::text THEN 0.00
            ELSE 0.00
        END)::numeric(5,2) AS confidence_weight
   FROM (public.allocation a
     JOIN public.economic_event ee ON (((ee.organization_id = a.organization_id) AND (ee.id = a.economic_event_id))))
  WHERE (ee.status = 'POSTED'::text);


--
-- Name: osg_cash_leg; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_cash_leg AS
 SELECT cm.organization_id,
    cm.id AS cash_movement_id,
    cm.occurred_at,
    cm.currency,
    cm.status,
    cm.external_reference,
    cm.from_money_account_id AS money_account_id,
    (- cm.amount) AS signed_amount,
    'OUT'::text AS direction
   FROM public.cash_movement cm
  WHERE ((cm.from_money_account_id IS NOT NULL) AND (cm.status <> 'IGNORED'::text))
UNION ALL
 SELECT cm.organization_id,
    cm.id AS cash_movement_id,
    cm.occurred_at,
    cm.currency,
    cm.status,
    cm.external_reference,
    cm.to_money_account_id AS money_account_id,
    cm.amount AS signed_amount,
    'IN'::text AS direction
   FROM public.cash_movement cm
  WHERE ((cm.to_money_account_id IS NOT NULL) AND (cm.status <> 'IGNORED'::text));


--
-- Name: osg_guest_profile_canonical_map; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_guest_profile_canonical_map AS
 SELECT organization_id,
    id AS source_guest_profile_id,
    public.osg_canonical_guest_profile(organization_id, id) AS canonical_guest_profile_id
   FROM public.guest_profile gp;


--
-- Name: reservation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    channel_id uuid,
    primary_guest_id uuid,
    reference_code text NOT NULL,
    commercial_status text NOT NULL,
    booked_at timestamp with time zone NOT NULL,
    currency character(3) NOT NULL,
    source_created_at timestamp with time zone,
    source_updated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT reservation_commercial_status_check CHECK ((commercial_status = ANY (ARRAY['INQUIRY'::text, 'HELD'::text, 'CONFIRMED'::text, 'CANCELLED'::text, 'NO_SHOW'::text])))
);


--
-- Name: reservation_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation_item (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    reservation_id uuid NOT NULL,
    unit_type_id uuid NOT NULL,
    assigned_unit_id uuid,
    arrival_date date NOT NULL,
    departure_date date NOT NULL,
    adults integer DEFAULT 1 NOT NULL,
    children integer DEFAULT 0 NOT NULL,
    infants integer DEFAULT 0 NOT NULL,
    pets integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'ACTIVE'::text NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT reservation_item_adults_check CHECK ((adults >= 0)),
    CONSTRAINT reservation_item_check CHECK ((departure_date > arrival_date)),
    CONSTRAINT reservation_item_children_check CHECK ((children >= 0)),
    CONSTRAINT reservation_item_infants_check CHECK ((infants >= 0)),
    CONSTRAINT reservation_item_pets_check CHECK ((pets >= 0)),
    CONSTRAINT reservation_item_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'CANCELLED'::text])))
);


--
-- Name: stay; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stay (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    reservation_item_id uuid NOT NULL,
    primary_guest_id uuid,
    status text NOT NULL,
    actual_checkin_at timestamp with time zone,
    actual_checkout_at timestamp with time zone,
    guest_count_actual integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT stay_guest_count_actual_check CHECK (((guest_count_actual IS NULL) OR (guest_count_actual >= 0))),
    CONSTRAINT stay_status_check CHECK ((status = ANY (ARRAY['EXPECTED'::text, 'CHECKED_IN'::text, 'CHECKED_OUT'::text, 'CANCELLED'::text])))
);


--
-- Name: osg_completed_stay_guest_fact; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_completed_stay_guest_fact AS
 SELECT s.organization_id,
    r.property_id,
    s.id AS stay_id,
    s.actual_checkout_at,
    gpmap.canonical_guest_profile_id
   FROM (((public.stay s
     JOIN public.reservation_item ri ON (((ri.organization_id = s.organization_id) AND (ri.id = s.reservation_item_id))))
     JOIN public.reservation r ON (((r.organization_id = ri.organization_id) AND (r.id = ri.reservation_id))))
     JOIN public.osg_guest_profile_canonical_map gpmap ON (((gpmap.organization_id = s.organization_id) AND (gpmap.source_guest_profile_id = s.primary_guest_id))))
  WHERE ((s.status = 'CHECKED_OUT'::text) AND (s.actual_checkout_at IS NOT NULL) AND (s.primary_guest_id IS NOT NULL));


--
-- Name: osg_dq_capex_without_investment_project; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_capex_without_investment_project AS
 SELECT organization_id,
    property_id,
    allocation_id,
    economic_event_id,
    amount,
    economic_date,
    confidence,
    'HIGH'::text AS severity
   FROM public.osg_allocation_fact af
  WHERE ((classification = 'CAPEX'::text) AND (investment_project_id IS NULL));


--
-- Name: property; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.property (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    property_type text DEFAULT 'GLAMPING'::text NOT NULL,
    timezone text DEFAULT 'Europe/Warsaw'::text NOT NULL,
    currency character(3) DEFAULT 'PLN'::bpchar NOT NULL,
    status text NOT NULL,
    opened_at date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT property_status_check CHECK ((status = ANY (ARRAY['DEVELOPMENT'::text, 'ACTIVE'::text, 'SEASONAL'::text, 'CLOSED'::text, 'ARCHIVED'::text])))
);


--
-- Name: osg_dq_commercial_night_non_sellable_conflict; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_commercial_night_non_sellable_conflict AS
 SELECT cn.organization_id,
    cn.property_id,
    cn.stay_id,
    cn.night_date,
    cn.unit_id,
    unf.sellable_capacity,
    'HIGH'::text AS severity,
    'COMMERCIAL_NIGHT_ON_NON_SELLABLE_UNIT'::text AS issue_type
   FROM ((public.property p
     CROSS JOIN LATERAL public.osg_commercial_accommodation_nights(p.id, (GREATEST((CURRENT_DATE - '90 days'::interval), ('2000-01-01'::date)::timestamp without time zone))::date, CURRENT_DATE) cn(organization_id, property_id, stay_id, reservation_item_id, night_date, unit_id, anchor_at, finality, attribution_status))
     JOIN LATERAL public.osg_unit_night_facts(p.id, cn.night_date, cn.night_date) unf(organization_id, property_id, unit_id, local_night_date, operational_start_at, operational_end_at, physical_capacity, sellable_capacity, physically_occupied) ON (((unf.unit_id = cn.unit_id) AND (unf.local_night_date = cn.night_date))))
  WHERE ((cn.property_id = p.id) AND (cn.attribution_status = 'RESOLVED'::text) AND (unf.sellable_capacity = false));


--
-- Name: osg_dq_low_confidence_allocation; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_low_confidence_allocation AS
 SELECT organization_id,
    property_id,
    allocation_id,
    economic_event_id,
    amount,
    classification,
    confidence,
    rationale,
        CASE
            WHEN (confidence = 'UNKNOWN'::text) THEN 'HIGH'::text
            ELSE 'MEDIUM'::text
        END AS severity
   FROM public.osg_allocation_fact af
  WHERE (confidence = ANY (ARRAY['UNKNOWN'::text, 'ESTIMATED'::text, 'MANUAL'::text]));


--
-- Name: stay_segment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stay_segment (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    stay_id uuid NOT NULL,
    unit_id uuid NOT NULL,
    start_at timestamp with time zone NOT NULL,
    end_at timestamp with time zone NOT NULL,
    status text DEFAULT 'ACTIVE'::text NOT NULL,
    reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT stay_segment_check CHECK ((end_at > start_at)),
    CONSTRAINT stay_segment_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'CANCELLED'::text])))
);


--
-- Name: unit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unit (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    unit_type_id uuid NOT NULL,
    zone_id uuid,
    code text NOT NULL,
    name text NOT NULL,
    lifecycle_status text NOT NULL,
    commissioned_at date,
    retired_at date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT unit_lifecycle_status_check CHECK ((lifecycle_status = ANY (ARRAY['PLANNED'::text, 'ACTIVE'::text, 'OUT_OF_SERVICE'::text, 'RETIRED'::text])))
);


--
-- Name: osg_dq_occupied_non_sellable_overlap; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_occupied_non_sellable_overlap AS
 SELECT DISTINCT ss.organization_id,
    u.property_id,
    ss.stay_id,
    ss.id AS stay_segment_id,
    ss.unit_id,
    ab.id AS availability_block_id,
    ab.reason_type,
    ab.guest_impact,
    'HIGH'::text AS severity
   FROM ((public.stay_segment ss
     JOIN public.unit u ON (((u.organization_id = ss.organization_id) AND (u.id = ss.unit_id))))
     JOIN public.availability_block ab ON (((ab.organization_id = ss.organization_id) AND (ab.unit_id = ss.unit_id) AND (ab.status = 'ACTIVE'::text) AND (ab.sellability_impact = true) AND (tstzrange(ab.start_at, ab.end_at, '[)'::text) && tstzrange(ss.start_at, ss.end_at, '[)'::text)))))
  WHERE (ss.status = 'ACTIVE'::text);


--
-- Name: payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    folio_id uuid NOT NULL,
    payer_party_id uuid,
    method text NOT NULL,
    provider text,
    amount numeric(14,2) NOT NULL,
    currency character(3) NOT NULL,
    status text NOT NULL,
    paid_at timestamp with time zone,
    external_reference text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT payment_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'CONFIRMED'::text, 'FAILED'::text, 'REFUNDED'::text, 'PARTIALLY_REFUNDED'::text])))
);


--
-- Name: payment_allocation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_allocation (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    payment_id uuid NOT NULL,
    charge_id uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_allocation_amount_check CHECK ((amount > (0)::numeric))
);


--
-- Name: osg_dq_payment_overallocated; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_payment_overallocated AS
 SELECT p.organization_id,
    p.id AS payment_id,
    p.amount AS payment_amount,
    COALESCE(sum(pa.amount), (0)::numeric) AS allocated_amount,
    (COALESCE(sum(pa.amount), (0)::numeric) - p.amount) AS overallocated_by,
    'CRITICAL'::text AS severity
   FROM (public.payment p
     LEFT JOIN public.payment_allocation pa ON (((pa.organization_id = p.organization_id) AND (pa.payment_id = p.id))))
  GROUP BY p.organization_id, p.id, p.amount
 HAVING (COALESCE(sum(pa.amount), (0)::numeric) > p.amount);


--
-- Name: settlement_application; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settlement_application (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    settlement_entry_id uuid NOT NULL,
    cash_movement_id uuid,
    amount numeric(14,2) NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT settlement_application_amount_check CHECK ((amount > (0)::numeric))
);


--
-- Name: settlement_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settlement_entry (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    source_economic_event_id uuid,
    source_allocation_id uuid,
    creditor_party_id uuid NOT NULL,
    debtor_party_id uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    currency character(3) NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT settlement_entry_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT settlement_entry_check CHECK ((creditor_party_id <> debtor_party_id)),
    CONSTRAINT settlement_entry_check1 CHECK ((num_nonnulls(source_economic_event_id, source_allocation_id) >= 1)),
    CONSTRAINT settlement_entry_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'PARTIALLY_SETTLED'::text, 'SETTLED'::text, 'REVERSED'::text])))
);


--
-- Name: osg_dq_settlement_overapplied; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_settlement_overapplied AS
 SELECT se.organization_id,
    se.id AS settlement_entry_id,
    se.amount AS settlement_amount,
    COALESCE(sum(sa.amount), (0)::numeric) AS applied_amount,
    (COALESCE(sum(sa.amount), (0)::numeric) - se.amount) AS overapplied_by,
    'CRITICAL'::text AS severity
   FROM (public.settlement_entry se
     LEFT JOIN public.settlement_application sa ON (((sa.organization_id = se.organization_id) AND (sa.settlement_entry_id = se.id))))
  WHERE (se.status <> 'REVERSED'::text)
  GROUP BY se.organization_id, se.id, se.amount
 HAVING (COALESCE(sum(sa.amount), (0)::numeric) > se.amount);


--
-- Name: reconciliation_link; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reconciliation_link (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    financial_document_id uuid,
    financial_document_line_id uuid,
    cash_movement_id uuid,
    payment_id uuid,
    refund_id uuid,
    economic_event_id uuid,
    settlement_application_id uuid,
    match_status text NOT NULL,
    matched_amount numeric(14,2),
    confidence text DEFAULT 'MANUAL'::text NOT NULL,
    rationale text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reconciliation_link_check CHECK ((num_nonnulls(financial_document_id, financial_document_line_id, cash_movement_id, payment_id, refund_id, economic_event_id, settlement_application_id) >= 2)),
    CONSTRAINT reconciliation_link_confidence_check CHECK ((confidence = ANY (ARRAY['VERIFIED'::text, 'SYSTEM_DERIVED'::text, 'ESTIMATED'::text, 'MANUAL'::text, 'UNKNOWN'::text]))),
    CONSTRAINT reconciliation_link_match_status_check CHECK ((match_status = ANY (ARRAY['UNMATCHED'::text, 'PARTIAL'::text, 'MATCHED'::text, 'CONFLICT'::text, 'IGNORED'::text])))
);


--
-- Name: osg_dq_stale_unreconciled_cash; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_stale_unreconciled_cash AS
 SELECT organization_id,
    id AS cash_movement_id,
    occurred_at,
    amount,
    currency,
    external_reference,
    'MEDIUM'::text AS severity
   FROM public.cash_movement cm
  WHERE ((status = 'VERIFIED'::text) AND (occurred_at < (now() - '7 days'::interval)) AND (NOT (EXISTS ( SELECT 1
           FROM public.reconciliation_link rl
          WHERE ((rl.organization_id = cm.organization_id) AND (rl.cash_movement_id = cm.id) AND (rl.match_status = ANY (ARRAY['MATCHED'::text, 'PARTIAL'::text])))))));


--
-- Name: osg_dq_unassigned_near_arrival; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_unassigned_near_arrival AS
 SELECT r.organization_id,
    r.property_id,
    r.id AS reservation_id,
    ri.id AS reservation_item_id,
    ri.arrival_date,
    ri.unit_type_id,
    'HIGH'::text AS severity
   FROM (public.reservation r
     JOIN public.reservation_item ri ON (((ri.organization_id = r.organization_id) AND (ri.reservation_id = r.id))))
  WHERE ((r.commercial_status = 'CONFIRMED'::text) AND (ri.status = 'ACTIVE'::text) AND (ri.assigned_unit_id IS NULL) AND (ri.arrival_date <= (((now() AT TIME ZONE 'UTC'::text))::date + 1)));


--
-- Name: osg_dq_unbalanced_posted_economic_event; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_unbalanced_posted_economic_event AS
 SELECT ee.organization_id,
    ee.property_id,
    ee.id AS economic_event_id,
    ee.amount AS event_amount,
    COALESCE(sum(a.amount), (0)::numeric) AS allocation_sum,
    (ee.amount - COALESCE(sum(a.amount), (0)::numeric)) AS difference,
    'CRITICAL'::text AS severity
   FROM (public.economic_event ee
     LEFT JOIN public.allocation a ON (((a.organization_id = ee.organization_id) AND (a.economic_event_id = ee.id))))
  WHERE (ee.status = 'POSTED'::text)
  GROUP BY ee.organization_id, ee.property_id, ee.id, ee.amount
 HAVING (ee.amount <> COALESCE(sum(a.amount), (0)::numeric));


--
-- Name: osg_dq_unresolved_commercial_night_attribution; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_dq_unresolved_commercial_night_attribution AS
 SELECT cn.organization_id,
    cn.property_id,
    cn.stay_id,
    cn.reservation_item_id,
    cn.night_date,
    cn.anchor_at,
    cn.finality,
    'HIGH'::text AS severity,
    'COMMERCIAL_NIGHT_UNIT_UNRESOLVED'::text AS issue_type
   FROM (public.property p
     CROSS JOIN LATERAL public.osg_commercial_accommodation_nights(p.id, (GREATEST((CURRENT_DATE - '90 days'::interval), ('2000-01-01'::date)::timestamp without time zone))::date, CURRENT_DATE) cn(organization_id, property_id, stay_id, reservation_item_id, night_date, unit_id, anchor_at, finality, attribution_status))
  WHERE ((cn.property_id = p.id) AND (cn.attribution_status = 'UNRESOLVED'::text));


--
-- Name: refund; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refund (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    payment_id uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    currency character(3) NOT NULL,
    status text NOT NULL,
    refunded_at timestamp with time zone,
    external_reference text,
    reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT refund_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT refund_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'CONFIRMED'::text, 'FAILED'::text])))
);


--
-- Name: osg_folio_balance; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_folio_balance AS
 WITH charge_totals AS (
         SELECT f_1.organization_id,
            f_1.id AS folio_id,
            f_1.currency,
            COALESCE(sum(c.gross_amount) FILTER (WHERE (c.status = ANY (ARRAY['POSTED'::text, 'RECOGNIZED'::text]))), (0)::numeric) AS net_charges,
            count(c.id) FILTER (WHERE (c.status = 'PENDING'::text)) AS pending_charge_count
           FROM (public.folio f_1
             LEFT JOIN public.charge c ON (((c.organization_id = f_1.organization_id) AND (c.folio_id = f_1.id))))
          GROUP BY f_1.organization_id, f_1.id, f_1.currency
        ), payment_totals AS (
         SELECT f_1.organization_id,
            f_1.id AS folio_id,
            COALESCE(sum(p.amount) FILTER (WHERE (p.status = ANY (ARRAY['CONFIRMED'::text, 'PARTIALLY_REFUNDED'::text, 'REFUNDED'::text]))), (0)::numeric) AS gross_payments,
            COALESCE(sum(r.amount) FILTER (WHERE (r.status = 'CONFIRMED'::text)), (0)::numeric) AS confirmed_refunds,
            count(p.id) FILTER (WHERE (p.status = 'PENDING'::text)) AS pending_payment_count,
            count(r.id) FILTER (WHERE (r.status = 'PENDING'::text)) AS pending_refund_count
           FROM ((public.folio f_1
             LEFT JOIN public.payment p ON (((p.organization_id = f_1.organization_id) AND (p.folio_id = f_1.id))))
             LEFT JOIN public.refund r ON (((r.organization_id = p.organization_id) AND (r.payment_id = p.id))))
          GROUP BY f_1.organization_id, f_1.id
        )
 SELECT f.organization_id,
    f.id AS folio_id,
    f.reservation_id,
    f.stay_id,
    f.currency,
    f.status,
    ct.net_charges,
    pt.gross_payments,
    pt.confirmed_refunds,
    (pt.gross_payments - pt.confirmed_refunds) AS net_collected,
    (ct.net_charges - (pt.gross_payments - pt.confirmed_refunds)) AS balance_due,
    ct.pending_charge_count,
    pt.pending_payment_count,
    pt.pending_refund_count,
    ((ct.pending_charge_count + pt.pending_payment_count) + pt.pending_refund_count) AS pending_commercial_items
   FROM ((public.folio f
     JOIN charge_totals ct ON (((ct.organization_id = f.organization_id) AND (ct.folio_id = f.id))))
     JOIN payment_totals pt ON (((pt.organization_id = f.organization_id) AND (pt.folio_id = f.id))));


--
-- Name: osg_money_account_balance; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_money_account_balance AS
 SELECT ma.organization_id,
    ma.property_id,
    ma.id AS money_account_id,
    ma.name,
    ma.account_type,
    ma.currency,
    COALESCE(sum(cl.signed_amount) FILTER (WHERE (cl.status = ANY (ARRAY['IMPORTED'::text, 'VERIFIED'::text]))), (0)::numeric) AS calculated_balance_delta
   FROM (public.money_account ma
     LEFT JOIN public.osg_cash_leg cl ON (((cl.organization_id = ma.organization_id) AND (cl.money_account_id = ma.id) AND (cl.currency = ma.currency))))
  GROUP BY ma.organization_id, ma.property_id, ma.id, ma.name, ma.account_type, ma.currency;


--
-- Name: osg_open_incident_attention; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_open_incident_attention AS
 SELECT organization_id,
    property_id,
    id AS incident_id,
    unit_id,
    resource_id,
    asset_id,
    severity,
    status,
    title,
    guest_impact,
    safety_related,
    reported_at,
    (EXTRACT(epoch FROM (now() - reported_at)) / 3600.0) AS age_hours
   FROM public.incident i
  WHERE (status <> ALL (ARRAY['RESOLVED'::text, 'CLOSED'::text]));


--
-- Name: property_stay_policy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.property_stay_policy (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    version_no integer NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    default_checkin_time time without time zone NOT NULL,
    default_checkout_time time without time zone NOT NULL,
    readiness_buffer interval DEFAULT '00:30:00'::interval NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    overnight_anchor_time time without time zone DEFAULT '03:00:00'::time without time zone NOT NULL,
    CONSTRAINT property_stay_policy_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT property_stay_policy_version_no_check CHECK ((version_no > 0))
);


--
-- Name: COLUMN property_stay_policy.overnight_anchor_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.property_stay_policy.overnight_anchor_time IS 'Local time on D+1 used to attribute commercial accommodation night D to the Unit/StaySegment that hosted the overnight service.';


--
-- Name: osg_property_stay_policy_current; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_property_stay_policy_current AS
 SELECT DISTINCT ON (p.id) p.organization_id,
    p.id AS property_id,
    p.timezone,
    spp.default_checkin_time,
    spp.default_checkout_time,
    spp.readiness_buffer,
    spp.overnight_anchor_time,
    spp.version_no
   FROM (public.property p
     JOIN public.property_stay_policy spp ON (((spp.organization_id = p.organization_id) AND (spp.property_id = p.id))))
  WHERE ((spp.active = true) AND (spp.valid_from <= CURRENT_DATE) AND ((spp.valid_to IS NULL) OR (spp.valid_to >= CURRENT_DATE)))
  ORDER BY p.id, spp.valid_from DESC, spp.version_no DESC;


--
-- Name: osg_settlement_balance; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_settlement_balance AS
 SELECT se.organization_id,
    se.id AS settlement_entry_id,
    se.creditor_party_id,
    se.debtor_party_id,
    se.currency,
    se.amount AS original_amount,
    COALESCE(sum(sa.amount), (0)::numeric) AS applied_amount,
    (se.amount - COALESCE(sum(sa.amount), (0)::numeric)) AS open_amount,
        CASE
            WHEN (COALESCE(sum(sa.amount), (0)::numeric) = (0)::numeric) THEN 'OPEN'::text
            WHEN (COALESCE(sum(sa.amount), (0)::numeric) < se.amount) THEN 'PARTIALLY_SETTLED'::text
            WHEN (COALESCE(sum(sa.amount), (0)::numeric) = se.amount) THEN 'SETTLED'::text
            ELSE 'OVERAPPLIED_ERROR'::text
        END AS derived_status
   FROM (public.settlement_entry se
     LEFT JOIN public.settlement_application sa ON (((sa.organization_id = se.organization_id) AND (sa.settlement_entry_id = se.id))))
  WHERE (se.status <> 'REVERSED'::text)
  GROUP BY se.organization_id, se.id, se.creditor_party_id, se.debtor_party_id, se.currency, se.amount;


--
-- Name: turnover; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.turnover (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    unit_id uuid NOT NULL,
    previous_stay_id uuid,
    next_stay_id uuid,
    available_from timestamp with time zone,
    ready_deadline timestamp with time zone,
    status text NOT NULL,
    priority text DEFAULT 'NORMAL'::text NOT NULL,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT turnover_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'IN_PROGRESS'::text, 'READY'::text, 'BLOCKED'::text, 'CANCELLED'::text])))
);


--
-- Name: osg_turnover_attention; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.osg_turnover_attention AS
 SELECT t.organization_id,
    t.property_id,
    t.id AS turnover_id,
    t.unit_id,
    u.name AS unit_name,
    t.status,
    t.priority,
    t.ready_deadline,
    t.next_stay_id,
        CASE
            WHEN (t.status = 'BLOCKED'::text) THEN 'BLOCKED'::text
            WHEN ((t.status <> 'READY'::text) AND (t.ready_deadline < now())) THEN 'OVERDUE'::text
            WHEN ((t.status <> 'READY'::text) AND (t.ready_deadline <= (now() + '01:00:00'::interval))) THEN 'AT_RISK'::text
            ELSE 'ON_TRACK'::text
        END AS attention_status
   FROM (public.turnover t
     JOIN public.unit u ON (((u.organization_id = t.organization_id) AND (u.id = t.unit_id))))
  WHERE (t.status <> ALL (ARRAY['READY'::text, 'CANCELLED'::text]));


--
-- Name: outbox_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.outbox_event (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    domain_event_id uuid NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    available_at timestamp with time zone DEFAULT now() NOT NULL,
    published_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL,
    last_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT outbox_event_attempts_check CHECK ((attempts >= 0)),
    CONSTRAINT outbox_event_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'PUBLISHING'::text, 'PUBLISHED'::text, 'FAILED_RETRYABLE'::text, 'FAILED_FINAL'::text])))
);


--
-- Name: package; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.package (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    version_no integer DEFAULT 1 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    valid_from date,
    valid_to date,
    CONSTRAINT package_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: package_component; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.package_component (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    package_id uuid NOT NULL,
    component_type text NOT NULL,
    unit_type_id uuid,
    service_id uuid,
    quantity numeric(12,3) DEFAULT 1 NOT NULL,
    pricing_allocation jsonb,
    CONSTRAINT package_component_check CHECK ((((component_type = 'ACCOMMODATION'::text) AND (unit_type_id IS NOT NULL) AND (service_id IS NULL)) OR ((component_type = 'SERVICE'::text) AND (service_id IS NOT NULL) AND (unit_type_id IS NULL)) OR ((component_type = ANY (ARRAY['FEE'::text, 'DISCOUNT'::text])) AND (unit_type_id IS NULL) AND (service_id IS NULL)))),
    CONSTRAINT package_component_component_type_check CHECK ((component_type = ANY (ARRAY['ACCOMMODATION'::text, 'SERVICE'::text, 'FEE'::text, 'DISCOUNT'::text]))),
    CONSTRAINT package_component_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: party; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.party (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    party_type text NOT NULL,
    display_name text NOT NULL,
    legal_name text,
    tax_id text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT party_party_type_check CHECK ((party_type = ANY (ARRAY['PERSON'::text, 'COMPANY'::text, 'PLATFORM'::text, 'PUBLIC_BODY'::text, 'OTHER'::text])))
);


--
-- Name: permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permission (
    code text NOT NULL,
    description text NOT NULL
);


--
-- Name: pricing_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pricing_rule (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    code text NOT NULL,
    version_no integer NOT NULL,
    conditions jsonb NOT NULL,
    adjustment jsonb NOT NULL,
    guardrails jsonb DEFAULT '{}'::jsonb NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pricing_suggestion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pricing_suggestion (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    unit_type_id uuid NOT NULL,
    stay_date date NOT NULL,
    suggested_amount numeric(14,2) NOT NULL,
    currency character(3) NOT NULL,
    source_type text NOT NULL,
    source_reference text,
    confidence numeric(5,4),
    rationale text,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pricing_suggestion_source_type_check CHECK ((source_type = ANY (ARRAY['RULE'::text, 'MODEL'::text, 'AI'::text, 'MANUAL'::text]))),
    CONSTRAINT pricing_suggestion_status_check CHECK ((status = ANY (ARRAY['GENERATED'::text, 'REVIEWED'::text, 'ACCEPTED'::text, 'REJECTED'::text, 'EXPIRED'::text, 'PUBLISHED'::text]))),
    CONSTRAINT pricing_suggestion_suggested_amount_check CHECK ((suggested_amount >= (0)::numeric))
);


--
-- Name: rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rate (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    unit_type_id uuid NOT NULL,
    rate_plan_id uuid NOT NULL,
    channel_id uuid,
    stay_date date NOT NULL,
    amount numeric(14,2) NOT NULL,
    currency character(3) NOT NULL,
    source text NOT NULL,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rate_amount_check CHECK ((amount >= (0)::numeric))
);


--
-- Name: rate_plan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rate_plan (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    cancellation_policy_code text,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: rate_snapshot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rate_snapshot (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    reservation_item_id uuid NOT NULL,
    rate_plan_id uuid,
    channel_id uuid,
    stay_date date NOT NULL,
    amount numeric(14,2) NOT NULL,
    currency character(3) NOT NULL,
    captured_at timestamp with time zone NOT NULL,
    source_reference text,
    CONSTRAINT rate_snapshot_amount_check CHECK ((amount >= (0)::numeric))
);


--
-- Name: recommendation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recommendation (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    recommendation_type text NOT NULL,
    subject_type text,
    subject_id uuid,
    action_class text NOT NULL,
    status text NOT NULL,
    confidence numeric(5,4),
    data_quality_context jsonb,
    rationale_summary text,
    proposed_action jsonb,
    source_version text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    reviewed_at timestamp with time zone,
    CONSTRAINT recommendation_action_class_check CHECK ((action_class = ANY (ARRAY['A0'::text, 'A1'::text, 'A2'::text, 'A3'::text, 'A4'::text]))),
    CONSTRAINT recommendation_status_check CHECK ((status = ANY (ARRAY['GENERATED'::text, 'REVIEWED'::text, 'ACCEPTED'::text, 'REJECTED'::text, 'EXECUTED'::text, 'EXPIRED'::text])))
);


--
-- Name: reorder_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reorder_rule (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    inventory_item_id uuid NOT NULL,
    inventory_location_id uuid NOT NULL,
    min_quantity numeric(14,3) NOT NULL,
    target_quantity numeric(14,3),
    lead_time interval,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: resource; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    zone_id uuid,
    code text NOT NULL,
    name text NOT NULL,
    resource_type text NOT NULL,
    capacity integer NOT NULL,
    booking_mode text NOT NULL,
    buffer_before interval DEFAULT '00:00:00'::interval NOT NULL,
    buffer_after interval DEFAULT '00:00:00'::interval NOT NULL,
    active boolean DEFAULT true NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT resource_booking_mode_check CHECK ((booking_mode = ANY (ARRAY['NONE'::text, 'SLOT'::text, 'DURATION'::text, 'EXCLUSIVE'::text, 'CAPACITY'::text]))),
    CONSTRAINT resource_capacity_check CHECK ((capacity > 0))
);


--
-- Name: resource_reservation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_reservation (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    service_booking_id uuid,
    start_at timestamp with time zone NOT NULL,
    end_at timestamp with time zone NOT NULL,
    effective_start_at timestamp with time zone NOT NULL,
    effective_end_at timestamp with time zone NOT NULL,
    capacity_used integer DEFAULT 1 NOT NULL,
    exclusive_booking boolean DEFAULT false NOT NULL,
    status text NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT resource_reservation_capacity_used_check CHECK ((capacity_used > 0)),
    CONSTRAINT resource_reservation_check CHECK ((end_at > start_at)),
    CONSTRAINT resource_reservation_check1 CHECK ((effective_end_at > effective_start_at)),
    CONSTRAINT resource_reservation_status_check CHECK ((status = ANY (ARRAY['HELD'::text, 'CONFIRMED'::text, 'IN_PROGRESS'::text, 'COMPLETED'::text, 'CANCELLED'::text, 'EXPIRED'::text])))
);


--
-- Name: role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: role_assignment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_assignment (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    user_account_id uuid NOT NULL,
    role_id uuid NOT NULL,
    property_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    archived_at timestamp with time zone
);


--
-- Name: role_permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permission (
    organization_id uuid NOT NULL,
    role_id uuid NOT NULL,
    permission_code text NOT NULL
);


--
-- Name: service; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    service_type text NOT NULL,
    pricing_mode text NOT NULL,
    base_price numeric(14,2),
    requires_booking boolean DEFAULT false NOT NULL,
    requires_resource boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL
);


--
-- Name: service_booking; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_booking (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    service_id uuid NOT NULL,
    stay_id uuid,
    reservation_id uuid,
    guest_profile_id uuid,
    requested_start_at timestamp with time zone,
    requested_end_at timestamp with time zone,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT service_booking_check CHECK ((num_nonnulls(stay_id, reservation_id, guest_profile_id) >= 1)),
    CONSTRAINT service_booking_status_check CHECK ((status = ANY (ARRAY['REQUESTED'::text, 'CONFIRMED'::text, 'IN_PROGRESS'::text, 'COMPLETED'::text, 'CANCELLED'::text, 'NO_SHOW'::text])))
);


--
-- Name: service_execution; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_execution (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    service_booking_id uuid NOT NULL,
    actual_start_at timestamp with time zone,
    actual_end_at timestamp with time zone,
    status text NOT NULL,
    notes text,
    CONSTRAINT service_execution_check CHECK (((actual_end_at IS NULL) OR (actual_start_at IS NULL) OR (actual_end_at > actual_start_at))),
    CONSTRAINT service_execution_status_check CHECK ((status = ANY (ARRAY['STARTED'::text, 'COMPLETED'::text, 'CANCELLED'::text, 'NO_SHOW'::text])))
);


--
-- Name: stay_guest; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stay_guest (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    stay_id uuid NOT NULL,
    guest_profile_id uuid,
    role text NOT NULL,
    CONSTRAINT stay_guest_role_check CHECK ((role = ANY (ARRAY['PRIMARY'::text, 'ADULT'::text, 'CHILD'::text, 'OTHER'::text])))
);


--
-- Name: stock_movement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_movement (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    inventory_item_id uuid NOT NULL,
    from_location_id uuid,
    to_location_id uuid,
    movement_type text NOT NULL,
    quantity numeric(14,3) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    confidence text DEFAULT 'VERIFIED'::text NOT NULL,
    reason text,
    turnover_id uuid,
    stay_id uuid,
    reverses_movement_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT stock_movement_check CHECK ((num_nonnulls(from_location_id, to_location_id) >= 1)),
    CONSTRAINT stock_movement_check1 CHECK (((movement_type <> 'ADJUSTMENT'::text) OR (reason IS NOT NULL))),
    CONSTRAINT stock_movement_confidence_check CHECK ((confidence = ANY (ARRAY['VERIFIED'::text, 'SYSTEM_DERIVED'::text, 'ESTIMATED'::text, 'MANUAL'::text, 'UNKNOWN'::text]))),
    CONSTRAINT stock_movement_movement_type_check CHECK ((movement_type = ANY (ARRAY['RECEIPT'::text, 'CONSUMPTION'::text, 'TRANSFER'::text, 'ADJUSTMENT'::text, 'WASTE'::text, 'RETURN'::text, 'REVERSAL'::text]))),
    CONSTRAINT stock_movement_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    turnover_id uuid,
    incident_id uuid,
    assignee_user_id uuid,
    task_type text NOT NULL,
    title text NOT NULL,
    description text,
    priority text DEFAULT 'NORMAL'::text NOT NULL,
    status text NOT NULL,
    due_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT task_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'IN_PROGRESS'::text, 'DONE'::text, 'BLOCKED'::text, 'CANCELLED'::text])))
);


--
-- Name: task_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_template (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid,
    code text NOT NULL,
    version_no integer NOT NULL,
    task_type text NOT NULL,
    title_template text NOT NULL,
    checklist jsonb DEFAULT '[]'::jsonb NOT NULL,
    requires_work_log boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT task_template_version_no_check CHECK ((version_no > 0))
);


--
-- Name: unit_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unit_type (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    base_capacity integer NOT NULL,
    max_capacity integer NOT NULL,
    area_m2 numeric(10,2),
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT unit_type_base_capacity_check CHECK ((base_capacity > 0)),
    CONSTRAINT unit_type_check CHECK ((max_capacity >= base_capacity))
);


--
-- Name: user_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_account (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    party_id uuid,
    email_login text NOT NULL,
    status text NOT NULL,
    mfa_enabled boolean DEFAULT false NOT NULL,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_account_status_check CHECK ((status = ANY (ARRAY['INVITED'::text, 'ACTIVE'::text, 'SUSPENDED'::text, 'ARCHIVED'::text])))
);


--
-- Name: work_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_log (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    task_id uuid NOT NULL,
    performed_by_user_id uuid,
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    minutes integer,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT work_log_check CHECK (((ended_at IS NULL) OR (started_at IS NULL) OR (ended_at >= started_at))),
    CONSTRAINT work_log_minutes_check CHECK (((minutes IS NULL) OR (minutes >= 0)))
);


--
-- Name: work_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_order (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    incident_id uuid,
    asset_id uuid,
    contractor_party_id uuid,
    status text NOT NULL,
    requested_at timestamp with time zone,
    scheduled_at timestamp with time zone,
    completed_at timestamp with time zone,
    estimated_cost numeric(14,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT work_order_status_check CHECK ((status = ANY (ARRAY['DRAFT'::text, 'REQUESTED'::text, 'SCHEDULED'::text, 'IN_PROGRESS'::text, 'COMPLETED'::text, 'CANCELLED'::text])))
);


--
-- Name: zone; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zone (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    property_id uuid NOT NULL,
    parent_zone_id uuid,
    name text NOT NULL,
    zone_type text,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: allocation allocation_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: allocation allocation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_pkey PRIMARY KEY (id);


--
-- Name: allocation_rule allocation_rule_organization_id_code_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rule
    ADD CONSTRAINT allocation_rule_organization_id_code_version_no_key UNIQUE (organization_id, code, version_no);


--
-- Name: allocation_rule allocation_rule_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rule
    ADD CONSTRAINT allocation_rule_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: allocation_rule allocation_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rule
    ADD CONSTRAINT allocation_rule_pkey PRIMARY KEY (id);


--
-- Name: approval_decision approval_decision_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_decision
    ADD CONSTRAINT approval_decision_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: approval_decision approval_decision_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_decision
    ADD CONSTRAINT approval_decision_pkey PRIMARY KEY (id);


--
-- Name: approval_policy approval_policy_organization_id_code_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_policy
    ADD CONSTRAINT approval_policy_organization_id_code_version_no_key UNIQUE (organization_id, code, version_no);


--
-- Name: approval_policy approval_policy_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_policy
    ADD CONSTRAINT approval_policy_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: approval_policy approval_policy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_policy
    ADD CONSTRAINT approval_policy_pkey PRIMARY KEY (id);


--
-- Name: approval_request approval_request_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: approval_request approval_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_pkey PRIMARY KEY (id);


--
-- Name: asset asset_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: asset asset_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_pkey PRIMARY KEY (id);


--
-- Name: attachment_link attachment_link_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_link
    ADD CONSTRAINT attachment_link_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: attachment_link attachment_link_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_link
    ADD CONSTRAINT attachment_link_pkey PRIMARY KEY (id);


--
-- Name: audit_event audit_event_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_event
    ADD CONSTRAINT audit_event_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: audit_event audit_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_event
    ADD CONSTRAINT audit_event_pkey PRIMARY KEY (id);


--
-- Name: automation_execution automation_execution_automation_rule_id_trigger_event_id_ac_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_execution
    ADD CONSTRAINT automation_execution_automation_rule_id_trigger_event_id_ac_key UNIQUE (automation_rule_id, trigger_event_id, action_key);


--
-- Name: automation_execution automation_execution_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_execution
    ADD CONSTRAINT automation_execution_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: automation_execution automation_execution_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_execution
    ADD CONSTRAINT automation_execution_pkey PRIMARY KEY (id);


--
-- Name: automation_rule automation_rule_organization_id_code_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_rule
    ADD CONSTRAINT automation_rule_organization_id_code_version_no_key UNIQUE (organization_id, code, version_no);


--
-- Name: automation_rule automation_rule_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_rule
    ADD CONSTRAINT automation_rule_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: automation_rule automation_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_rule
    ADD CONSTRAINT automation_rule_pkey PRIMARY KEY (id);


--
-- Name: availability_block availability_block_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_block
    ADD CONSTRAINT availability_block_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: availability_block availability_block_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_block
    ADD CONSTRAINT availability_block_pkey PRIMARY KEY (id);


--
-- Name: cash_movement cash_movement_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movement
    ADD CONSTRAINT cash_movement_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: cash_movement cash_movement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movement
    ADD CONSTRAINT cash_movement_pkey PRIMARY KEY (id);


--
-- Name: channel channel_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel
    ADD CONSTRAINT channel_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: channel channel_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel
    ADD CONSTRAINT channel_pkey PRIMARY KEY (id);


--
-- Name: channel channel_property_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel
    ADD CONSTRAINT channel_property_id_code_key UNIQUE (property_id, code);


--
-- Name: charge charge_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge
    ADD CONSTRAINT charge_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: charge charge_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge
    ADD CONSTRAINT charge_pkey PRIMARY KEY (id);


--
-- Name: command_idempotency command_idempotency_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.command_idempotency
    ADD CONSTRAINT command_idempotency_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: command_idempotency command_idempotency_organization_id_principal_key_command_n_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.command_idempotency
    ADD CONSTRAINT command_idempotency_organization_id_principal_key_command_n_key UNIQUE (organization_id, principal_key, command_name, idempotency_key);


--
-- Name: command_idempotency command_idempotency_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.command_idempotency
    ADD CONSTRAINT command_idempotency_pkey PRIMARY KEY (id);


--
-- Name: commercial_policy_snapshot commercial_policy_snapshot_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commercial_policy_snapshot
    ADD CONSTRAINT commercial_policy_snapshot_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: commercial_policy_snapshot commercial_policy_snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commercial_policy_snapshot
    ADD CONSTRAINT commercial_policy_snapshot_pkey PRIMARY KEY (id);


--
-- Name: commercial_policy_snapshot commercial_policy_snapshot_reservation_id_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commercial_policy_snapshot
    ADD CONSTRAINT commercial_policy_snapshot_reservation_id_version_no_key UNIQUE (reservation_id, version_no);


--
-- Name: commission_rule commission_rule_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: commission_rule commission_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_pkey PRIMARY KEY (id);


--
-- Name: communication_consent communication_consent_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communication_consent
    ADD CONSTRAINT communication_consent_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: communication_consent communication_consent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communication_consent
    ADD CONSTRAINT communication_consent_pkey PRIMARY KEY (id);


--
-- Name: conflict_case conflict_case_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conflict_case
    ADD CONSTRAINT conflict_case_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: conflict_case conflict_case_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conflict_case
    ADD CONSTRAINT conflict_case_pkey PRIMARY KEY (id);


--
-- Name: conversation conversation_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: conversation conversation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_pkey PRIMARY KEY (id);


--
-- Name: cost_center cost_center_organization_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_center
    ADD CONSTRAINT cost_center_organization_id_code_key UNIQUE (organization_id, code);


--
-- Name: cost_center cost_center_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_center
    ADD CONSTRAINT cost_center_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: cost_center cost_center_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_center
    ADD CONSTRAINT cost_center_pkey PRIMARY KEY (id);


--
-- Name: data_quality_issue data_quality_issue_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_quality_issue
    ADD CONSTRAINT data_quality_issue_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: data_quality_issue data_quality_issue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_quality_issue
    ADD CONSTRAINT data_quality_issue_pkey PRIMARY KEY (id);


--
-- Name: domain_event domain_event_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_event
    ADD CONSTRAINT domain_event_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: domain_event domain_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_event
    ADD CONSTRAINT domain_event_pkey PRIMARY KEY (id);


--
-- Name: economic_event economic_event_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: economic_event economic_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_pkey PRIMARY KEY (id);


--
-- Name: resource_reservation ex_exclusive_resource_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_reservation
    ADD CONSTRAINT ex_exclusive_resource_no_overlap EXCLUDE USING gist (organization_id WITH =, resource_id WITH =, tstzrange(effective_start_at, effective_end_at, '[)'::text) WITH &&) WHERE (((exclusive_booking = true) AND (status = ANY (ARRAY['HELD'::text, 'CONFIRMED'::text, 'IN_PROGRESS'::text]))));


--
-- Name: financial_period ex_org_financial_period_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_period
    ADD CONSTRAINT ex_org_financial_period_no_overlap EXCLUDE USING gist (organization_id WITH =, daterange(period_start, (period_end + 1), '[)'::text) WITH &&) WHERE ((property_id IS NULL));


--
-- Name: financial_period ex_property_financial_period_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_period
    ADD CONSTRAINT ex_property_financial_period_no_overlap EXCLUDE USING gist (organization_id WITH =, property_id WITH =, daterange(period_start, (period_end + 1), '[)'::text) WITH &&) WHERE ((property_id IS NOT NULL));


--
-- Name: stay_segment ex_stay_segment_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_segment
    ADD CONSTRAINT ex_stay_segment_no_overlap EXCLUDE USING gist (organization_id WITH =, unit_id WITH =, tstzrange(start_at, end_at, '[)'::text) WITH &&) WHERE ((status = 'ACTIVE'::text));


--
-- Name: external_record external_record_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_record
    ADD CONSTRAINT external_record_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: external_record external_record_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_record
    ADD CONSTRAINT external_record_pkey PRIMARY KEY (id);


--
-- Name: external_reference external_reference_integration_id_external_type_external_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_reference
    ADD CONSTRAINT external_reference_integration_id_external_type_external_id_key UNIQUE (integration_id, external_type, external_id);


--
-- Name: external_reference external_reference_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_reference
    ADD CONSTRAINT external_reference_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: external_reference external_reference_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_reference
    ADD CONSTRAINT external_reference_pkey PRIMARY KEY (id);


--
-- Name: extraction extraction_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.extraction
    ADD CONSTRAINT extraction_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: extraction extraction_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.extraction
    ADD CONSTRAINT extraction_pkey PRIMARY KEY (id);


--
-- Name: file_object file_object_organization_id_checksum_sha256_storage_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_object
    ADD CONSTRAINT file_object_organization_id_checksum_sha256_storage_key_key UNIQUE (organization_id, checksum_sha256, storage_key);


--
-- Name: file_object file_object_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_object
    ADD CONSTRAINT file_object_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: file_object file_object_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_object
    ADD CONSTRAINT file_object_pkey PRIMARY KEY (id);


--
-- Name: financial_document_line financial_document_line_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_document_line
    ADD CONSTRAINT financial_document_line_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: financial_document_line financial_document_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_document_line
    ADD CONSTRAINT financial_document_line_pkey PRIMARY KEY (id);


--
-- Name: financial_document financial_document_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_document
    ADD CONSTRAINT financial_document_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: financial_document financial_document_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_document
    ADD CONSTRAINT financial_document_pkey PRIMARY KEY (id);


--
-- Name: financial_period financial_period_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_period
    ADD CONSTRAINT financial_period_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: financial_period financial_period_organization_id_property_id_period_start_p_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_period
    ADD CONSTRAINT financial_period_organization_id_property_id_period_start_p_key UNIQUE (organization_id, property_id, period_start, period_end);


--
-- Name: financial_period financial_period_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_period
    ADD CONSTRAINT financial_period_pkey PRIMARY KEY (id);


--
-- Name: folio folio_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folio
    ADD CONSTRAINT folio_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: folio folio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folio
    ADD CONSTRAINT folio_pkey PRIMARY KEY (id);


--
-- Name: guest_identity_signal guest_identity_signal_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_identity_signal
    ADD CONSTRAINT guest_identity_signal_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: guest_identity_signal guest_identity_signal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_identity_signal
    ADD CONSTRAINT guest_identity_signal_pkey PRIMARY KEY (id);


--
-- Name: guest_match_candidate guest_match_candidate_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_match_candidate
    ADD CONSTRAINT guest_match_candidate_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: guest_match_candidate guest_match_candidate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_match_candidate
    ADD CONSTRAINT guest_match_candidate_pkey PRIMARY KEY (id);


--
-- Name: guest_merge_event guest_merge_event_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_merge_event
    ADD CONSTRAINT guest_merge_event_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: guest_merge_event guest_merge_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_merge_event
    ADD CONSTRAINT guest_merge_event_pkey PRIMARY KEY (id);


--
-- Name: guest_profile_alias guest_profile_alias_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile_alias
    ADD CONSTRAINT guest_profile_alias_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: guest_profile_alias guest_profile_alias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile_alias
    ADD CONSTRAINT guest_profile_alias_pkey PRIMARY KEY (id);


--
-- Name: guest_profile guest_profile_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile
    ADD CONSTRAINT guest_profile_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: guest_profile guest_profile_organization_id_party_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile
    ADD CONSTRAINT guest_profile_organization_id_party_id_key UNIQUE (organization_id, party_id);


--
-- Name: guest_profile guest_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile
    ADD CONSTRAINT guest_profile_pkey PRIMARY KEY (id);


--
-- Name: incident incident_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident
    ADD CONSTRAINT incident_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: incident incident_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident
    ADD CONSTRAINT incident_pkey PRIMARY KEY (id);


--
-- Name: integration integration_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration
    ADD CONSTRAINT integration_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: integration integration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration
    ADD CONSTRAINT integration_pkey PRIMARY KEY (id);


--
-- Name: integration_processing_record integration_processing_record_integration_id_external_event_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_processing_record
    ADD CONSTRAINT integration_processing_record_integration_id_external_event_key UNIQUE (integration_id, external_event_id, action_key);


--
-- Name: integration_processing_record integration_processing_record_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_processing_record
    ADD CONSTRAINT integration_processing_record_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: integration_processing_record integration_processing_record_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_processing_record
    ADD CONSTRAINT integration_processing_record_pkey PRIMARY KEY (id);


--
-- Name: inventory_item inventory_item_organization_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_item
    ADD CONSTRAINT inventory_item_organization_id_code_key UNIQUE (organization_id, code);


--
-- Name: inventory_item inventory_item_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_item
    ADD CONSTRAINT inventory_item_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: inventory_item inventory_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_item
    ADD CONSTRAINT inventory_item_pkey PRIMARY KEY (id);


--
-- Name: inventory_location inventory_location_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_location
    ADD CONSTRAINT inventory_location_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: inventory_location inventory_location_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_location
    ADD CONSTRAINT inventory_location_pkey PRIMARY KEY (id);


--
-- Name: inventory_location inventory_location_property_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_location
    ADD CONSTRAINT inventory_location_property_id_code_key UNIQUE (property_id, code);


--
-- Name: investment_project investment_project_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_project
    ADD CONSTRAINT investment_project_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: investment_project investment_project_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_project
    ADD CONSTRAINT investment_project_pkey PRIMARY KEY (id);


--
-- Name: maintenance_plan maintenance_plan_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_plan
    ADD CONSTRAINT maintenance_plan_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: maintenance_plan maintenance_plan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_plan
    ADD CONSTRAINT maintenance_plan_pkey PRIMARY KEY (id);


--
-- Name: message message_organization_id_deduplication_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_organization_id_deduplication_key_key UNIQUE (organization_id, deduplication_key);


--
-- Name: message message_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: message message_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- Name: message_template message_template_organization_id_code_version_no_language_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_template
    ADD CONSTRAINT message_template_organization_id_code_version_no_language_key UNIQUE (organization_id, code, version_no, language);


--
-- Name: message_template message_template_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_template
    ADD CONSTRAINT message_template_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: message_template message_template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_template
    ADD CONSTRAINT message_template_pkey PRIMARY KEY (id);


--
-- Name: money_account money_account_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.money_account
    ADD CONSTRAINT money_account_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: money_account money_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.money_account
    ADD CONSTRAINT money_account_pkey PRIMARY KEY (id);


--
-- Name: notification notification_organization_id_deduplication_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_organization_id_deduplication_key_key UNIQUE (organization_id, deduplication_key);


--
-- Name: notification notification_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: notification notification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_pkey PRIMARY KEY (id);


--
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- Name: organization organization_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_slug_key UNIQUE (slug);


--
-- Name: outbox_event outbox_event_domain_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.outbox_event
    ADD CONSTRAINT outbox_event_domain_event_id_key UNIQUE (domain_event_id);


--
-- Name: outbox_event outbox_event_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.outbox_event
    ADD CONSTRAINT outbox_event_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: outbox_event outbox_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.outbox_event
    ADD CONSTRAINT outbox_event_pkey PRIMARY KEY (id);


--
-- Name: package_component package_component_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package_component
    ADD CONSTRAINT package_component_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: package_component package_component_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package_component
    ADD CONSTRAINT package_component_pkey PRIMARY KEY (id);


--
-- Name: package package_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package
    ADD CONSTRAINT package_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: package package_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package
    ADD CONSTRAINT package_pkey PRIMARY KEY (id);


--
-- Name: package package_property_id_code_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package
    ADD CONSTRAINT package_property_id_code_version_no_key UNIQUE (property_id, code, version_no);


--
-- Name: party party_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party
    ADD CONSTRAINT party_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: party party_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party
    ADD CONSTRAINT party_pkey PRIMARY KEY (id);


--
-- Name: payment_allocation payment_allocation_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocation
    ADD CONSTRAINT payment_allocation_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: payment_allocation payment_allocation_payment_id_charge_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocation
    ADD CONSTRAINT payment_allocation_payment_id_charge_id_key UNIQUE (payment_id, charge_id);


--
-- Name: payment_allocation payment_allocation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocation
    ADD CONSTRAINT payment_allocation_pkey PRIMARY KEY (id);


--
-- Name: payment payment_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (id);


--
-- Name: permission permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission
    ADD CONSTRAINT permission_pkey PRIMARY KEY (code);


--
-- Name: pricing_rule pricing_rule_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_rule
    ADD CONSTRAINT pricing_rule_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: pricing_rule pricing_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_rule
    ADD CONSTRAINT pricing_rule_pkey PRIMARY KEY (id);


--
-- Name: pricing_rule pricing_rule_property_id_code_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_rule
    ADD CONSTRAINT pricing_rule_property_id_code_version_no_key UNIQUE (property_id, code, version_no);


--
-- Name: pricing_suggestion pricing_suggestion_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_suggestion
    ADD CONSTRAINT pricing_suggestion_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: pricing_suggestion pricing_suggestion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_suggestion
    ADD CONSTRAINT pricing_suggestion_pkey PRIMARY KEY (id);


--
-- Name: property property_organization_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property
    ADD CONSTRAINT property_organization_id_code_key UNIQUE (organization_id, code);


--
-- Name: property property_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property
    ADD CONSTRAINT property_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: property property_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property
    ADD CONSTRAINT property_pkey PRIMARY KEY (id);


--
-- Name: property_stay_policy property_stay_policy_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_stay_policy
    ADD CONSTRAINT property_stay_policy_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: property_stay_policy property_stay_policy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_stay_policy
    ADD CONSTRAINT property_stay_policy_pkey PRIMARY KEY (id);


--
-- Name: property_stay_policy property_stay_policy_property_id_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_stay_policy
    ADD CONSTRAINT property_stay_policy_property_id_version_no_key UNIQUE (property_id, version_no);


--
-- Name: rate rate_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate
    ADD CONSTRAINT rate_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: rate rate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate
    ADD CONSTRAINT rate_pkey PRIMARY KEY (id);


--
-- Name: rate_plan rate_plan_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_plan
    ADD CONSTRAINT rate_plan_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: rate_plan rate_plan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_plan
    ADD CONSTRAINT rate_plan_pkey PRIMARY KEY (id);


--
-- Name: rate_plan rate_plan_property_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_plan
    ADD CONSTRAINT rate_plan_property_id_code_key UNIQUE (property_id, code);


--
-- Name: rate_snapshot rate_snapshot_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_snapshot
    ADD CONSTRAINT rate_snapshot_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: rate_snapshot rate_snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_snapshot
    ADD CONSTRAINT rate_snapshot_pkey PRIMARY KEY (id);


--
-- Name: recommendation recommendation_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recommendation
    ADD CONSTRAINT recommendation_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: recommendation recommendation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recommendation
    ADD CONSTRAINT recommendation_pkey PRIMARY KEY (id);


--
-- Name: reconciliation_link reconciliation_link_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: reconciliation_link reconciliation_link_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_pkey PRIMARY KEY (id);


--
-- Name: refund refund_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refund
    ADD CONSTRAINT refund_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: refund refund_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refund
    ADD CONSTRAINT refund_pkey PRIMARY KEY (id);


--
-- Name: reorder_rule reorder_rule_inventory_item_id_inventory_location_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_rule
    ADD CONSTRAINT reorder_rule_inventory_item_id_inventory_location_id_key UNIQUE (inventory_item_id, inventory_location_id);


--
-- Name: reorder_rule reorder_rule_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_rule
    ADD CONSTRAINT reorder_rule_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: reorder_rule reorder_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_rule
    ADD CONSTRAINT reorder_rule_pkey PRIMARY KEY (id);


--
-- Name: reservation_item reservation_item_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_item
    ADD CONSTRAINT reservation_item_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: reservation_item reservation_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_item
    ADD CONSTRAINT reservation_item_pkey PRIMARY KEY (id);


--
-- Name: reservation reservation_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: reservation reservation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_pkey PRIMARY KEY (id);


--
-- Name: reservation reservation_property_id_reference_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_property_id_reference_code_key UNIQUE (property_id, reference_code);


--
-- Name: resource resource_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: resource resource_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_pkey PRIMARY KEY (id);


--
-- Name: resource resource_property_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_property_id_code_key UNIQUE (property_id, code);


--
-- Name: resource_reservation resource_reservation_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_reservation
    ADD CONSTRAINT resource_reservation_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: resource_reservation resource_reservation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_reservation
    ADD CONSTRAINT resource_reservation_pkey PRIMARY KEY (id);


--
-- Name: role_assignment role_assignment_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignment
    ADD CONSTRAINT role_assignment_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: role_assignment role_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignment
    ADD CONSTRAINT role_assignment_pkey PRIMARY KEY (id);


--
-- Name: role role_organization_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_organization_id_code_key UNIQUE (organization_id, code);


--
-- Name: role role_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: role_permission role_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permission
    ADD CONSTRAINT role_permission_pkey PRIMARY KEY (role_id, permission_code);


--
-- Name: role role_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (id);


--
-- Name: service_booking service_booking_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_booking
    ADD CONSTRAINT service_booking_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: service_booking service_booking_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_booking
    ADD CONSTRAINT service_booking_pkey PRIMARY KEY (id);


--
-- Name: service_execution service_execution_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_execution
    ADD CONSTRAINT service_execution_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: service_execution service_execution_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_execution
    ADD CONSTRAINT service_execution_pkey PRIMARY KEY (id);


--
-- Name: service service_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: service service_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_pkey PRIMARY KEY (id);


--
-- Name: service service_property_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_property_id_code_key UNIQUE (property_id, code);


--
-- Name: settlement_application settlement_application_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_application
    ADD CONSTRAINT settlement_application_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: settlement_application settlement_application_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_application
    ADD CONSTRAINT settlement_application_pkey PRIMARY KEY (id);


--
-- Name: settlement_entry settlement_entry_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_entry
    ADD CONSTRAINT settlement_entry_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: settlement_entry settlement_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_entry
    ADD CONSTRAINT settlement_entry_pkey PRIMARY KEY (id);


--
-- Name: stay_guest stay_guest_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_guest
    ADD CONSTRAINT stay_guest_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: stay_guest stay_guest_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_guest
    ADD CONSTRAINT stay_guest_pkey PRIMARY KEY (id);


--
-- Name: stay stay_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay
    ADD CONSTRAINT stay_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: stay stay_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay
    ADD CONSTRAINT stay_pkey PRIMARY KEY (id);


--
-- Name: stay_segment stay_segment_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_segment
    ADD CONSTRAINT stay_segment_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: stay_segment stay_segment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_segment
    ADD CONSTRAINT stay_segment_pkey PRIMARY KEY (id);


--
-- Name: stock_movement stock_movement_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: stock_movement stock_movement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_pkey PRIMARY KEY (id);


--
-- Name: task task_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: task task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_pkey PRIMARY KEY (id);


--
-- Name: task_template task_template_organization_id_code_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_template
    ADD CONSTRAINT task_template_organization_id_code_version_no_key UNIQUE (organization_id, code, version_no);


--
-- Name: task_template task_template_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_template
    ADD CONSTRAINT task_template_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: task_template task_template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_template
    ADD CONSTRAINT task_template_pkey PRIMARY KEY (id);


--
-- Name: turnover turnover_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turnover
    ADD CONSTRAINT turnover_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: turnover turnover_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turnover
    ADD CONSTRAINT turnover_pkey PRIMARY KEY (id);


--
-- Name: unit unit_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: unit unit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_pkey PRIMARY KEY (id);


--
-- Name: unit unit_property_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_property_id_code_key UNIQUE (property_id, code);


--
-- Name: unit_type unit_type_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_type
    ADD CONSTRAINT unit_type_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: unit_type unit_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_type
    ADD CONSTRAINT unit_type_pkey PRIMARY KEY (id);


--
-- Name: unit_type unit_type_property_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_type
    ADD CONSTRAINT unit_type_property_id_code_key UNIQUE (property_id, code);


--
-- Name: user_account user_account_organization_id_email_login_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_organization_id_email_login_key UNIQUE (organization_id, email_login);


--
-- Name: user_account user_account_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: user_account user_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_pkey PRIMARY KEY (id);


--
-- Name: work_log work_log_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_log
    ADD CONSTRAINT work_log_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: work_log work_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_log
    ADD CONSTRAINT work_log_pkey PRIMARY KEY (id);


--
-- Name: work_order work_order_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: work_order work_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_pkey PRIMARY KEY (id);


--
-- Name: zone zone_organization_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone
    ADD CONSTRAINT zone_organization_id_id_key UNIQUE (organization_id, id);


--
-- Name: zone zone_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone
    ADD CONSTRAINT zone_pkey PRIMARY KEY (id);


--
-- Name: idx_allocation_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_allocation_event ON public.allocation USING btree (economic_event_id);


--
-- Name: idx_cash_movement_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cash_movement_date ON public.cash_movement USING btree (organization_id, occurred_at);


--
-- Name: idx_command_idempotency_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_command_idempotency_expiry ON public.command_idempotency USING btree (organization_id, expires_at) WHERE (expires_at IS NOT NULL);


--
-- Name: idx_dq_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dq_open ON public.data_quality_issue USING btree (organization_id, status, severity);


--
-- Name: idx_economic_event_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_economic_event_date ON public.economic_event USING btree (organization_id, economic_date, status);


--
-- Name: idx_external_record_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_external_record_lookup ON public.external_record USING btree (integration_id, external_type, external_id);


--
-- Name: idx_guest_identity_signal_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_guest_identity_signal_lookup ON public.guest_identity_signal USING btree (organization_id, signal_type, value_hash) WHERE ((active = true) AND (value_hash IS NOT NULL));


--
-- Name: idx_incident_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incident_open ON public.incident USING btree (property_id, status, severity);


--
-- Name: idx_integration_health; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_health ON public.integration USING btree (organization_id, status, last_success_at);


--
-- Name: idx_message_conversation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_conversation ON public.message USING btree (conversation_id, created_at);


--
-- Name: idx_notification_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_user ON public.notification USING btree (target_user_id, acknowledged_at, created_at);


--
-- Name: idx_outbox_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_outbox_pending ON public.outbox_event USING btree (status, available_at) WHERE (status = ANY (ARRAY['PENDING'::text, 'FAILED_RETRYABLE'::text]));


--
-- Name: idx_pricing_suggestion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pricing_suggestion ON public.pricing_suggestion USING btree (property_id, stay_date, status);


--
-- Name: idx_processing_retry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_processing_retry ON public.integration_processing_record USING btree (status, last_attempt_at);


--
-- Name: idx_rate_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rate_lookup ON public.rate USING btree (property_id, unit_type_id, stay_date, rate_plan_id);


--
-- Name: idx_reservation_item_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reservation_item_dates ON public.reservation_item USING btree (arrival_date, departure_date);


--
-- Name: idx_reservation_property_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reservation_property_dates ON public.reservation USING btree (property_id, booked_at);


--
-- Name: idx_resource_reservation_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resource_reservation_time ON public.resource_reservation USING btree (resource_id, effective_start_at, effective_end_at);


--
-- Name: idx_settlement_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_settlement_open ON public.settlement_entry USING btree (organization_id, status);


--
-- Name: idx_stay_segment_unit_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stay_segment_unit_time ON public.stay_segment USING btree (unit_id, start_at, end_at);


--
-- Name: idx_stay_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stay_status ON public.stay USING btree (organization_id, status);


--
-- Name: idx_stock_item_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_item_time ON public.stock_movement USING btree (inventory_item_id, occurred_at);


--
-- Name: idx_task_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_due ON public.task USING btree (property_id, status, due_at);


--
-- Name: idx_turnover_deadline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_turnover_deadline ON public.turnover USING btree (property_id, status, ready_deadline);


--
-- Name: uq_guest_match_candidate_pair_open; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_guest_match_candidate_pair_open ON public.guest_match_candidate USING btree (organization_id, LEAST(guest_profile_a_id, guest_profile_b_id), GREATEST(guest_profile_a_id, guest_profile_b_id)) WHERE (status = 'OPEN'::text);


--
-- Name: uq_guest_profile_active_alias; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_guest_profile_active_alias ON public.guest_profile_alias USING btree (organization_id, alias_guest_profile_id) WHERE (active = true);


--
-- Name: allocation trg_allocation_property_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_allocation_property_context BEFORE INSERT OR UPDATE ON public.allocation FOR EACH ROW EXECUTE FUNCTION public.osg_guard_allocation_property_context();


--
-- Name: economic_event trg_economic_event_period_assignment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_economic_event_period_assignment BEFORE INSERT OR UPDATE ON public.economic_event FOR EACH ROW EXECUTE FUNCTION public.osg_guard_economic_event_period_assignment();


--
-- Name: economic_event trg_economic_event_reporting_currency; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_economic_event_reporting_currency BEFORE INSERT OR UPDATE ON public.economic_event FOR EACH ROW EXECUTE FUNCTION public.osg_guard_economic_event_reporting_currency();


--
-- Name: external_reference trg_external_reference_target_tenant; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_external_reference_target_tenant BEFORE INSERT OR UPDATE OF organization_id, osg_entity_type, osg_entity_id ON public.external_reference FOR EACH ROW EXECUTE FUNCTION public.osg_guard_external_reference_target_tenant();


--
-- Name: folio trg_folio_close_balance; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_folio_close_balance BEFORE UPDATE ON public.folio FOR EACH ROW EXECUTE FUNCTION public.osg_guard_folio_close_balance();


--
-- Name: allocation trg_guard_allocation_of_posted_event; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard_allocation_of_posted_event BEFORE INSERT OR DELETE OR UPDATE ON public.allocation FOR EACH ROW EXECUTE FUNCTION public.osg_guard_allocation_of_posted_event();


--
-- Name: charge trg_guard_charge_reversal; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard_charge_reversal BEFORE INSERT OR UPDATE ON public.charge FOR EACH ROW EXECUTE FUNCTION public.osg_guard_charge_reversal();


--
-- Name: economic_event trg_guard_closed_period_event; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard_closed_period_event BEFORE INSERT OR UPDATE ON public.economic_event FOR EACH ROW EXECUTE FUNCTION public.osg_guard_closed_period_event();


--
-- Name: charge trg_guard_final_charge_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard_final_charge_delete BEFORE DELETE ON public.charge FOR EACH ROW EXECUTE FUNCTION public.osg_guard_final_charge_delete();


--
-- Name: charge trg_guard_final_charge_immutability; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard_final_charge_immutability BEFORE UPDATE ON public.charge FOR EACH ROW EXECUTE FUNCTION public.osg_guard_final_charge_immutability();


--
-- Name: financial_period trg_guard_financial_period_transition; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard_financial_period_transition BEFORE UPDATE ON public.financial_period FOR EACH ROW EXECUTE FUNCTION public.osg_guard_financial_period_transition();


--
-- Name: economic_event trg_guard_hard_closed_existing_event; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard_hard_closed_existing_event BEFORE DELETE OR UPDATE ON public.economic_event FOR EACH ROW EXECUTE FUNCTION public.osg_guard_hard_closed_existing_event();


--
-- Name: economic_event trg_guard_posted_economic_event; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard_posted_economic_event BEFORE UPDATE ON public.economic_event FOR EACH ROW EXECUTE FUNCTION public.osg_guard_posted_economic_event_v098();


--
-- Name: guest_profile_alias trg_guest_profile_alias_integrity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guest_profile_alias_integrity BEFORE INSERT OR UPDATE ON public.guest_profile_alias FOR EACH ROW EXECUTE FUNCTION public.osg_guard_guest_profile_alias();


--
-- Name: incident trg_incident_property_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_incident_property_context BEFORE INSERT OR UPDATE ON public.incident FOR EACH ROW EXECUTE FUNCTION public.osg_guard_incident_property_context();


--
-- Name: payment trg_payment_folio_currency; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_payment_folio_currency BEFORE INSERT OR UPDATE ON public.payment FOR EACH ROW EXECUTE FUNCTION public.osg_guard_payment_folio_currency();


--
-- Name: refund trg_refund_payment_currency_and_amount; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_refund_payment_currency_and_amount BEFORE INSERT OR UPDATE ON public.refund FOR EACH ROW EXECUTE FUNCTION public.osg_guard_refund_payment_currency_and_amount();


--
-- Name: reservation_item trg_reservation_item_property_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_reservation_item_property_context BEFORE INSERT OR UPDATE ON public.reservation_item FOR EACH ROW EXECUTE FUNCTION public.osg_guard_reservation_item_property_context();


--
-- Name: resource_reservation trg_resource_reservation_property_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_resource_reservation_property_context BEFORE INSERT OR UPDATE ON public.resource_reservation FOR EACH ROW EXECUTE FUNCTION public.osg_guard_resource_reservation_property_context();


--
-- Name: service_booking trg_service_booking_property_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_service_booking_property_context BEFORE INSERT OR UPDATE ON public.service_booking FOR EACH ROW EXECUTE FUNCTION public.osg_guard_service_booking_property_context();


--
-- Name: stay_segment trg_stay_segment_property_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_stay_segment_property_context BEFORE INSERT OR UPDATE ON public.stay_segment FOR EACH ROW EXECUTE FUNCTION public.osg_guard_stay_segment_property_context();


--
-- Name: turnover trg_turnover_property_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_turnover_property_context BEFORE INSERT OR UPDATE ON public.turnover FOR EACH ROW EXECUTE FUNCTION public.osg_guard_turnover_property_context();


--
-- Name: allocation allocation_organization_id_allocation_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_allocation_rule_id_fkey FOREIGN KEY (organization_id, allocation_rule_id) REFERENCES public.allocation_rule(organization_id, id);


--
-- Name: allocation allocation_organization_id_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_asset_id_fkey FOREIGN KEY (organization_id, asset_id) REFERENCES public.asset(organization_id, id);


--
-- Name: allocation allocation_organization_id_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_channel_id_fkey FOREIGN KEY (organization_id, channel_id) REFERENCES public.channel(organization_id, id);


--
-- Name: allocation allocation_organization_id_cost_center_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_cost_center_id_fkey FOREIGN KEY (organization_id, cost_center_id) REFERENCES public.cost_center(organization_id, id);


--
-- Name: allocation allocation_organization_id_economic_bearer_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_economic_bearer_party_id_fkey FOREIGN KEY (organization_id, economic_bearer_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: allocation allocation_organization_id_economic_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_economic_event_id_fkey FOREIGN KEY (organization_id, economic_event_id) REFERENCES public.economic_event(organization_id, id);


--
-- Name: allocation allocation_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: allocation allocation_organization_id_investment_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_investment_project_id_fkey FOREIGN KEY (organization_id, investment_project_id) REFERENCES public.investment_project(organization_id, id);


--
-- Name: allocation allocation_organization_id_paid_by_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_paid_by_party_id_fkey FOREIGN KEY (organization_id, paid_by_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: allocation allocation_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: allocation allocation_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.resource(organization_id, id);


--
-- Name: allocation allocation_organization_id_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_service_id_fkey FOREIGN KEY (organization_id, service_id) REFERENCES public.service(organization_id, id);


--
-- Name: allocation allocation_organization_id_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_stay_id_fkey FOREIGN KEY (organization_id, stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: allocation allocation_organization_id_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_organization_id_unit_id_fkey FOREIGN KEY (organization_id, unit_id) REFERENCES public.unit(organization_id, id);


--
-- Name: allocation_rule allocation_rule_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rule
    ADD CONSTRAINT allocation_rule_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: allocation_rule allocation_rule_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rule
    ADD CONSTRAINT allocation_rule_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: approval_decision approval_decision_organization_id_approval_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_decision
    ADD CONSTRAINT approval_decision_organization_id_approval_request_id_fkey FOREIGN KEY (organization_id, approval_request_id) REFERENCES public.approval_request(organization_id, id);


--
-- Name: approval_decision approval_decision_organization_id_approver_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_decision
    ADD CONSTRAINT approval_decision_organization_id_approver_user_id_fkey FOREIGN KEY (organization_id, approver_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: approval_decision approval_decision_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_decision
    ADD CONSTRAINT approval_decision_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: approval_policy approval_policy_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_policy
    ADD CONSTRAINT approval_policy_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: approval_policy approval_policy_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_policy
    ADD CONSTRAINT approval_policy_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: approval_request approval_request_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: approval_request approval_request_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: approval_request approval_request_organization_id_requested_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_organization_id_requested_by_user_id_fkey FOREIGN KEY (organization_id, requested_by_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: asset asset_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: asset asset_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: asset asset_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.resource(organization_id, id);


--
-- Name: asset asset_organization_id_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_organization_id_unit_id_fkey FOREIGN KEY (organization_id, unit_id) REFERENCES public.unit(organization_id, id);


--
-- Name: asset asset_organization_id_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_organization_id_zone_id_fkey FOREIGN KEY (organization_id, zone_id) REFERENCES public.zone(organization_id, id);


--
-- Name: attachment_link attachment_link_organization_id_file_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_link
    ADD CONSTRAINT attachment_link_organization_id_file_object_id_fkey FOREIGN KEY (organization_id, file_object_id) REFERENCES public.file_object(organization_id, id);


--
-- Name: attachment_link attachment_link_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_link
    ADD CONSTRAINT attachment_link_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: audit_event audit_event_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_event
    ADD CONSTRAINT audit_event_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: audit_event audit_event_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_event
    ADD CONSTRAINT audit_event_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: automation_execution automation_execution_organization_id_automation_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_execution
    ADD CONSTRAINT automation_execution_organization_id_automation_rule_id_fkey FOREIGN KEY (organization_id, automation_rule_id) REFERENCES public.automation_rule(organization_id, id);


--
-- Name: automation_execution automation_execution_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_execution
    ADD CONSTRAINT automation_execution_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: automation_execution automation_execution_organization_id_trigger_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_execution
    ADD CONSTRAINT automation_execution_organization_id_trigger_event_id_fkey FOREIGN KEY (organization_id, trigger_event_id) REFERENCES public.domain_event(organization_id, id);


--
-- Name: automation_rule automation_rule_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_rule
    ADD CONSTRAINT automation_rule_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: automation_rule automation_rule_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_rule
    ADD CONSTRAINT automation_rule_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: availability_block availability_block_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_block
    ADD CONSTRAINT availability_block_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: availability_block availability_block_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_block
    ADD CONSTRAINT availability_block_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: availability_block availability_block_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_block
    ADD CONSTRAINT availability_block_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.resource(organization_id, id);


--
-- Name: availability_block availability_block_organization_id_source_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_block
    ADD CONSTRAINT availability_block_organization_id_source_incident_id_fkey FOREIGN KEY (organization_id, source_incident_id) REFERENCES public.incident(organization_id, id);


--
-- Name: availability_block availability_block_organization_id_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_block
    ADD CONSTRAINT availability_block_organization_id_unit_id_fkey FOREIGN KEY (organization_id, unit_id) REFERENCES public.unit(organization_id, id);


--
-- Name: cash_movement cash_movement_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movement
    ADD CONSTRAINT cash_movement_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: cash_movement cash_movement_organization_id_from_money_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movement
    ADD CONSTRAINT cash_movement_organization_id_from_money_account_id_fkey FOREIGN KEY (organization_id, from_money_account_id) REFERENCES public.money_account(organization_id, id);


--
-- Name: cash_movement cash_movement_organization_id_to_money_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movement
    ADD CONSTRAINT cash_movement_organization_id_to_money_account_id_fkey FOREIGN KEY (organization_id, to_money_account_id) REFERENCES public.money_account(organization_id, id);


--
-- Name: channel channel_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel
    ADD CONSTRAINT channel_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: channel channel_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel
    ADD CONSTRAINT channel_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: charge charge_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge
    ADD CONSTRAINT charge_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: charge charge_organization_id_folio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge
    ADD CONSTRAINT charge_organization_id_folio_id_fkey FOREIGN KEY (organization_id, folio_id) REFERENCES public.folio(organization_id, id);


--
-- Name: charge charge_organization_id_reverses_charge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge
    ADD CONSTRAINT charge_organization_id_reverses_charge_id_fkey FOREIGN KEY (organization_id, reverses_charge_id) REFERENCES public.charge(organization_id, id);


--
-- Name: command_idempotency command_idempotency_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.command_idempotency
    ADD CONSTRAINT command_idempotency_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: command_idempotency command_idempotency_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.command_idempotency
    ADD CONSTRAINT command_idempotency_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: commercial_policy_snapshot commercial_policy_snapshot_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commercial_policy_snapshot
    ADD CONSTRAINT commercial_policy_snapshot_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: commercial_policy_snapshot commercial_policy_snapshot_organization_id_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commercial_policy_snapshot
    ADD CONSTRAINT commercial_policy_snapshot_organization_id_reservation_id_fkey FOREIGN KEY (organization_id, reservation_id) REFERENCES public.reservation(organization_id, id);


--
-- Name: commercial_policy_snapshot commercial_policy_snapshot_organization_id_reservation_ite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commercial_policy_snapshot
    ADD CONSTRAINT commercial_policy_snapshot_organization_id_reservation_ite_fkey FOREIGN KEY (organization_id, reservation_item_id) REFERENCES public.reservation_item(organization_id, id);


--
-- Name: commercial_policy_snapshot commercial_policy_snapshot_organization_id_supersedes_snap_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commercial_policy_snapshot
    ADD CONSTRAINT commercial_policy_snapshot_organization_id_supersedes_snap_fkey FOREIGN KEY (organization_id, supersedes_snapshot_id) REFERENCES public.commercial_policy_snapshot(organization_id, id);


--
-- Name: commission_rule commission_rule_organization_id_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_organization_id_channel_id_fkey FOREIGN KEY (organization_id, channel_id) REFERENCES public.channel(organization_id, id);


--
-- Name: commission_rule commission_rule_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: communication_consent communication_consent_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communication_consent
    ADD CONSTRAINT communication_consent_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: communication_consent communication_consent_organization_id_guest_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communication_consent
    ADD CONSTRAINT communication_consent_organization_id_guest_profile_id_fkey FOREIGN KEY (organization_id, guest_profile_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: conflict_case conflict_case_organization_id_availability_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conflict_case
    ADD CONSTRAINT conflict_case_organization_id_availability_block_id_fkey FOREIGN KEY (organization_id, availability_block_id) REFERENCES public.availability_block(organization_id, id);


--
-- Name: conflict_case conflict_case_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conflict_case
    ADD CONSTRAINT conflict_case_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: conflict_case conflict_case_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conflict_case
    ADD CONSTRAINT conflict_case_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: conflict_case conflict_case_organization_id_reservation_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conflict_case
    ADD CONSTRAINT conflict_case_organization_id_reservation_item_id_fkey FOREIGN KEY (organization_id, reservation_item_id) REFERENCES public.reservation_item(organization_id, id);


--
-- Name: conflict_case conflict_case_organization_id_resolved_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conflict_case
    ADD CONSTRAINT conflict_case_organization_id_resolved_by_user_id_fkey FOREIGN KEY (organization_id, resolved_by_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: conflict_case conflict_case_organization_id_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conflict_case
    ADD CONSTRAINT conflict_case_organization_id_stay_id_fkey FOREIGN KEY (organization_id, stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: conversation conversation_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: conversation conversation_organization_id_guest_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_organization_id_guest_profile_id_fkey FOREIGN KEY (organization_id, guest_profile_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: conversation conversation_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: conversation conversation_organization_id_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_organization_id_reservation_id_fkey FOREIGN KEY (organization_id, reservation_id) REFERENCES public.reservation(organization_id, id);


--
-- Name: conversation conversation_organization_id_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_organization_id_stay_id_fkey FOREIGN KEY (organization_id, stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: cost_center cost_center_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_center
    ADD CONSTRAINT cost_center_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: cost_center cost_center_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_center
    ADD CONSTRAINT cost_center_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: data_quality_issue data_quality_issue_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_quality_issue
    ADD CONSTRAINT data_quality_issue_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: data_quality_issue data_quality_issue_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_quality_issue
    ADD CONSTRAINT data_quality_issue_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: domain_event domain_event_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_event
    ADD CONSTRAINT domain_event_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: domain_event domain_event_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_event
    ADD CONSTRAINT domain_event_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: economic_event economic_event_organization_id_financial_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_organization_id_financial_period_id_fkey FOREIGN KEY (organization_id, financial_period_id) REFERENCES public.financial_period(organization_id, id);


--
-- Name: economic_event economic_event_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: economic_event economic_event_organization_id_posted_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_organization_id_posted_by_user_id_fkey FOREIGN KEY (organization_id, posted_by_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: economic_event economic_event_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: economic_event economic_event_organization_id_relates_to_financial_period_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_organization_id_relates_to_financial_period_fkey FOREIGN KEY (organization_id, relates_to_financial_period_id) REFERENCES public.financial_period(organization_id, id);


--
-- Name: economic_event economic_event_organization_id_reverses_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_organization_id_reverses_event_id_fkey FOREIGN KEY (organization_id, reverses_event_id) REFERENCES public.economic_event(organization_id, id);


--
-- Name: economic_event economic_event_organization_id_source_charge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_organization_id_source_charge_id_fkey FOREIGN KEY (organization_id, source_charge_id) REFERENCES public.charge(organization_id, id);


--
-- Name: economic_event economic_event_organization_id_source_document_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_event
    ADD CONSTRAINT economic_event_organization_id_source_document_line_id_fkey FOREIGN KEY (organization_id, source_document_line_id) REFERENCES public.financial_document_line(organization_id, id);


--
-- Name: external_record external_record_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_record
    ADD CONSTRAINT external_record_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: external_record external_record_organization_id_integration_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_record
    ADD CONSTRAINT external_record_organization_id_integration_id_fkey FOREIGN KEY (organization_id, integration_id) REFERENCES public.integration(organization_id, id);


--
-- Name: external_reference external_reference_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_reference
    ADD CONSTRAINT external_reference_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: external_reference external_reference_organization_id_integration_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_reference
    ADD CONSTRAINT external_reference_organization_id_integration_id_fkey FOREIGN KEY (organization_id, integration_id) REFERENCES public.integration(organization_id, id);


--
-- Name: extraction extraction_organization_id_file_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.extraction
    ADD CONSTRAINT extraction_organization_id_file_object_id_fkey FOREIGN KEY (organization_id, file_object_id) REFERENCES public.file_object(organization_id, id);


--
-- Name: extraction extraction_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.extraction
    ADD CONSTRAINT extraction_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: file_object file_object_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_object
    ADD CONSTRAINT file_object_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: file_object file_object_organization_id_uploaded_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_object
    ADD CONSTRAINT file_object_organization_id_uploaded_by_user_id_fkey FOREIGN KEY (organization_id, uploaded_by_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: financial_document_line financial_document_line_organization_id_financial_document_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_document_line
    ADD CONSTRAINT financial_document_line_organization_id_financial_document_fkey FOREIGN KEY (organization_id, financial_document_id) REFERENCES public.financial_document(organization_id, id);


--
-- Name: financial_document_line financial_document_line_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_document_line
    ADD CONSTRAINT financial_document_line_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: financial_document financial_document_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_document
    ADD CONSTRAINT financial_document_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: financial_document financial_document_organization_id_issuer_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_document
    ADD CONSTRAINT financial_document_organization_id_issuer_party_id_fkey FOREIGN KEY (organization_id, issuer_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: financial_document financial_document_organization_id_recipient_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_document
    ADD CONSTRAINT financial_document_organization_id_recipient_party_id_fkey FOREIGN KEY (organization_id, recipient_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: financial_period financial_period_organization_id_closed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_period
    ADD CONSTRAINT financial_period_organization_id_closed_by_user_id_fkey FOREIGN KEY (organization_id, closed_by_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: financial_period financial_period_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_period
    ADD CONSTRAINT financial_period_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: financial_period financial_period_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.financial_period
    ADD CONSTRAINT financial_period_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: folio folio_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folio
    ADD CONSTRAINT folio_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: folio folio_organization_id_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folio
    ADD CONSTRAINT folio_organization_id_reservation_id_fkey FOREIGN KEY (organization_id, reservation_id) REFERENCES public.reservation(organization_id, id);


--
-- Name: folio folio_organization_id_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folio
    ADD CONSTRAINT folio_organization_id_stay_id_fkey FOREIGN KEY (organization_id, stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: guest_identity_signal guest_identity_signal_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_identity_signal
    ADD CONSTRAINT guest_identity_signal_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: guest_identity_signal guest_identity_signal_organization_id_guest_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_identity_signal
    ADD CONSTRAINT guest_identity_signal_organization_id_guest_profile_id_fkey FOREIGN KEY (organization_id, guest_profile_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: guest_match_candidate guest_match_candidate_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_match_candidate
    ADD CONSTRAINT guest_match_candidate_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: guest_match_candidate guest_match_candidate_organization_id_guest_profile_a_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_match_candidate
    ADD CONSTRAINT guest_match_candidate_organization_id_guest_profile_a_id_fkey FOREIGN KEY (organization_id, guest_profile_a_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: guest_match_candidate guest_match_candidate_organization_id_guest_profile_b_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_match_candidate
    ADD CONSTRAINT guest_match_candidate_organization_id_guest_profile_b_id_fkey FOREIGN KEY (organization_id, guest_profile_b_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: guest_match_candidate guest_match_candidate_organization_id_reviewed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_match_candidate
    ADD CONSTRAINT guest_match_candidate_organization_id_reviewed_by_user_id_fkey FOREIGN KEY (organization_id, reviewed_by_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: guest_merge_event guest_merge_event_organization_id_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_merge_event
    ADD CONSTRAINT guest_merge_event_organization_id_actor_user_id_fkey FOREIGN KEY (organization_id, actor_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: guest_merge_event guest_merge_event_organization_id_canonical_guest_profile__fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_merge_event
    ADD CONSTRAINT guest_merge_event_organization_id_canonical_guest_profile__fkey FOREIGN KEY (organization_id, canonical_guest_profile_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: guest_merge_event guest_merge_event_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_merge_event
    ADD CONSTRAINT guest_merge_event_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: guest_merge_event guest_merge_event_organization_id_match_candidate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_merge_event
    ADD CONSTRAINT guest_merge_event_organization_id_match_candidate_id_fkey FOREIGN KEY (organization_id, match_candidate_id) REFERENCES public.guest_match_candidate(organization_id, id);


--
-- Name: guest_merge_event guest_merge_event_organization_id_merged_guest_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_merge_event
    ADD CONSTRAINT guest_merge_event_organization_id_merged_guest_profile_id_fkey FOREIGN KEY (organization_id, merged_guest_profile_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: guest_profile_alias guest_profile_alias_organization_id_alias_guest_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile_alias
    ADD CONSTRAINT guest_profile_alias_organization_id_alias_guest_profile_id_fkey FOREIGN KEY (organization_id, alias_guest_profile_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: guest_profile_alias guest_profile_alias_organization_id_canonical_guest_profil_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile_alias
    ADD CONSTRAINT guest_profile_alias_organization_id_canonical_guest_profil_fkey FOREIGN KEY (organization_id, canonical_guest_profile_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: guest_profile_alias guest_profile_alias_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile_alias
    ADD CONSTRAINT guest_profile_alias_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: guest_profile guest_profile_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile
    ADD CONSTRAINT guest_profile_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: guest_profile guest_profile_organization_id_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guest_profile
    ADD CONSTRAINT guest_profile_organization_id_party_id_fkey FOREIGN KEY (organization_id, party_id) REFERENCES public.party(organization_id, id);


--
-- Name: incident incident_organization_id_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident
    ADD CONSTRAINT incident_organization_id_asset_id_fkey FOREIGN KEY (organization_id, asset_id) REFERENCES public.asset(organization_id, id);


--
-- Name: incident incident_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident
    ADD CONSTRAINT incident_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: incident incident_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident
    ADD CONSTRAINT incident_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: incident incident_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident
    ADD CONSTRAINT incident_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.resource(organization_id, id);


--
-- Name: incident incident_organization_id_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident
    ADD CONSTRAINT incident_organization_id_unit_id_fkey FOREIGN KEY (organization_id, unit_id) REFERENCES public.unit(organization_id, id);


--
-- Name: integration integration_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration
    ADD CONSTRAINT integration_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: integration integration_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration
    ADD CONSTRAINT integration_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: integration_processing_record integration_processing_record_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_processing_record
    ADD CONSTRAINT integration_processing_record_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: integration_processing_record integration_processing_record_organization_id_integration__fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_processing_record
    ADD CONSTRAINT integration_processing_record_organization_id_integration__fkey FOREIGN KEY (organization_id, integration_id) REFERENCES public.integration(organization_id, id);


--
-- Name: inventory_item inventory_item_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_item
    ADD CONSTRAINT inventory_item_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: inventory_location inventory_location_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_location
    ADD CONSTRAINT inventory_location_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: inventory_location inventory_location_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_location
    ADD CONSTRAINT inventory_location_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: inventory_location inventory_location_organization_id_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_location
    ADD CONSTRAINT inventory_location_organization_id_zone_id_fkey FOREIGN KEY (organization_id, zone_id) REFERENCES public.zone(organization_id, id);


--
-- Name: investment_project investment_project_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_project
    ADD CONSTRAINT investment_project_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: investment_project investment_project_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_project
    ADD CONSTRAINT investment_project_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: maintenance_plan maintenance_plan_organization_id_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_plan
    ADD CONSTRAINT maintenance_plan_organization_id_asset_id_fkey FOREIGN KEY (organization_id, asset_id) REFERENCES public.asset(organization_id, id);


--
-- Name: maintenance_plan maintenance_plan_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_plan
    ADD CONSTRAINT maintenance_plan_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: maintenance_plan maintenance_plan_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_plan
    ADD CONSTRAINT maintenance_plan_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: maintenance_plan maintenance_plan_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_plan
    ADD CONSTRAINT maintenance_plan_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.resource(organization_id, id);


--
-- Name: maintenance_plan maintenance_plan_organization_id_task_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_plan
    ADD CONSTRAINT maintenance_plan_organization_id_task_template_id_fkey FOREIGN KEY (organization_id, task_template_id) REFERENCES public.task_template(organization_id, id);


--
-- Name: message message_organization_id_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_organization_id_conversation_id_fkey FOREIGN KEY (organization_id, conversation_id) REFERENCES public.conversation(organization_id, id);


--
-- Name: message message_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: message message_organization_id_recipient_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_organization_id_recipient_party_id_fkey FOREIGN KEY (organization_id, recipient_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: message message_organization_id_sender_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_organization_id_sender_party_id_fkey FOREIGN KEY (organization_id, sender_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: message message_organization_id_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_organization_id_template_id_fkey FOREIGN KEY (organization_id, template_id) REFERENCES public.message_template(organization_id, id);


--
-- Name: message_template message_template_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_template
    ADD CONSTRAINT message_template_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: message_template message_template_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_template
    ADD CONSTRAINT message_template_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: money_account money_account_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.money_account
    ADD CONSTRAINT money_account_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: money_account money_account_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.money_account
    ADD CONSTRAINT money_account_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: notification notification_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: notification notification_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: notification notification_organization_id_target_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_organization_id_target_role_id_fkey FOREIGN KEY (organization_id, target_role_id) REFERENCES public.role(organization_id, id);


--
-- Name: notification notification_organization_id_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_organization_id_target_user_id_fkey FOREIGN KEY (organization_id, target_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: outbox_event outbox_event_organization_id_domain_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.outbox_event
    ADD CONSTRAINT outbox_event_organization_id_domain_event_id_fkey FOREIGN KEY (organization_id, domain_event_id) REFERENCES public.domain_event(organization_id, id);


--
-- Name: outbox_event outbox_event_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.outbox_event
    ADD CONSTRAINT outbox_event_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: package_component package_component_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package_component
    ADD CONSTRAINT package_component_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: package_component package_component_organization_id_package_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package_component
    ADD CONSTRAINT package_component_organization_id_package_id_fkey FOREIGN KEY (organization_id, package_id) REFERENCES public.package(organization_id, id);


--
-- Name: package_component package_component_organization_id_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package_component
    ADD CONSTRAINT package_component_organization_id_service_id_fkey FOREIGN KEY (organization_id, service_id) REFERENCES public.service(organization_id, id);


--
-- Name: package_component package_component_organization_id_unit_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package_component
    ADD CONSTRAINT package_component_organization_id_unit_type_id_fkey FOREIGN KEY (organization_id, unit_type_id) REFERENCES public.unit_type(organization_id, id);


--
-- Name: package package_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package
    ADD CONSTRAINT package_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: package package_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package
    ADD CONSTRAINT package_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: party party_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party
    ADD CONSTRAINT party_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: payment_allocation payment_allocation_organization_id_charge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocation
    ADD CONSTRAINT payment_allocation_organization_id_charge_id_fkey FOREIGN KEY (organization_id, charge_id) REFERENCES public.charge(organization_id, id);


--
-- Name: payment_allocation payment_allocation_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocation
    ADD CONSTRAINT payment_allocation_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: payment_allocation payment_allocation_organization_id_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_allocation
    ADD CONSTRAINT payment_allocation_organization_id_payment_id_fkey FOREIGN KEY (organization_id, payment_id) REFERENCES public.payment(organization_id, id);


--
-- Name: payment payment_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: payment payment_organization_id_folio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_organization_id_folio_id_fkey FOREIGN KEY (organization_id, folio_id) REFERENCES public.folio(organization_id, id);


--
-- Name: payment payment_organization_id_payer_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_organization_id_payer_party_id_fkey FOREIGN KEY (organization_id, payer_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: pricing_rule pricing_rule_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_rule
    ADD CONSTRAINT pricing_rule_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: pricing_rule pricing_rule_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_rule
    ADD CONSTRAINT pricing_rule_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: pricing_suggestion pricing_suggestion_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_suggestion
    ADD CONSTRAINT pricing_suggestion_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: pricing_suggestion pricing_suggestion_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_suggestion
    ADD CONSTRAINT pricing_suggestion_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: pricing_suggestion pricing_suggestion_organization_id_unit_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_suggestion
    ADD CONSTRAINT pricing_suggestion_organization_id_unit_type_id_fkey FOREIGN KEY (organization_id, unit_type_id) REFERENCES public.unit_type(organization_id, id);


--
-- Name: property property_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property
    ADD CONSTRAINT property_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: property_stay_policy property_stay_policy_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_stay_policy
    ADD CONSTRAINT property_stay_policy_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: property_stay_policy property_stay_policy_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_stay_policy
    ADD CONSTRAINT property_stay_policy_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: rate rate_organization_id_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate
    ADD CONSTRAINT rate_organization_id_channel_id_fkey FOREIGN KEY (organization_id, channel_id) REFERENCES public.channel(organization_id, id);


--
-- Name: rate rate_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate
    ADD CONSTRAINT rate_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: rate rate_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate
    ADD CONSTRAINT rate_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: rate rate_organization_id_rate_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate
    ADD CONSTRAINT rate_organization_id_rate_plan_id_fkey FOREIGN KEY (organization_id, rate_plan_id) REFERENCES public.rate_plan(organization_id, id);


--
-- Name: rate rate_organization_id_unit_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate
    ADD CONSTRAINT rate_organization_id_unit_type_id_fkey FOREIGN KEY (organization_id, unit_type_id) REFERENCES public.unit_type(organization_id, id);


--
-- Name: rate_plan rate_plan_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_plan
    ADD CONSTRAINT rate_plan_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: rate_plan rate_plan_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_plan
    ADD CONSTRAINT rate_plan_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: rate_snapshot rate_snapshot_organization_id_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_snapshot
    ADD CONSTRAINT rate_snapshot_organization_id_channel_id_fkey FOREIGN KEY (organization_id, channel_id) REFERENCES public.channel(organization_id, id);


--
-- Name: rate_snapshot rate_snapshot_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_snapshot
    ADD CONSTRAINT rate_snapshot_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: rate_snapshot rate_snapshot_organization_id_rate_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_snapshot
    ADD CONSTRAINT rate_snapshot_organization_id_rate_plan_id_fkey FOREIGN KEY (organization_id, rate_plan_id) REFERENCES public.rate_plan(organization_id, id);


--
-- Name: rate_snapshot rate_snapshot_organization_id_reservation_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_snapshot
    ADD CONSTRAINT rate_snapshot_organization_id_reservation_item_id_fkey FOREIGN KEY (organization_id, reservation_item_id) REFERENCES public.reservation_item(organization_id, id);


--
-- Name: recommendation recommendation_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recommendation
    ADD CONSTRAINT recommendation_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: recommendation recommendation_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recommendation
    ADD CONSTRAINT recommendation_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: reconciliation_link reconciliation_link_organization_id_cash_movement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_organization_id_cash_movement_id_fkey FOREIGN KEY (organization_id, cash_movement_id) REFERENCES public.cash_movement(organization_id, id);


--
-- Name: reconciliation_link reconciliation_link_organization_id_economic_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_organization_id_economic_event_id_fkey FOREIGN KEY (organization_id, economic_event_id) REFERENCES public.economic_event(organization_id, id);


--
-- Name: reconciliation_link reconciliation_link_organization_id_financial_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_organization_id_financial_document_id_fkey FOREIGN KEY (organization_id, financial_document_id) REFERENCES public.financial_document(organization_id, id);


--
-- Name: reconciliation_link reconciliation_link_organization_id_financial_document_lin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_organization_id_financial_document_lin_fkey FOREIGN KEY (organization_id, financial_document_line_id) REFERENCES public.financial_document_line(organization_id, id);


--
-- Name: reconciliation_link reconciliation_link_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: reconciliation_link reconciliation_link_organization_id_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_organization_id_payment_id_fkey FOREIGN KEY (organization_id, payment_id) REFERENCES public.payment(organization_id, id);


--
-- Name: reconciliation_link reconciliation_link_organization_id_refund_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_organization_id_refund_id_fkey FOREIGN KEY (organization_id, refund_id) REFERENCES public.refund(organization_id, id);


--
-- Name: reconciliation_link reconciliation_link_organization_id_settlement_application_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_link
    ADD CONSTRAINT reconciliation_link_organization_id_settlement_application_fkey FOREIGN KEY (organization_id, settlement_application_id) REFERENCES public.settlement_application(organization_id, id);


--
-- Name: refund refund_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refund
    ADD CONSTRAINT refund_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: refund refund_organization_id_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refund
    ADD CONSTRAINT refund_organization_id_payment_id_fkey FOREIGN KEY (organization_id, payment_id) REFERENCES public.payment(organization_id, id);


--
-- Name: reorder_rule reorder_rule_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_rule
    ADD CONSTRAINT reorder_rule_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: reorder_rule reorder_rule_organization_id_inventory_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_rule
    ADD CONSTRAINT reorder_rule_organization_id_inventory_item_id_fkey FOREIGN KEY (organization_id, inventory_item_id) REFERENCES public.inventory_item(organization_id, id);


--
-- Name: reorder_rule reorder_rule_organization_id_inventory_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_rule
    ADD CONSTRAINT reorder_rule_organization_id_inventory_location_id_fkey FOREIGN KEY (organization_id, inventory_location_id) REFERENCES public.inventory_location(organization_id, id);


--
-- Name: reservation_item reservation_item_organization_id_assigned_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_item
    ADD CONSTRAINT reservation_item_organization_id_assigned_unit_id_fkey FOREIGN KEY (organization_id, assigned_unit_id) REFERENCES public.unit(organization_id, id);


--
-- Name: reservation_item reservation_item_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_item
    ADD CONSTRAINT reservation_item_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: reservation_item reservation_item_organization_id_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_item
    ADD CONSTRAINT reservation_item_organization_id_reservation_id_fkey FOREIGN KEY (organization_id, reservation_id) REFERENCES public.reservation(organization_id, id);


--
-- Name: reservation_item reservation_item_organization_id_unit_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_item
    ADD CONSTRAINT reservation_item_organization_id_unit_type_id_fkey FOREIGN KEY (organization_id, unit_type_id) REFERENCES public.unit_type(organization_id, id);


--
-- Name: reservation reservation_organization_id_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_organization_id_channel_id_fkey FOREIGN KEY (organization_id, channel_id) REFERENCES public.channel(organization_id, id);


--
-- Name: reservation reservation_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: reservation reservation_organization_id_primary_guest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_organization_id_primary_guest_id_fkey FOREIGN KEY (organization_id, primary_guest_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: reservation reservation_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: resource resource_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: resource resource_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: resource resource_organization_id_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_organization_id_zone_id_fkey FOREIGN KEY (organization_id, zone_id) REFERENCES public.zone(organization_id, id);


--
-- Name: resource_reservation resource_reservation_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_reservation
    ADD CONSTRAINT resource_reservation_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: resource_reservation resource_reservation_organization_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_reservation
    ADD CONSTRAINT resource_reservation_organization_id_resource_id_fkey FOREIGN KEY (organization_id, resource_id) REFERENCES public.resource(organization_id, id);


--
-- Name: resource_reservation resource_reservation_organization_id_service_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_reservation
    ADD CONSTRAINT resource_reservation_organization_id_service_booking_id_fkey FOREIGN KEY (organization_id, service_booking_id) REFERENCES public.service_booking(organization_id, id);


--
-- Name: role_assignment role_assignment_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignment
    ADD CONSTRAINT role_assignment_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: role_assignment role_assignment_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignment
    ADD CONSTRAINT role_assignment_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: role_assignment role_assignment_organization_id_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignment
    ADD CONSTRAINT role_assignment_organization_id_role_id_fkey FOREIGN KEY (organization_id, role_id) REFERENCES public.role(organization_id, id);


--
-- Name: role_assignment role_assignment_organization_id_user_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignment
    ADD CONSTRAINT role_assignment_organization_id_user_account_id_fkey FOREIGN KEY (organization_id, user_account_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: role role_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: role_permission role_permission_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permission
    ADD CONSTRAINT role_permission_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: role_permission role_permission_organization_id_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permission
    ADD CONSTRAINT role_permission_organization_id_role_id_fkey FOREIGN KEY (organization_id, role_id) REFERENCES public.role(organization_id, id);


--
-- Name: role_permission role_permission_permission_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permission
    ADD CONSTRAINT role_permission_permission_code_fkey FOREIGN KEY (permission_code) REFERENCES public.permission(code);


--
-- Name: service_booking service_booking_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_booking
    ADD CONSTRAINT service_booking_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: service_booking service_booking_organization_id_guest_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_booking
    ADD CONSTRAINT service_booking_organization_id_guest_profile_id_fkey FOREIGN KEY (organization_id, guest_profile_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: service_booking service_booking_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_booking
    ADD CONSTRAINT service_booking_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: service_booking service_booking_organization_id_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_booking
    ADD CONSTRAINT service_booking_organization_id_reservation_id_fkey FOREIGN KEY (organization_id, reservation_id) REFERENCES public.reservation(organization_id, id);


--
-- Name: service_booking service_booking_organization_id_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_booking
    ADD CONSTRAINT service_booking_organization_id_service_id_fkey FOREIGN KEY (organization_id, service_id) REFERENCES public.service(organization_id, id);


--
-- Name: service_booking service_booking_organization_id_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_booking
    ADD CONSTRAINT service_booking_organization_id_stay_id_fkey FOREIGN KEY (organization_id, stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: service_execution service_execution_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_execution
    ADD CONSTRAINT service_execution_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: service_execution service_execution_organization_id_service_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_execution
    ADD CONSTRAINT service_execution_organization_id_service_booking_id_fkey FOREIGN KEY (organization_id, service_booking_id) REFERENCES public.service_booking(organization_id, id);


--
-- Name: service service_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: service service_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service
    ADD CONSTRAINT service_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: settlement_application settlement_application_organization_id_cash_movement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_application
    ADD CONSTRAINT settlement_application_organization_id_cash_movement_id_fkey FOREIGN KEY (organization_id, cash_movement_id) REFERENCES public.cash_movement(organization_id, id);


--
-- Name: settlement_application settlement_application_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_application
    ADD CONSTRAINT settlement_application_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: settlement_application settlement_application_organization_id_settlement_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_application
    ADD CONSTRAINT settlement_application_organization_id_settlement_entry_id_fkey FOREIGN KEY (organization_id, settlement_entry_id) REFERENCES public.settlement_entry(organization_id, id);


--
-- Name: settlement_entry settlement_entry_organization_id_creditor_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_entry
    ADD CONSTRAINT settlement_entry_organization_id_creditor_party_id_fkey FOREIGN KEY (organization_id, creditor_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: settlement_entry settlement_entry_organization_id_debtor_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_entry
    ADD CONSTRAINT settlement_entry_organization_id_debtor_party_id_fkey FOREIGN KEY (organization_id, debtor_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: settlement_entry settlement_entry_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_entry
    ADD CONSTRAINT settlement_entry_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: settlement_entry settlement_entry_organization_id_source_allocation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_entry
    ADD CONSTRAINT settlement_entry_organization_id_source_allocation_id_fkey FOREIGN KEY (organization_id, source_allocation_id) REFERENCES public.allocation(organization_id, id);


--
-- Name: settlement_entry settlement_entry_organization_id_source_economic_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_entry
    ADD CONSTRAINT settlement_entry_organization_id_source_economic_event_id_fkey FOREIGN KEY (organization_id, source_economic_event_id) REFERENCES public.economic_event(organization_id, id);


--
-- Name: stay_guest stay_guest_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_guest
    ADD CONSTRAINT stay_guest_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: stay_guest stay_guest_organization_id_guest_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_guest
    ADD CONSTRAINT stay_guest_organization_id_guest_profile_id_fkey FOREIGN KEY (organization_id, guest_profile_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: stay_guest stay_guest_organization_id_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_guest
    ADD CONSTRAINT stay_guest_organization_id_stay_id_fkey FOREIGN KEY (organization_id, stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: stay stay_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay
    ADD CONSTRAINT stay_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: stay stay_organization_id_primary_guest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay
    ADD CONSTRAINT stay_organization_id_primary_guest_id_fkey FOREIGN KEY (organization_id, primary_guest_id) REFERENCES public.guest_profile(organization_id, id);


--
-- Name: stay stay_organization_id_reservation_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay
    ADD CONSTRAINT stay_organization_id_reservation_item_id_fkey FOREIGN KEY (organization_id, reservation_item_id) REFERENCES public.reservation_item(organization_id, id);


--
-- Name: stay_segment stay_segment_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_segment
    ADD CONSTRAINT stay_segment_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: stay_segment stay_segment_organization_id_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_segment
    ADD CONSTRAINT stay_segment_organization_id_stay_id_fkey FOREIGN KEY (organization_id, stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: stay_segment stay_segment_organization_id_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stay_segment
    ADD CONSTRAINT stay_segment_organization_id_unit_id_fkey FOREIGN KEY (organization_id, unit_id) REFERENCES public.unit(organization_id, id);


--
-- Name: stock_movement stock_movement_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: stock_movement stock_movement_organization_id_from_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_organization_id_from_location_id_fkey FOREIGN KEY (organization_id, from_location_id) REFERENCES public.inventory_location(organization_id, id);


--
-- Name: stock_movement stock_movement_organization_id_inventory_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_organization_id_inventory_item_id_fkey FOREIGN KEY (organization_id, inventory_item_id) REFERENCES public.inventory_item(organization_id, id);


--
-- Name: stock_movement stock_movement_organization_id_reverses_movement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_organization_id_reverses_movement_id_fkey FOREIGN KEY (organization_id, reverses_movement_id) REFERENCES public.stock_movement(organization_id, id);


--
-- Name: stock_movement stock_movement_organization_id_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_organization_id_stay_id_fkey FOREIGN KEY (organization_id, stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: stock_movement stock_movement_organization_id_to_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_organization_id_to_location_id_fkey FOREIGN KEY (organization_id, to_location_id) REFERENCES public.inventory_location(organization_id, id);


--
-- Name: stock_movement stock_movement_organization_id_turnover_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_organization_id_turnover_id_fkey FOREIGN KEY (organization_id, turnover_id) REFERENCES public.turnover(organization_id, id);


--
-- Name: task task_organization_id_assignee_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_organization_id_assignee_user_id_fkey FOREIGN KEY (organization_id, assignee_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: task task_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: task task_organization_id_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_organization_id_incident_id_fkey FOREIGN KEY (organization_id, incident_id) REFERENCES public.incident(organization_id, id);


--
-- Name: task task_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: task task_organization_id_turnover_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_organization_id_turnover_id_fkey FOREIGN KEY (organization_id, turnover_id) REFERENCES public.turnover(organization_id, id);


--
-- Name: task_template task_template_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_template
    ADD CONSTRAINT task_template_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: task_template task_template_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_template
    ADD CONSTRAINT task_template_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: turnover turnover_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turnover
    ADD CONSTRAINT turnover_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: turnover turnover_organization_id_next_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turnover
    ADD CONSTRAINT turnover_organization_id_next_stay_id_fkey FOREIGN KEY (organization_id, next_stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: turnover turnover_organization_id_previous_stay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turnover
    ADD CONSTRAINT turnover_organization_id_previous_stay_id_fkey FOREIGN KEY (organization_id, previous_stay_id) REFERENCES public.stay(organization_id, id);


--
-- Name: turnover turnover_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turnover
    ADD CONSTRAINT turnover_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: turnover turnover_organization_id_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turnover
    ADD CONSTRAINT turnover_organization_id_unit_id_fkey FOREIGN KEY (organization_id, unit_id) REFERENCES public.unit(organization_id, id);


--
-- Name: unit unit_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: unit unit_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: unit unit_organization_id_unit_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_organization_id_unit_type_id_fkey FOREIGN KEY (organization_id, unit_type_id) REFERENCES public.unit_type(organization_id, id);


--
-- Name: unit unit_organization_id_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_organization_id_zone_id_fkey FOREIGN KEY (organization_id, zone_id) REFERENCES public.zone(organization_id, id);


--
-- Name: unit_type unit_type_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_type
    ADD CONSTRAINT unit_type_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: unit_type unit_type_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_type
    ADD CONSTRAINT unit_type_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: user_account user_account_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: user_account user_account_organization_id_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_organization_id_party_id_fkey FOREIGN KEY (organization_id, party_id) REFERENCES public.party(organization_id, id);


--
-- Name: work_log work_log_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_log
    ADD CONSTRAINT work_log_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: work_log work_log_organization_id_performed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_log
    ADD CONSTRAINT work_log_organization_id_performed_by_user_id_fkey FOREIGN KEY (organization_id, performed_by_user_id) REFERENCES public.user_account(organization_id, id);


--
-- Name: work_log work_log_organization_id_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_log
    ADD CONSTRAINT work_log_organization_id_task_id_fkey FOREIGN KEY (organization_id, task_id) REFERENCES public.task(organization_id, id);


--
-- Name: work_order work_order_organization_id_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_organization_id_asset_id_fkey FOREIGN KEY (organization_id, asset_id) REFERENCES public.asset(organization_id, id);


--
-- Name: work_order work_order_organization_id_contractor_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_organization_id_contractor_party_id_fkey FOREIGN KEY (organization_id, contractor_party_id) REFERENCES public.party(organization_id, id);


--
-- Name: work_order work_order_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: work_order work_order_organization_id_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_organization_id_incident_id_fkey FOREIGN KEY (organization_id, incident_id) REFERENCES public.incident(organization_id, id);


--
-- Name: work_order work_order_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- Name: zone zone_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone
    ADD CONSTRAINT zone_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organization(id);


--
-- Name: zone zone_organization_id_parent_zone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone
    ADD CONSTRAINT zone_organization_id_parent_zone_id_fkey FOREIGN KEY (organization_id, parent_zone_id) REFERENCES public.zone(organization_id, id);


--
-- Name: zone zone_organization_id_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone
    ADD CONSTRAINT zone_organization_id_property_id_fkey FOREIGN KEY (organization_id, property_id) REFERENCES public.property(organization_id, id);


--
-- PostgreSQL database dump complete
--


