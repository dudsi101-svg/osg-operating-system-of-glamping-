-- OSG pre-v1 Guest identity resolution entities
-- PRE-FREEZE / DEV candidate.

create table guest_identity_signal (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  guest_profile_id uuid not null,
  signal_type text not null check (signal_type in ('EMAIL','PHONE','EXTERNAL_CUSTOMER_ID','HASHED_SOURCE_ID','OTHER')),
  normalized_value text,
  value_hash text,
  source text not null,
  confidence text not null default 'UNKNOWN' check (confidence in ('VERIFIED','SYSTEM_DERIVED','ESTIMATED','MANUAL','UNKNOWN')),
  verified_at timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id,id),
  foreign key (organization_id,guest_profile_id) references guest_profile(organization_id,id),
  check (num_nonnulls(normalized_value,value_hash) >= 1)
);

create index idx_guest_identity_signal_lookup
  on guest_identity_signal(organization_id,signal_type,value_hash)
  where active=true and value_hash is not null;

create table guest_match_candidate (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  guest_profile_a_id uuid not null,
  guest_profile_b_id uuid not null,
  match_method text not null,
  method_version text,
  confidence numeric(5,4) check (confidence is null or (confidence>=0 and confidence<=1)),
  evidence jsonb not null default '{}'::jsonb,
  status text not null check (status in ('OPEN','CONFIRMED_MATCH','REJECTED','EXPIRED')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by_user_id uuid,
  unique (organization_id,id),
  foreign key (organization_id,guest_profile_a_id) references guest_profile(organization_id,id),
  foreign key (organization_id,guest_profile_b_id) references guest_profile(organization_id,id),
  foreign key (organization_id,reviewed_by_user_id) references user_account(organization_id,id),
  check (guest_profile_a_id <> guest_profile_b_id)
);

create unique index uq_guest_match_candidate_pair_open
  on guest_match_candidate(
    organization_id,
    least(guest_profile_a_id,guest_profile_b_id),
    greatest(guest_profile_a_id,guest_profile_b_id)
  ) where status='OPEN';

create table guest_profile_alias (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  alias_guest_profile_id uuid not null,
  canonical_guest_profile_id uuid not null,
  active boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  unique (organization_id,id),
  foreign key (organization_id,alias_guest_profile_id) references guest_profile(organization_id,id),
  foreign key (organization_id,canonical_guest_profile_id) references guest_profile(organization_id,id),
  check (alias_guest_profile_id <> canonical_guest_profile_id),
  check (effective_to is null or effective_to > effective_from)
);

create unique index uq_guest_profile_active_alias
  on guest_profile_alias(organization_id,alias_guest_profile_id)
  where active=true;

create table guest_merge_event (
  id uuid primary key,
  organization_id uuid not null references organization(id),
  canonical_guest_profile_id uuid not null,
  merged_guest_profile_id uuid not null,
  match_candidate_id uuid,
  action text not null check (action in ('MERGE','UNDO_MERGE')),
  reason text not null,
  actor_user_id uuid,
  occurred_at timestamptz not null default now(),
  evidence jsonb not null default '{}'::jsonb,
  unique (organization_id,id),
  foreign key (organization_id,canonical_guest_profile_id) references guest_profile(organization_id,id),
  foreign key (organization_id,merged_guest_profile_id) references guest_profile(organization_id,id),
  foreign key (organization_id,match_candidate_id) references guest_match_candidate(organization_id,id),
  foreign key (organization_id,actor_user_id) references user_account(organization_id,id),
  check (canonical_guest_profile_id <> merged_guest_profile_id)
);

-- Resolve current canonical identity. Alias chains should be flattened by merge workflow;
-- this helper intentionally follows one active alias only to keep resolution deterministic.
create or replace function osg_canonical_guest_profile(
  p_organization_id uuid,
  p_guest_profile_id uuid
)
returns uuid language sql stable as $$
  select coalesce(
    (select canonical_guest_profile_id
     from guest_profile_alias
     where organization_id=p_organization_id
       and alias_guest_profile_id=p_guest_profile_id
       and active=true
     limit 1),
    p_guest_profile_id
  )
$$;

-- Merge workflow must reject cycles and alias-to-alias chains; canonical target should
-- itself have no active alias. Historical Reservation/Stay FKs are not rewritten.
