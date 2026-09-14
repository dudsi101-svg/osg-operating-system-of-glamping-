-- OSG pre-v1 Charge correction/reversal guards
-- PRE-FREEZE / DEV candidate.

-- Remove ambiguous original REVERSED state.
alter table charge
  drop constraint if exists charge_status_check;

alter table charge
  add constraint charge_status_check
  check (status in ('PENDING','POSTED','RECOGNIZED'));

-- Posted/recognized material commercial facts are immutable.
create or replace function osg_guard_final_charge_immutability()
returns trigger language plpgsql as $$
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

create trigger trg_guard_final_charge_immutability
before update on charge
for each row execute function osg_guard_final_charge_immutability();

-- Reversing Charge validation and conservation.
create or replace function osg_guard_charge_reversal()
returns trigger language plpgsql as $$
declare
  v_original_folio uuid;
  v_original_amount numeric(14,2);
  v_existing_reversal numeric(14,2);
begin
  if new.reverses_charge_id is null then
    return new;
  end if;

  select folio_id,gross_amount
    into v_original_folio,v_original_amount
  from charge
  where organization_id=new.organization_id
    and id=new.reverses_charge_id
  for share;

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

create trigger trg_guard_charge_reversal
before insert or update on charge
for each row execute function osg_guard_charge_reversal();

-- DELETE of POSTED/RECOGNIZED charge should be denied by permissions/repository layer;
-- add DB fail-closed trigger as defense-in-depth.
create or replace function osg_guard_final_charge_delete()
returns trigger language plpgsql as $$
begin
  if old.status in ('POSTED','RECOGNIZED') then
    raise exception 'OSG_FINAL_CHARGE_IMMUTABLE';
  end if;
  return old;
end $$;

create trigger trg_guard_final_charge_delete
before delete on charge
for each row execute function osg_guard_final_charge_delete();
