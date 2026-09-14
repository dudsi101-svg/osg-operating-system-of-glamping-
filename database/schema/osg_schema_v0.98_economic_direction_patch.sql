-- OSG v0.98 Economic direction patch
-- PRE-FREEZE / DEV candidate.
-- Solves partial/current-period reversals without misclassifying cost reductions as revenue.

alter table economic_event
  add column effect_direction text not null default 'NORMAL'
    check (effect_direction in ('NORMAL','REVERSAL'));

comment on column economic_event.effect_direction is
  'NORMAL applies the natural effect of Allocation.classification; REVERSAL applies the opposite effect while preserving the original economic category.';

-- Semantics by Allocation.classification:
-- REVENUE + NORMAL   => increases operating result
-- REVENUE + REVERSAL => decreases operating result
-- OPEX + NORMAL      => decreases operating result
-- OPEX + REVERSAL    => increases operating result
-- CAPEX + NORMAL     => increases invested-capital view
-- CAPEX + REVERSAL   => reduces invested-capital view
-- NON_BUSINESS       => excluded from property economic operating result either way

-- reverses_event_id can reference the source fact for traceability.
-- A reversal may be full or partial; amount and allocations describe the reversal magnitude.
-- A HARD_CLOSED original period remains immutable: create a current-period ADJUSTMENT
-- with effect_direction='REVERSAL' and a reference to the original fact.

-- Strengthen immutability: direction is economically critical after POSTED.
create or replace function osg_guard_posted_economic_event_v098()
returns trigger language plpgsql as $$
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

drop trigger if exists trg_guard_posted_economic_event on economic_event;
create trigger trg_guard_posted_economic_event
before update on economic_event
for each row execute function osg_guard_posted_economic_event_v098();
