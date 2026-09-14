-- OSG pre-v1 Financial Period hard-close guard patch
-- PRE-FREEZE / DEV candidate.

-- ---------------------------------------------------------------
-- Prevent mutation/deletion of EconomicEvent recognized in HARD_CLOSED period.
-- ---------------------------------------------------------------
create or replace function osg_guard_hard_closed_existing_event()
returns trigger language plpgsql as $$
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

create trigger trg_guard_hard_closed_existing_event
before update or delete on economic_event
for each row execute function osg_guard_hard_closed_existing_event();

-- ---------------------------------------------------------------
-- FinancialPeriod state transition guard.
-- Controlled reopen requires transaction-local session flag set only by the
-- reviewed privileged domain workflow.
-- ---------------------------------------------------------------
create or replace function osg_guard_financial_period_transition()
returns trigger language plpgsql as $$
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

create trigger trg_guard_financial_period_transition
before update on financial_period
for each row execute function osg_guard_financial_period_transition();

-- ---------------------------------------------------------------
-- New events cannot be REVIEWED/POSTED directly into HARD_CLOSED period.
-- Existing v0.96 guard remains valid; keep this explicit check for clean v1 fold.
-- ---------------------------------------------------------------
create or replace function osg_assert_target_period_open_for_post(p_event_id uuid)
returns void language plpgsql as $$
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

-- Controlled reopen workflow must additionally write Approval/Audit/DomainEvent;
-- the DB session flag is a guard, not sufficient business authorization by itself.
