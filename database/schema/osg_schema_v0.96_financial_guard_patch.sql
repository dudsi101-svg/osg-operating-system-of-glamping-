-- OSG v0.96 financial immutability hardening patch
-- Apply after v0.95 core.
-- DEV/PRE-FREEZE candidate only.

-- The v0.95 proof trigger guarded UPDATE/DELETE of allocations attached to a
-- POSTED EconomicEvent, but an INSERT could still add a new allocation after
-- posting. This patch closes that hole and makes TG_OP handling explicit.

drop trigger if exists trg_guard_allocation_of_posted_event on allocation;

create or replace function osg_guard_allocation_of_posted_event()
returns trigger language plpgsql as $$
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

create trigger trg_guard_allocation_of_posted_event
before insert or update or delete on allocation
for each row execute function osg_guard_allocation_of_posted_event();

-- Required proof:
-- 1. allocations may be created/edited while EconomicEvent is DRAFT/REVIEWED.
-- 2. after Event becomes POSTED: INSERT/UPDATE/DELETE Allocation all reject.
-- 3. reversal/correction creates a separate event/allocation chain rather than
--    mutating the posted record.
