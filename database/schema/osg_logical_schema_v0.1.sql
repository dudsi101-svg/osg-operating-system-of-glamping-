-- OSG PostgreSQL logical schema v0.1
-- Proof-of-model only. NOT production migration.

create extension if not exists pgcrypto;

create table organization (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  default_currency char(3) not null default 'PLN',
  default_timezone text not null default 'Europe/Warsaw',
  status text not null check (status in ('ACTIVE','SUSPENDED','ARCHIVED')),
  created_at timestamptz not null default now()
);

create table property (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  name text not null,
  code text not null,
  timezone text not null,
  currency char(3) not null,
  status text not null,
  unique (organization_id, code)
);

create table party (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  party_type text not null,
  display_name text not null,
  legal_name text,
  tax_id text,
  active boolean not null default true
);

create table unit_type (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  name text not null,
  code text not null,
  base_capacity integer not null check (base_capacity > 0),
  max_capacity integer not null check (max_capacity >= base_capacity),
  active boolean not null default true,
  unique(property_id, code)
);

create table unit (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  unit_type_id uuid not null references unit_type(id),
  code text not null,
  name text not null,
  lifecycle_status text not null,
  unique(property_id, code)
);

create table resource (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  code text not null,
  name text not null,
  resource_type text not null,
  capacity integer not null check (capacity > 0),
  booking_mode text not null,
  buffer_before interval not null default interval '0 minutes',
  buffer_after interval not null default interval '0 minutes',
  active boolean not null default true,
  unique(property_id, code)
);

create table asset (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  unit_id uuid references unit(id),
  resource_id uuid references resource(id),
  name text not null,
  asset_type text not null,
  lifecycle_status text not null
);

create table guest_profile (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  party_id uuid not null unique references party(id),
  preferred_language text,
  first_seen_at timestamptz,
  last_seen_at timestamptz
);

create table channel (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  name text not null,
  channel_type text not null,
  active boolean not null default true
);

create table reservation (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  channel_id uuid references channel(id),
  primary_guest_id uuid references guest_profile(id),
  reference_code text not null,
  commercial_status text not null,
  booked_at timestamptz not null,
  currency char(3) not null,
  unique(property_id, reference_code)
);

create table reservation_item (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  reservation_id uuid not null references reservation(id),
  unit_type_id uuid not null references unit_type(id),
  assigned_unit_id uuid references unit(id),
  arrival_date date not null,
  departure_date date not null,
  adults integer not null default 1 check (adults >= 0),
  children integer not null default 0 check (children >= 0),
  infants integer not null default 0 check (infants >= 0),
  pets integer not null default 0 check (pets >= 0),
  check (departure_date > arrival_date)
);

create table stay (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  reservation_item_id uuid not null references reservation_item(id),
  primary_guest_id uuid references guest_profile(id),
  status text not null,
  actual_checkin_at timestamptz,
  actual_checkout_at timestamptz
);

create table stay_segment (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  stay_id uuid not null references stay(id),
  unit_id uuid not null references unit(id),
  start_at timestamptz not null,
  end_at timestamptz not null,
  reason text,
  check (end_at > start_at)
);

create table availability_block (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  unit_id uuid not null references unit(id),
  start_at timestamptz not null,
  end_at timestamptz not null,
  reason_type text not null,
  reason_text text,
  check (end_at > start_at)
);

create table folio (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  reservation_id uuid not null references reservation(id),
  stay_id uuid references stay(id),
  currency char(3) not null,
  status text not null
);

create table charge (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  folio_id uuid not null references folio(id),
  charge_type text not null,
  description text not null,
  quantity numeric(12,3) not null default 1,
  unit_price numeric(14,2) not null,
  gross_amount numeric(14,2) not null,
  recognized_at timestamptz,
  status text not null
);

create table payment (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  folio_id uuid not null references folio(id),
  payer_party_id uuid references party(id),
  amount numeric(14,2) not null check (amount >= 0),
  currency char(3) not null,
  status text not null,
  paid_at timestamptz
);

create table payment_allocation (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  payment_id uuid not null references payment(id),
  charge_id uuid not null references charge(id),
  amount numeric(14,2) not null check (amount > 0)
);

create table service (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  name text not null,
  service_type text not null,
  pricing_mode text not null,
  base_price numeric(14,2),
  requires_booking boolean not null default false,
  requires_resource boolean not null default false,
  active boolean not null default true
);

create table service_booking (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  service_id uuid not null references service(id),
  stay_id uuid references stay(id),
  reservation_id uuid references reservation(id),
  guest_profile_id uuid references guest_profile(id),
  start_at timestamptz,
  end_at timestamptz,
  status text not null
);

create table resource_reservation (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  resource_id uuid not null references resource(id),
  service_booking_id uuid references service_booking(id),
  start_at timestamptz not null,
  end_at timestamptz not null,
  effective_start_at timestamptz not null,
  effective_end_at timestamptz not null,
  capacity_used integer not null default 1 check (capacity_used > 0),
  status text not null,
  check (end_at > start_at),
  check (effective_end_at > effective_start_at)
);

create table money_account (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid references property(id),
  name text not null,
  account_type text not null,
  currency char(3) not null,
  active boolean not null default true
);

create table cash_movement (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  from_money_account_id uuid references money_account(id),
  to_money_account_id uuid references money_account(id),
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null,
  occurred_at timestamptz not null,
  external_reference text,
  status text not null
);

create table financial_document (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  document_type text not null,
  document_number text,
  issuer_party_id uuid references party(id),
  recipient_party_id uuid references party(id),
  issue_date date,
  service_date date,
  currency char(3) not null,
  gross_total numeric(14,2) not null,
  status text not null
);

create table financial_document_line (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  financial_document_id uuid not null references financial_document(id),
  description text not null,
  gross_amount numeric(14,2) not null
);

create table economic_event (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  event_type text not null,
  economic_date date not null,
  amount numeric(14,2) not null,
  currency char(3) not null,
  source_document_line_id uuid references financial_document_line(id),
  source_charge_id uuid references charge(id),
  status text not null
);

create table investment_project (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid not null references property(id),
  name text not null,
  status text not null
);

create table cost_center (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  property_id uuid references property(id),
  code text not null,
  name text not null,
  unique(organization_id, code)
);

create table allocation (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  economic_event_id uuid not null references economic_event(id),
  amount numeric(14,2) not null,
  property_id uuid references property(id),
  unit_id uuid references unit(id),
  stay_id uuid references stay(id),
  resource_id uuid references resource(id),
  asset_id uuid references asset(id),
  service_id uuid references service(id),
  channel_id uuid references channel(id),
  investment_project_id uuid references investment_project(id),
  cost_center_id uuid references cost_center(id),
  paid_by_party_id uuid references party(id),
  economic_bearer_party_id uuid references party(id),
  allocation_type text not null,
  classification text not null,
  confidence text not null,
  allocation_method text,
  rationale text
);

create table settlement_entry (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  source_economic_event_id uuid references economic_event(id),
  creditor_party_id uuid not null references party(id),
  debtor_party_id uuid not null references party(id),
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null,
  status text not null,
  check (creditor_party_id <> debtor_party_id)
);

create table domain_event (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organization(id),
  event_type text not null,
  event_version integer not null default 1,
  aggregate_type text not null,
  aggregate_id uuid not null,
  property_id uuid references property(id),
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default now(),
  correlation_id uuid,
  causation_id uuid,
  payload jsonb not null default '{}'::jsonb
);

-- TODO before production:
-- 1. tenant-consistency composite FKs or guarded constraints
-- 2. temporal exclusion constraint for active stay_segment ranges
-- 3. resource capacity concurrency enforcement
-- 4. deferred constraint/trigger for posted economic_event allocation equality
-- 5. payment allocation sum enforcement
-- 6. immutable posted financial records policy
-- 7. RLS policies
-- 8. indexes and partitioning strategy
