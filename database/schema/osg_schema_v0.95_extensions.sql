-- OSG PostgreSQL schema candidate v0.95 — EXTENSIONS
-- Requires osg_schema_v0.95_core.sql.
-- PRE-FREEZE / DEV CANDIDATE. NOT A PRODUCTION MIGRATION.

-- ================================================================
-- INTEGRATIONS / IDEMPOTENCY
-- ================================================================

create table integration (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  provider text not null,
  integration_type text not null check (integration_type in ('RESERVATION_SOURCE','CHANNEL_MANAGER','PAYMENT_PROVIDER','BANK','ACCOUNTING','MESSAGING','IDENTITY','FILE_OCR','ANALYTICS_EXPORT','OTHER')),
  status text not null check (status in ('ACTIVE','DEGRADED','DISABLED','ERROR')),
  sync_mode text not null check (sync_mode in ('WEBHOOK_PRIMARY','POLLING','MANUAL_IMPORT','BATCH_FILE','HYBRID')),
  credentials_reference text,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  created_at timestamptz not null default now(),
  row_version bigint not null default 1,
  unique (organization_id, id),
  foreign key (organization_id, property_id) references property(organization_id, id)
);

create table external_record (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  integration_id uuid not null,
  external_type text not null,
  external_id text not null,
  source_version text,
  received_at timestamptz not null default now(),
  payload_hash text not null,
  payload jsonb,
  processing_status text not null check (processing_status in ('RECEIVED','PROCESSING','MAPPED','REJECTED','DUPLICATE','FAILED')),
  unique (organization_id, id),
  foreign key (organization_id, integration_id) references integration(organization_id, id)
);

create index idx_external_record_lookup on external_record(integration_id, external_type, external_id);

create table integration_processing_record (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  integration_id uuid not null,
  external_event_id text not null,
  action_key text not null default 'default',
  status text not null check (status in ('RECEIVED','PROCESSING','SUCCEEDED','FAILED_RETRYABLE','FAILED_FINAL','DUPLICATE')),
  result_reference text,
  attempts integer not null default 0,
  first_seen_at timestamptz not null default now(),
  last_attempt_at timestamptz,
  last_error text,
  unique (organization_id, id),
  unique (integration_id, external_event_id, action_key),
  foreign key (organization_id, integration_id) references integration(organization_id, id)
);

create table external_reference (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  integration_id uuid not null,
  external_type text not null,
  external_id text not null,
  osg_entity_type text not null,
  osg_entity_id uuid not null,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (integration_id, external_type, external_id),
  foreign key (organization_id, integration_id) references integration(organization_id, id)
);

-- Generic target is acceptable here because ExternalReference is an integration
-- mapping registry spanning many bounded contexts. Domain-critical relations
-- remain explicit FKs inside core tables.

-- ================================================================
-- FILES / EXTRACTION
-- ================================================================

create table file_object (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  storage_key text not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes >= 0),
  checksum_sha256 text not null,
  classification text not null check (classification in ('PUBLIC','INTERNAL','CONFIDENTIAL','PERSONAL','SENSITIVE_OPERATIONAL','FINANCIAL','SECURITY')),
  retention_class text,
  uploaded_by_user_id uuid,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (organization_id, id),
  unique (organization_id, checksum_sha256, storage_key),
  foreign key (organization_id, uploaded_by_user_id) references user_account(organization_id, id)
);

create table attachment_link (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  file_object_id uuid not null,
  context_type text not null,
  context_id uuid not null,
  purpose text,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, file_object_id) references file_object(organization_id, id)
);

create table extraction (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  file_object_id uuid not null,
  extractor text not null,
  extractor_version text,
  confidence numeric(5,4) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  result jsonb not null,
  validation_status text not null check (validation_status in ('UNVALIDATED','VALIDATED','REJECTED')),
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, file_object_id) references file_object(organization_id, id)
);

-- ================================================================
-- AUTOMATION
-- ================================================================

create table automation_rule (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  code text not null,
  version_no integer not null check (version_no > 0),
  trigger_event_type text not null,
  conditions jsonb not null default '{}'::jsonb,
  actions jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, code, version_no),
  foreign key (organization_id, property_id) references property(organization_id, id)
);

create table automation_execution (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  automation_rule_id uuid not null,
  trigger_event_id uuid not null,
  action_key text not null,
  status text not null check (status in ('PENDING','RUNNING','SUCCEEDED','FAILED_RETRYABLE','FAILED_FINAL','SKIPPED')),
  started_at timestamptz,
  completed_at timestamptz,
  retry_count integer not null default 0,
  error text,
  result jsonb,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (automation_rule_id, trigger_event_id, action_key),
  foreign key (organization_id, automation_rule_id) references automation_rule(organization_id, id),
  foreign key (organization_id, trigger_event_id) references domain_event(organization_id, id)
);

-- ================================================================
-- COMMUNICATION / NOTIFICATIONS
-- ================================================================

create table conversation (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  guest_profile_id uuid,
  reservation_id uuid,
  stay_id uuid,
  status text not null default 'OPEN' check (status in ('OPEN','CLOSED','ARCHIVED')),
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, property_id) references property(organization_id, id),
  foreign key (organization_id, guest_profile_id) references guest_profile(organization_id, id),
  foreign key (organization_id, reservation_id) references reservation(organization_id, id),
  foreign key (organization_id, stay_id) references stay(organization_id, id),
  check (num_nonnulls(guest_profile_id, reservation_id, stay_id) >= 1)
);

create table message_template (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  code text not null,
  version_no integer not null,
  channel text not null,
  language text not null default 'pl',
  subject_template text,
  body_template text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, code, version_no, language),
  foreign key (organization_id, property_id) references property(organization_id, id)
);

create table message (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  conversation_id uuid not null,
  template_id uuid,
  channel text not null check (channel in ('EMAIL','SMS','WHATSAPP','PORTAL','INTERNAL','OTHER')),
  direction text not null check (direction in ('INBOUND','OUTBOUND')),
  sender_party_id uuid,
  recipient_party_id uuid,
  subject text,
  body text not null,
  delivery_status text not null default 'QUEUED' check (delivery_status in ('QUEUED','SENT','DELIVERED','FAILED','BOUNCED','READ','RECEIVED')),
  provider_message_id text,
  deduplication_key text,
  sent_at timestamptz,
  received_at timestamptz,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, deduplication_key),
  foreign key (organization_id, conversation_id) references conversation(organization_id, id),
  foreign key (organization_id, template_id) references message_template(organization_id, id),
  foreign key (organization_id, sender_party_id) references party(organization_id, id),
  foreign key (organization_id, recipient_party_id) references party(organization_id, id)
);

create table notification (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  target_user_id uuid,
  target_role_id uuid,
  severity text not null check (severity in ('INFO','ACTION_REQUIRED','WARNING','CRITICAL')),
  category text not null,
  title text not null,
  body text,
  subject_type text,
  subject_id uuid,
  action_url text,
  deduplication_key text,
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  expires_at timestamptz,
  unique (organization_id, id),
  unique (organization_id, deduplication_key),
  foreign key (organization_id, property_id) references property(organization_id, id),
  foreign key (organization_id, target_user_id) references user_account(organization_id, id),
  foreign key (organization_id, target_role_id) references role(organization_id, id),
  check (num_nonnulls(target_user_id, target_role_id) >= 1)
);

-- ================================================================
-- INVENTORY
-- ================================================================

create table inventory_item (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  code text not null,
  name text not null,
  category text,
  unit_of_measure text not null,
  track_mode text not null check (track_mode in ('COUNTED','ESTIMATED','NON_TRACKED')),
  active boolean not null default true,
  unique (organization_id, id),
  unique (organization_id, code)
);

create table inventory_location (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid not null,
  zone_id uuid,
  code text not null,
  name text not null,
  active boolean not null default true,
  unique (organization_id, id),
  unique (property_id, code),
  foreign key (organization_id, property_id) references property(organization_id, id),
  foreign key (organization_id, zone_id) references zone(organization_id, id)
);

create table stock_movement (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  inventory_item_id uuid not null,
  from_location_id uuid,
  to_location_id uuid,
  movement_type text not null check (movement_type in ('RECEIPT','CONSUMPTION','TRANSFER','ADJUSTMENT','WASTE','RETURN','REVERSAL')),
  quantity numeric(14,3) not null check (quantity > 0),
  occurred_at timestamptz not null,
  confidence text not null default 'VERIFIED' check (confidence in ('VERIFIED','SYSTEM_DERIVED','ESTIMATED','MANUAL','UNKNOWN')),
  reason text,
  turnover_id uuid,
  stay_id uuid,
  reverses_movement_id uuid,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, inventory_item_id) references inventory_item(organization_id, id),
  foreign key (organization_id, from_location_id) references inventory_location(organization_id, id),
  foreign key (organization_id, to_location_id) references inventory_location(organization_id, id),
  foreign key (organization_id, turnover_id) references turnover(organization_id, id),
  foreign key (organization_id, stay_id) references stay(organization_id, id),
  foreign key (organization_id, reverses_movement_id) references stock_movement(organization_id, id),
  check (num_nonnulls(from_location_id, to_location_id) >= 1),
  check (movement_type <> 'ADJUSTMENT' or reason is not null)
);

create table reorder_rule (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  inventory_item_id uuid not null,
  inventory_location_id uuid not null,
  min_quantity numeric(14,3) not null,
  target_quantity numeric(14,3),
  lead_time interval,
  active boolean not null default true,
  unique (organization_id, id),
  unique (inventory_item_id, inventory_location_id),
  foreign key (organization_id, inventory_item_id) references inventory_item(organization_id, id),
  foreign key (organization_id, inventory_location_id) references inventory_location(organization_id, id)
);

-- ================================================================
-- REVENUE
-- ================================================================

create table rate_plan (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid not null,
  code text not null,
  name text not null,
  cancellation_policy_code text,
  active boolean not null default true,
  unique (organization_id, id),
  unique (property_id, code),
  foreign key (organization_id, property_id) references property(organization_id, id)
);

create table rate (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid not null,
  unit_type_id uuid not null,
  rate_plan_id uuid not null,
  channel_id uuid,
  stay_date date not null,
  amount numeric(14,2) not null check (amount >= 0),
  currency char(3) not null,
  source text not null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, property_id) references property(organization_id, id),
  foreign key (organization_id, unit_type_id) references unit_type(organization_id, id),
  foreign key (organization_id, rate_plan_id) references rate_plan(organization_id, id),
  foreign key (organization_id, channel_id) references channel(organization_id, id)
);

create index idx_rate_lookup on rate(property_id, unit_type_id, stay_date, rate_plan_id);

create table commission_rule (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  channel_id uuid not null,
  valid_from date not null,
  valid_to date,
  commission_type text not null check (commission_type in ('PERCENT','FIXED','HYBRID')),
  percent_rate numeric(7,4),
  fixed_amount numeric(14,2),
  currency char(3),
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, channel_id) references channel(organization_id, id),
  check (valid_to is null or valid_to >= valid_from)
);

create table pricing_rule (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid not null,
  code text not null,
  version_no integer not null,
  conditions jsonb not null,
  adjustment jsonb not null,
  guardrails jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (property_id, code, version_no),
  foreign key (organization_id, property_id) references property(organization_id, id)
);

create table pricing_suggestion (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid not null,
  unit_type_id uuid not null,
  stay_date date not null,
  suggested_amount numeric(14,2) not null check (suggested_amount >= 0),
  currency char(3) not null,
  source_type text not null check (source_type in ('RULE','MODEL','AI','MANUAL')),
  source_reference text,
  confidence numeric(5,4),
  rationale text,
  status text not null check (status in ('GENERATED','REVIEWED','ACCEPTED','REJECTED','EXPIRED','PUBLISHED')),
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, property_id) references property(organization_id, id),
  foreign key (organization_id, unit_type_id) references unit_type(organization_id, id)
);

-- ================================================================
-- INITIAL INDEXES
-- ================================================================

create index idx_integration_health on integration(organization_id, status, last_success_at);
create index idx_processing_retry on integration_processing_record(status, last_attempt_at);
create index idx_message_conversation on message(conversation_id, created_at);
create index idx_notification_user on notification(target_user_id, acknowledged_at, created_at);
create index idx_stock_item_time on stock_movement(inventory_item_id, occurred_at);
create index idx_pricing_suggestion on pricing_suggestion(property_id, stay_date, status);

-- ================================================================
-- NOTES BEFORE v1.0 FINAL
-- ================================================================
-- 1. ExternalReference generic target stays in integration boundary only.
-- 2. PricingRule JSON is configuration DSL, not source transactional data.
-- 3. AttachmentLink generic context stays in file infrastructure boundary.
-- 4. Capacity Resource concurrency remains domain-service + locking for capacity > 1.
-- 5. RLS policies and provider-specific integration tables are intentionally not frozen here.
