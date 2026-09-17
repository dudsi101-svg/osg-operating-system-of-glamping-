-- OSG Schema v1 — production tenant RLS rollout
-- Issue #17. Production migration, not a selective proof policy.
--
-- Threat model:
-- * Organization is the tenant boundary.
-- * Runtime roles are NOLOGIN group roles, NOSUPERUSER and NOBYPASSRLS.
-- * The trusted application/service sets transaction-scoped `osg.organization_id`.
-- * Missing tenant context fails closed (no tenant rows visible; writes rejected).
-- * RLS is defense-in-depth and does not replace composite FKs/property guards.
-- * `osg_maintenance` is an explicit privileged DBA/service path and is never
--   granted to normal runtime roles.
-- * Arbitrary SQL execution as a runtime DB identity is outside this boundary:
--   PostgreSQL custom GUCs are not independently privilege-protected.
--
-- All runtime-facing ordinary views use security_invoker=true so view-owner
-- privileges cannot silently bypass caller RLS.

-- ---------------------------------------------------------------------------
-- Production database group roles
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname='osg_app_runtime') then
    create role osg_app_runtime nologin nosuperuser nocreatedb nocreaterole
      noinherit noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname='osg_worker_runtime') then
    create role osg_worker_runtime nologin nosuperuser nocreatedb nocreaterole
      noinherit noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname='osg_reporting_runtime') then
    create role osg_reporting_runtime nologin nosuperuser nocreatedb nocreaterole
      noinherit noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname='osg_maintenance') then
    create role osg_maintenance nologin nosuperuser nocreatedb nocreaterole
      noinherit noreplication bypassrls;
  end if;
end $$;

-- Existing roles with these names must also satisfy the contract.
do $$
declare
  r record;
begin
  for r in
    select rolname, rolsuper, rolcreaterole, rolcreatedb, rolreplication, rolbypassrls
    from pg_roles
    where rolname in ('osg_app_runtime','osg_worker_runtime','osg_reporting_runtime')
  loop
    if r.rolsuper or r.rolcreaterole or r.rolcreatedb or r.rolreplication or r.rolbypassrls then
      raise exception 'OSG_RLS_RUNTIME_ROLE_PRIVILEGE_INVALID role=%', r.rolname;
    end if;
  end loop;

  if exists (
    select 1
    from pg_auth_members m
    join pg_roles parent on parent.oid=m.roleid
    join pg_roles member on member.oid=m.member
    where parent.rolname='osg_maintenance'
      and member.rolname in ('osg_app_runtime','osg_worker_runtime','osg_reporting_runtime')
  ) then
    raise exception 'OSG_RLS_RUNTIME_MAINTENANCE_MEMBERSHIP_FORBIDDEN';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Tenant context
-- ---------------------------------------------------------------------------
create or replace function public.osg_current_organization_id()
returns uuid
language plpgsql
stable
security invoker
set search_path = pg_catalog
as $$
declare
  v_context text;
begin
  v_context := current_setting('osg.organization_id', true);
  if v_context is null or btrim(v_context) = '' then
    return null;
  end if;

  begin
    return v_context::uuid;
  exception
    when invalid_text_representation then
      raise exception 'OSG_INVALID_TENANT_CONTEXT'
        using errcode='22023',
              detail='osg.organization_id must contain a valid UUID';
  end;
end $$;

revoke all on function public.osg_current_organization_id() from public;
grant execute on function public.osg_current_organization_id()
  to osg_app_runtime, osg_worker_runtime, osg_reporting_runtime, osg_maintenance;

-- ---------------------------------------------------------------------------
-- Fail-closed classification of every ordinary public table
-- ---------------------------------------------------------------------------
do $$
declare
  v_unclassified text;
  v_nullable_tenant_key text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into v_nullable_tenant_key
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  join pg_attribute a
    on a.attrelid=c.oid
   and a.attname='organization_id'
   and not a.attisdropped
  where n.nspname='public'
    and c.relkind in ('r','p')
    and not a.attnotnull;

  if v_nullable_tenant_key is not null then
    raise exception 'OSG_RLS_NULLABLE_TENANT_KEY tables=%', v_nullable_tenant_key;
  end if;

  select string_agg(c.relname, ', ' order by c.relname)
    into v_unclassified
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind in ('r','p')
    and c.relname not in ('organization','permission','osg_schema_migration')
    and not exists (
      select 1
      from pg_attribute a
      where a.attrelid=c.oid
        and a.attname='organization_id'
        and a.attnotnull
        and not a.attisdropped
    );

  if v_unclassified is not null then
    raise exception 'OSG_RLS_UNCLASSIFIED_TABLES tables=%', v_unclassified;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Tenant-owned tables: complete generated rollout
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relkind in ('r','p')
      and exists (
        select 1
        from pg_attribute a
        where a.attrelid=c.oid
          and a.attname='organization_id'
          and a.attnotnull
          and not a.attisdropped
      )
    order by c.relname
  loop
    execute format('revoke all privileges on table public.%I from public', r.relname);
    execute format('alter table public.%I enable row level security', r.relname);
    execute format('alter table public.%I force row level security', r.relname);
    execute format('drop policy if exists osg_tenant_scope on public.%I', r.relname);
    execute format(
      'create policy osg_tenant_scope on public.%I for all ' ||
      'using (organization_id = public.osg_current_organization_id()) ' ||
      'with check (organization_id = public.osg_current_organization_id())',
      r.relname
    );
    execute format(
      'grant select, insert, update, delete on table public.%I to osg_app_runtime, osg_worker_runtime',
      r.relname
    );
    execute format(
      'grant select on table public.%I to osg_reporting_runtime, osg_maintenance',
      r.relname
    );
    execute format(
      'grant insert, update, delete on table public.%I to osg_maintenance',
      r.relname
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Organization root: tenant scoped, runtime read-only
-- ---------------------------------------------------------------------------
revoke all privileges on table public.organization from public;
alter table public.organization enable row level security;
alter table public.organization force row level security;
drop policy if exists osg_tenant_root_scope on public.organization;
create policy osg_tenant_root_scope on public.organization
  for all
  using (id = public.osg_current_organization_id())
  with check (id = public.osg_current_organization_id());

grant select on table public.organization
  to osg_app_runtime, osg_worker_runtime, osg_reporting_runtime, osg_maintenance;
grant insert, update, delete on table public.organization to osg_maintenance;

-- ---------------------------------------------------------------------------
-- Explicit non-tenant/global + system tables
-- ---------------------------------------------------------------------------
revoke all privileges on table public.permission from public;
grant select on table public.permission
  to osg_app_runtime, osg_worker_runtime, osg_reporting_runtime, osg_maintenance;
grant insert, update, delete on table public.permission to osg_maintenance;

-- Migration ledger remains infrastructure-only. Runtime roles get no access.
revoke all privileges on table public.osg_schema_migration
  from public, osg_app_runtime, osg_worker_runtime, osg_reporting_runtime, osg_maintenance;

-- ---------------------------------------------------------------------------
-- Views must execute with caller permissions so base-table RLS is preserved.
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='v'
    order by c.relname
  loop
    execute format('alter view public.%I set (security_invoker=true)', r.relname);
    execute format('revoke all privileges on table public.%I from public', r.relname);
    execute format(
      'grant select on table public.%I to osg_app_runtime, osg_worker_runtime, osg_reporting_runtime, osg_maintenance',
      r.relname
    );
  end loop;
end $$;

-- SECURITY DEFINER functions require explicit review because they can bypass
-- caller RLS semantics. v1 fails closed if any exist in public.
do $$
declare
  v_security_definers text;
begin
  select string_agg(p.proname, ', ' order by p.proname)
    into v_security_definers
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.prosecdef;

  if v_security_definers is not null then
    raise exception 'OSG_RLS_UNREVIEWED_SECURITY_DEFINER functions=%', v_security_definers;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Machine-checkable postconditions
-- ---------------------------------------------------------------------------
do $$
declare
  v_missing text;
  v_policy_mismatch text;
  v_view_mismatch text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into v_missing
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind in ('r','p')
    and (
      c.relname='organization'
      or exists (
        select 1 from pg_attribute a
        where a.attrelid=c.oid
          and a.attname='organization_id'
          and a.attnotnull
          and not a.attisdropped
      )
    )
    and (not c.relrowsecurity or not c.relforcerowsecurity);

  if v_missing is not null then
    raise exception 'OSG_RLS_COVERAGE_MISSING_FORCE tables=%', v_missing;
  end if;

  select string_agg(c.relname, ', ' order by c.relname)
    into v_policy_mismatch
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind in ('r','p')
    and (
      (c.relname='organization' and not exists (
        select 1 from pg_policy p
        where p.polrelid=c.oid and p.polname='osg_tenant_root_scope'
      ))
      or
      (exists (
        select 1 from pg_attribute a
        where a.attrelid=c.oid
          and a.attname='organization_id'
          and a.attnotnull
          and not a.attisdropped
      ) and not exists (
        select 1 from pg_policy p
        where p.polrelid=c.oid and p.polname='osg_tenant_scope'
      ))
    );

  if v_policy_mismatch is not null then
    raise exception 'OSG_RLS_POLICY_COVERAGE_MISMATCH tables=%', v_policy_mismatch;
  end if;

  select string_agg(c.relname, ', ' order by c.relname)
    into v_view_mismatch
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind='v'
    and coalesce((c.reloptions @> array['security_invoker=true'])::boolean,false)=false;

  if v_view_mismatch is not null then
    raise exception 'OSG_RLS_VIEW_NOT_SECURITY_INVOKER views=%', v_view_mismatch;
  end if;
end $$;
