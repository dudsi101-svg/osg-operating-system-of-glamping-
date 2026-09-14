-- OSG v0.96 Property Stay Policy patch
-- Discovered while translating occupancy/sellable-capacity semantics to SQL.
-- DEV/PRE-FREEZE candidate.

create table property_stay_policy (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid not null,
  version_no integer not null check (version_no > 0),
  valid_from date not null,
  valid_to date,
  default_checkin_time time not null,
  default_checkout_time time not null,
  readiness_buffer interval not null default interval '30 minutes',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (property_id, version_no),
  foreign key (organization_id, property_id) references property(organization_id, id),
  check (valid_to is null or valid_to >= valid_from)
);

-- Semantics:
-- A sellable unit-night for date D uses the PropertyStayPolicy valid on D.
-- Reference occupancy window:
--   D at default_checkin_time (Property timezone)
--   until D+1 at default_checkout_time (Property timezone).
--
-- Actual StaySegment timestamps remain the source of observed occupancy.
-- Reservation/CommercialSnapshot may override arrival/departure expectations,
-- but changing today's default policy must not rewrite historical metrics.
