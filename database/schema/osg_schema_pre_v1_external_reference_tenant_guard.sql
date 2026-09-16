-- OSG pre-v1 ExternalReference target tenant guard
-- PRE-FREEZE / DEV candidate.
--
-- ExternalReference is intentionally polymorphic and therefore cannot use a
-- conventional FK to every possible target table. The integration itself is
-- already tenant-bound through (organization_id,integration_id). This trigger
-- closes the other side of the relation: osg_entity_id must resolve to an OSG
-- entity owned by the same Organization.
--
-- Security properties:
-- - explicit allow-list; no arbitrary dynamic table names,
-- - unsupported entity types fail closed,
-- - missing target fails closed,
-- - cross-Organization target fails with a stable domain error.

create or replace function osg_guard_external_reference_target_tenant()
returns trigger
language plpgsql
as $$
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

create trigger trg_external_reference_target_tenant
before insert or update of organization_id,osg_entity_type,osg_entity_id
on external_reference
for each row execute function osg_guard_external_reference_target_tenant();

-- Stable application/domain error mappings:
-- OSG_EXTERNAL_REFERENCE_TENANT_MISMATCH
-- OSG_EXTERNAL_REFERENCE_TARGET_NOT_FOUND
-- OSG_EXTERNAL_REFERENCE_UNSUPPORTED_ENTITY_TYPE
