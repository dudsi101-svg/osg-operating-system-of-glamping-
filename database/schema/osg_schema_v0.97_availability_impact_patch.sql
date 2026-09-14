-- OSG v0.97 Availability impact semantics patch
-- PRE-FREEZE / DEV candidate.
-- Adds explicit business meaning required by occupancy/sellable-capacity metrics.

alter table availability_block
  add column sellability_impact boolean not null default true,
  add column operations_impact boolean not null default true,
  add column guest_impact boolean not null default false;

comment on column availability_block.sellability_impact is
  'If true, overlapping operational unit-night/resource window is unavailable for sale/capacity metrics.';

comment on column availability_block.operations_impact is
  'If true, block should surface in operations/maintenance workflows even when sale may remain possible.';

comment on column availability_block.guest_impact is
  'If true, current/expected guest experience is materially affected and conflict/escalation workflow should evaluate impact.';

-- Examples:
-- MAINTENANCE on Unit: sellability=true, operations=true
-- OWNER_USE on Unit: sellability=true, operations=false
-- COSMETIC_ISSUE: sellability=false, operations=true
-- SAFETY: sellability=true, operations=true, guest=true
--
-- This avoids hiding semantic behavior inside free-text reason or JSON metadata.
