-- OSG pre-v1 Folio guards
-- PRE-FREEZE / DEV candidate.
-- Requires semantic folio balance view for close validation.

-- ---------------------------------------------------------------
-- Payment currency must equal Folio currency in Release 1.
-- ---------------------------------------------------------------
create or replace function osg_guard_payment_folio_currency()
returns trigger language plpgsql as $$
declare
  v_folio_currency char(3);
begin
  select currency into v_folio_currency
  from folio
  where organization_id=new.organization_id and id=new.folio_id;

  if not found then
    raise exception 'OSG_FOLIO_NOT_FOUND';
  end if;

  if new.currency <> v_folio_currency then
    raise exception 'OSG_FOLIO_CURRENCY_MISMATCH expected=% actual=%',v_folio_currency,new.currency;
  end if;

  return new;
end $$;

create trigger trg_payment_folio_currency
before insert or update on payment
for each row execute function osg_guard_payment_folio_currency();

-- ---------------------------------------------------------------
-- Refund currency must equal original Payment currency.
-- Refund total cannot exceed Payment amount.
-- ---------------------------------------------------------------
create or replace function osg_guard_refund_payment_currency_and_amount()
returns trigger language plpgsql as $$
declare
  v_payment_currency char(3);
  v_payment_amount numeric(14,2);
  v_other_refunds numeric(14,2);
begin
  select currency,amount into v_payment_currency,v_payment_amount
  from payment
  where organization_id=new.organization_id and id=new.payment_id
  for update;

  if not found then
    raise exception 'OSG_PAYMENT_NOT_FOUND';
  end if;

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

create trigger trg_refund_payment_currency_and_amount
before insert or update on refund
for each row execute function osg_guard_refund_payment_currency_and_amount();

-- ---------------------------------------------------------------
-- Charge/Folio currency is implicit in Charge schema (no separate currency).
-- Close guard resolves canonical commercial balance.
-- ---------------------------------------------------------------
create or replace function osg_guard_folio_close_balance()
returns trigger language plpgsql as $$
declare
  v_balance numeric;
begin
  if old.status <> 'CLOSED' and new.status='CLOSED' then
    select balance_due into v_balance
    from osg_folio_balance
    where organization_id=new.organization_id and folio_id=new.id;

    if v_balance is null then
      raise exception 'OSG_FOLIO_BALANCE_UNAVAILABLE';
    end if;

    if abs(v_balance) > 0.01 then
      raise exception 'OSG_FOLIO_BALANCE_NOT_ZERO balance=%',v_balance;
    end if;

    if new.closed_at is null then
      new.closed_at := now();
    end if;
  end if;

  -- Reopening a CLOSED Folio must occur through explicit privileged/domain workflow.
  if old.status='CLOSED' and new.status='OPEN' then
    if coalesce(current_setting('osg.controlled_folio_reopen',true),'off') <> 'on' then
      raise exception 'OSG_CONTROLLED_FOLIO_REOPEN_REQUIRED';
    end if;
    new.closed_at := null;
  end if;

  return new;
end $$;

create trigger trg_folio_close_balance
before update on folio
for each row execute function osg_guard_folio_close_balance();

-- A close command should lock Folio before changing status and create a DomainEvent/Outbox record.
-- The DB trigger is fail-closed protection, not the full application workflow.
