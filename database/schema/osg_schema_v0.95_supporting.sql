-- OSG PostgreSQL schema candidate v0.95 — SUPPORTING CANONICAL ENTITIES
-- Requires core + extensions. PRE-FREEZE / DEV CANDIDATE.

-- ================================================================
-- CONFIG / APPROVAL
-- ================================================================

create table approval_policy (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  code text not null,
  version_no integer not null check (version_no > 0),
  conditions jsonb not null default '{}'::jsonb,
  outcome text not null check (outcome in ('NO_APPROVAL','SINGLE_APPROVAL','DUAL_CONTROL','OWNER_APPROVAL','FINANCE_APPROVAL','CUSTOM_CHAIN')),
  active boolean not null default true,
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  unique (organization_id, id),
  unique (organization_id, code, version_no),
  foreign key (organization_id, property_id) references property(organization_id, id),
  check (valid_to is null or valid_to > valid_from)
);

-- ================================================================
-- OPERATIONS TEMPLATES / MAINTENANCE
-- ================================================================

create table task_template (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  code text not null,
  version_no integer not null check (version_no > 0),
  task_type text not null,
  title_template text not null,
  checklist jsonb not null default '[]'::jsonb,
  requires_work_log boolean not null default false,
  active boolean not null default true,
  unique (organization_id, id),
  unique (organization_id, code, version_no),
  foreign key (organization_id, property_id) references property(organization_id, id)
);

create table maintenance_plan (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid not null,
  asset_id uuid,
  resource_id uuid,
  task_template_id uuid not null,
  maintenance_type text not null check (maintenance_type in ('PREVENTIVE','INSPECTION','SAFETY','WARRANTY','UPGRADE')),
  schedule_type text not null check (schedule_type in ('CALENDAR','USAGE','MANUAL')),
  schedule_config jsonb not null,
  next_due_at timestamptz,
  criticality text not null check (criticality in ('LOW','MEDIUM','HIGH','CRITICAL')),
  active boolean not null default true,
  unique (organization_id, id),
  foreign key (organization_id, property_id) references property(organization_id, id),
  foreign key (organization_id, asset_id) references asset(organization_id, id),
  foreign key (organization_id, resource_id) references resource(organization_id, id),
  foreign key (organization_id, task_template_id) references task_template(organization_id, id),
  check (num_nonnulls(asset_id, resource_id) = 1)
);

-- ================================================================
-- PACKAGES
-- ================================================================

create table package (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid not null,
  code text not null,
  name text not null,
  version_no integer not null default 1,
  active boolean not null default true,
  valid_from date,
  valid_to date,
  unique (organization_id, id),
  unique (property_id, code, version_no),
  foreign key (organization_id, property_id) references property(organization_id, id),
  check (valid_to is null or valid_from is null or valid_to >= valid_from)
);

create table package_component (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  package_id uuid not null,
  component_type text not null check (component_type in ('ACCOMMODATION','SERVICE','FEE','DISCOUNT')),
  unit_type_id uuid,
  service_id uuid,
  quantity numeric(12,3) not null default 1 check (quantity > 0),
  pricing_allocation jsonb,
  unique (organization_id, id),
  foreign key (organization_id, package_id) references package(organization_id, id),
  foreign key (organization_id, unit_type_id) references unit_type(organization_id, id),
  foreign key (organization_id, service_id) references service(organization_id, id),
  check (
    (component_type = 'ACCOMMODATION' and unit_type_id is not null and service_id is null)
    or (component_type = 'SERVICE' and service_id is not null and unit_type_id is null)
    or (component_type in ('FEE','DISCOUNT') and unit_type_id is null and service_id is null)
  )
);

-- ================================================================
-- FINANCIAL RULES / RECONCILIATION
-- ================================================================

create table allocation_rule (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  code text not null,
  version_no integer not null check (version_no > 0),
  basis text not null check (basis in ('EQUAL','REVENUE_SHARE','OCCUPIED_NIGHTS','AVAILABLE_NIGHTS','AREA_M2','GUEST_NIGHTS','USAGE_METER','MANUAL_PERCENTAGE','CUSTOM')),
  configuration jsonb not null default '{}'::jsonb,
  valid_from date not null,
  valid_to date,
  active boolean not null default true,
  unique (organization_id, id),
  unique (organization_id, code, version_no),
  foreign key (organization_id, property_id) references property(organization_id, id),
  check (valid_to is null or valid_to >= valid_from)
);

alter table allocation add column allocation_rule_id uuid;
alter table allocation
  add foreign key (organization_id, allocation_rule_id) references allocation_rule(organization_id, id);

create table reconciliation_link (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  financial_document_id uuid,
  financial_document_line_id uuid,
  cash_movement_id uuid,
  payment_id uuid,
  refund_id uuid,
  economic_event_id uuid,
  settlement_application_id uuid,
  match_status text not null check (match_status in ('UNMATCHED','PARTIAL','MATCHED','CONFLICT','IGNORED')),
  matched_amount numeric(14,2),
  confidence text not null default 'MANUAL' check (confidence in ('VERIFIED','SYSTEM_DERIVED','ESTIMATED','MANUAL','UNKNOWN')),
  rationale text,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, financial_document_id) references financial_document(organization_id, id),
  foreign key (organization_id, financial_document_line_id) references financial_document_line(organization_id, id),
  foreign key (organization_id, cash_movement_id) references cash_movement(organization_id, id),
  foreign key (organization_id, payment_id) references payment(organization_id, id),
  foreign key (organization_id, refund_id) references refund(organization_id, id),
  foreign key (organization_id, economic_event_id) references economic_event(organization_id, id),
  foreign key (organization_id, settlement_application_id) references settlement_application(organization_id, id),
  check (num_nonnulls(financial_document_id, financial_document_line_id, cash_movement_id, payment_id, refund_id, economic_event_id, settlement_application_id) >= 2)
);

-- ================================================================
-- COMMUNICATION CONSENT
-- ================================================================

create table communication_consent (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  guest_profile_id uuid not null,
  consent_type text not null,
  status text not null check (status in ('GRANTED','WITHDRAWN','NOT_REQUIRED')),
  content_version text,
  source text not null,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, guest_profile_id) references guest_profile(organization_id, id)
);

-- ================================================================
-- RATE SNAPSHOT / INTELLIGENCE RECOMMENDATION
-- ================================================================

create table rate_snapshot (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  reservation_item_id uuid not null,
  rate_plan_id uuid,
  channel_id uuid,
  stay_date date not null,
  amount numeric(14,2) not null check (amount >= 0),
  currency char(3) not null,
  captured_at timestamptz not null,
  source_reference text,
  unique (organization_id, id),
  foreign key (organization_id, reservation_item_id) references reservation_item(organization_id, id),
  foreign key (organization_id, rate_plan_id) references rate_plan(organization_id, id),
  foreign key (organization_id, channel_id) references channel(organization_id, id)
);

create table recommendation (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  recommendation_type text not null,
  subject_type text,
  subject_id uuid,
  action_class text not null check (action_class in ('A0','A1','A2','A3','A4')),
  status text not null check (status in ('GENERATED','REVIEWED','ACCEPTED','REJECTED','EXECUTED','EXPIRED')),
  confidence numeric(5,4),
  data_quality_context jsonb,
  rationale_summary text,
  proposed_action jsonb,
  source_version text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique (organization_id, id),
  foreign key (organization_id, property_id) references property(organization_id, id)
);

-- Supporting entities are kept separate to make their optional/extension nature clear,
-- but those listed here are part of the canonical v0.95 entity catalog.
