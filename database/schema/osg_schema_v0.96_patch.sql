-- OSG PostgreSQL pre-freeze patch v0.96
-- Applies after v0.95 core/extensions/supporting.
-- DEV candidate only. Introduced after scenario validation discovered a missing
-- explicit relation for current-period adjustments concerning prior periods.

alter table economic_event
  add column relates_to_financial_period_id uuid,
  add column adjustment_reason text;

alter table economic_event
  add foreign key (organization_id, relates_to_financial_period_id)
  references financial_period(organization_id, id);

-- Business rule:
-- * normal events may leave relates_to_financial_period_id NULL.
-- * ADJUSTMENT concerning an earlier closed period SHOULD set it.
-- * current financial_period_id is where the adjustment is recognized/posted.
-- * relates_to_financial_period_id identifies the historical period concerned.
-- This allows reports to distinguish:
--   recognized in September
--   economically/documentarily relates to August
-- without silently rewriting the HARD_CLOSED August period.

create or replace function osg_guard_closed_period_event()
returns trigger language plpgsql as $$
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

create trigger trg_guard_closed_period_event
before insert or update on economic_event
for each row execute function osg_guard_closed_period_event();

-- v0.96 is additive and exists because end-to-end validation found a real
-- semantic need. It should be folded into the v1.0 schema if executable proofs pass.
