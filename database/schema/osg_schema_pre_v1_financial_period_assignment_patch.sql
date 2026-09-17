-- OSG pre-v1 FinancialPeriod assignment/integrity patch
-- PRE-FREEZE / DEV candidate.

-- ---------------------------------------------------------------
-- Period ranges may not overlap within the same scope.
-- daterange uses [start, end+1) to represent inclusive period_end.
-- ---------------------------------------------------------------
alter table financial_period
  add constraint ex_property_financial_period_no_overlap
  exclude using gist (
    organization_id with =,
    property_id with =,
    daterange(period_start, period_end + 1, '[)') with &&
  ) where (property_id is not null);

alter table financial_period
  add constraint ex_org_financial_period_no_overlap
  exclude using gist (
    organization_id with =,
    daterange(period_start, period_end + 1, '[)') with &&
  ) where (property_id is null);

-- ---------------------------------------------------------------
-- Resolve exactly one matching period.
-- ---------------------------------------------------------------
create or replace function osg_resolve_financial_period(
  p_organization_id uuid,
  p_property_id uuid,
  p_economic_date date
)
returns uuid language plpgsql stable as $$
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

-- ---------------------------------------------------------------
-- Validate/assign period when event becomes REVIEWED or POSTED.
-- ---------------------------------------------------------------
create or replace function osg_guard_economic_event_period_assignment()
returns trigger language plpgsql as $$
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

create trigger trg_economic_event_period_assignment
before insert or update on economic_event
for each row execute function osg_guard_economic_event_period_assignment();

-- Posting application workflow should still call explicit period/open checks
-- inside its transaction; this trigger is the fail-closed database layer.
