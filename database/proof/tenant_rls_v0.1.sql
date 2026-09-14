-- OSG tenant RLS proof v0.1
-- DEV PROOF ONLY. RLS is defense-in-depth, not a replacement for composite FKs.

create or replace function osg_current_organization_id()
returns uuid language sql stable as $$
  select nullif(current_setting('app.organization_id', true), '')::uuid;
$$;

-- Critical tables selected for proof. Final migration should generate/apply
-- equivalent policies to all tenant-owned tables.

alter table property enable row level security;
alter table reservation enable row level security;
alter table reservation_item enable row level security;
alter table stay enable row level security;
alter table stay_segment enable row level security;
alter table economic_event enable row level security;
alter table allocation enable row level security;
alter table cash_movement enable row level security;
alter table settlement_entry enable row level security;

create policy property_tenant_isolation on property
  using (organization_id = osg_current_organization_id())
  with check (organization_id = osg_current_organization_id());

create policy reservation_tenant_isolation on reservation
  using (organization_id = osg_current_organization_id())
  with check (organization_id = osg_current_organization_id());

create policy reservation_item_tenant_isolation on reservation_item
  using (organization_id = osg_current_organization_id())
  with check (organization_id = osg_current_organization_id());

create policy stay_tenant_isolation on stay
  using (organization_id = osg_current_organization_id())
  with check (organization_id = osg_current_organization_id());

create policy stay_segment_tenant_isolation on stay_segment
  using (organization_id = osg_current_organization_id())
  with check (organization_id = osg_current_organization_id());

create policy economic_event_tenant_isolation on economic_event
  using (organization_id = osg_current_organization_id())
  with check (organization_id = osg_current_organization_id());

create policy allocation_tenant_isolation on allocation
  using (organization_id = osg_current_organization_id())
  with check (organization_id = osg_current_organization_id());

create policy cash_movement_tenant_isolation on cash_movement
  using (organization_id = osg_current_organization_id())
  with check (organization_id = osg_current_organization_id());

create policy settlement_entry_tenant_isolation on settlement_entry
  using (organization_id = osg_current_organization_id())
  with check (organization_id = osg_current_organization_id());

-- TEST PLAN
-- SET LOCAL app.organization_id = '<ORG_A UUID>';
-- SELECT/INSERT ORG_A rows => allowed.
-- SELECT ORG_B rows => invisible.
-- INSERT/UPDATE ORG_B organization_id => rejected by WITH CHECK.
-- Repeat from application role, not table owner/superuser (RLS bypass concern).
--
-- SECURITY NOTE
-- Table owners normally bypass RLS unless FORCE ROW LEVEL SECURITY is used.
-- Production runtime role must not be table owner. Evaluate FORCE RLS after
-- migration/service-role design is finalized.
