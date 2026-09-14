-- OSG pre-v1 reporting currency guard
-- PRE-FREEZE / DEV candidate.

create or replace function osg_guard_economic_event_reporting_currency()
returns trigger language plpgsql as $$
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

create trigger trg_economic_event_reporting_currency
before insert or update on economic_event
for each row execute function osg_guard_economic_event_reporting_currency();

-- Source FinancialDocument/CashMovement/Payment currencies may differ.
-- Conversion evidence/policy must exist before creating/posting Property economic truth.
