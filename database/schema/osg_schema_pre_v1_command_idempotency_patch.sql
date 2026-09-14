-- OSG pre-v1 Command Idempotency ledger
-- PRE-FREEZE / DEV candidate.

create table command_idempotency (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  property_id uuid,
  principal_key text not null,
  command_name text not null,
  idempotency_key text not null,
  request_hash text not null,
  status text not null check (status in ('IN_PROGRESS','SUCCEEDED','FAILED_RETRYABLE','FAILED_FINAL')),
  aggregate_type text,
  aggregate_id uuid,
  http_status integer,
  response_body jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at timestamptz,
  unique (organization_id, id),
  unique (organization_id, principal_key, command_name, idempotency_key),
  foreign key (organization_id, property_id) references property(organization_id, id),
  check (length(idempotency_key) >= 8),
  check (http_status is null or (http_status >= 100 and http_status <= 599))
);

create index idx_command_idempotency_expiry
  on command_idempotency(organization_id, expires_at)
  where expires_at is not null;

-- Contract:
-- same unique key + same request_hash + SUCCEEDED => replay prior committed outcome.
-- same unique key + different request_hash => IDEMPOTENCY_KEY_PAYLOAD_MISMATCH.
-- IN_PROGRESS => caller receives stable in-progress/conflict behavior; do not execute again.
-- FAILED_RETRYABLE may be reclaimed according to service policy using row lock.
--
-- principal_key examples:
-- user:<user_uuid>
-- integration:<integration_uuid>
-- ai:<initiating_user_uuid>:<agent_context>
-- system:<worker_name>
--
-- Generic principal_key avoids pretending every actor is a UserAccount while
-- keeping the tenant + principal + command namespace explicit.
