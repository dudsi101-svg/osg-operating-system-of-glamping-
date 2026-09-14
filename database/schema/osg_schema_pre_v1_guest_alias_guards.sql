-- OSG pre-v1 Guest alias integrity guards
-- PRE-FREEZE / DEV candidate.

create or replace function osg_guard_guest_profile_alias()
returns trigger language plpgsql as $$
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

create trigger trg_guest_profile_alias_integrity
before insert or update on guest_profile_alias
for each row execute function osg_guard_guest_profile_alias();

-- Merge workflow should lock both GuestProfiles in UUID order and resolve any
-- existing active alias before creating a new canonical mapping.
