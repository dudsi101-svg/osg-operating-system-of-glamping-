-- OSG Scenario 13 — durable Guest identity/provenance corpus for v1 data-preservation proof
-- Synthetic data only. No real guest PII.

begin;

insert into party (
  id, organization_id, party_type, display_name, legal_name, active,
  created_at, updated_at, row_version
) values
  ('00000000-0000-7000-8000-000000007301','00000000-0000-7000-8000-000000000001','PERSON','Preservation Guest Canonical',null,true,'2026-06-01T08:00:00+02','2026-06-01T08:00:00+02',1),
  ('00000000-0000-7000-8000-000000007302','00000000-0000-7000-8000-000000000001','PERSON','Preservation Guest Alias',null,true,'2026-06-02T09:00:00+02','2026-06-02T09:00:00+02',1);

insert into guest_profile (
  id, organization_id, party_id, preferred_language, crm_status,
  first_seen_at, last_seen_at, created_at
) values
  ('00000000-0000-7000-8000-000000007311','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000007301','pl','ACTIVE','2026-06-01T08:00:00+02','2026-06-10T10:00:00+02','2026-06-01T08:00:00+02'),
  ('00000000-0000-7000-8000-000000007312','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000007302','pl','ACTIVE','2026-06-02T09:00:00+02','2026-06-09T11:00:00+02','2026-06-02T09:00:00+02');

insert into guest_identity_signal (
  id, organization_id, guest_profile_id, signal_type,
  normalized_value, value_hash, source, confidence, verified_at, active, created_at
) values
  ('00000000-0000-7000-8000-000000007321','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000007311','EMAIL','preservation.canonical@example.invalid',null,'RC1_PRESERVATION_FIXTURE','VERIFIED','2026-06-10T10:00:00+02',true,'2026-06-10T10:00:00+02'),
  ('00000000-0000-7000-8000-000000007322','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000007312','HASHED_SOURCE_ID',null,'fixture-hash-alias-001','RC1_PRESERVATION_FIXTURE','SYSTEM_DERIVED',null,true,'2026-06-10T10:01:00+02');

insert into guest_match_candidate (
  id, organization_id, guest_profile_a_id, guest_profile_b_id,
  match_method, method_version, confidence, evidence, status,
  created_at, reviewed_at, reviewed_by_user_id
) values (
  '00000000-0000-7000-8000-000000007331',
  '00000000-0000-7000-8000-000000000001',
  '00000000-0000-7000-8000-000000007311',
  '00000000-0000-7000-8000-000000007312',
  'FIXTURE_EXACT_SOURCE_LINK','v1',0.9900,
  '{"source":"rc1-preservation","synthetic":true}'::jsonb,
  'CONFIRMED_MATCH',
  '2026-06-10T10:02:00+02','2026-06-10T10:03:00+02',null
);

insert into guest_profile_alias (
  id, organization_id, alias_guest_profile_id, canonical_guest_profile_id,
  active, effective_from, effective_to, created_at
) values (
  '00000000-0000-7000-8000-000000007341',
  '00000000-0000-7000-8000-000000000001',
  '00000000-0000-7000-8000-000000007312',
  '00000000-0000-7000-8000-000000007311',
  true,'2026-06-10T10:04:00+02',null,'2026-06-10T10:04:00+02'
);

insert into guest_merge_event (
  id, organization_id, canonical_guest_profile_id, merged_guest_profile_id,
  match_candidate_id, action, reason, actor_user_id, occurred_at, evidence
) values (
  '00000000-0000-7000-8000-000000007351',
  '00000000-0000-7000-8000-000000000001',
  '00000000-0000-7000-8000-000000007311',
  '00000000-0000-7000-8000-000000007312',
  '00000000-0000-7000-8000-000000007331',
  'MERGE','Synthetic RC1 preservation proof',null,'2026-06-10T10:05:00+02',
  '{"proof":"data-preservation","synthetic":true}'::jsonb
);

do $$
begin
  if osg_canonical_guest_profile(
      '00000000-0000-7000-8000-000000000001',
      '00000000-0000-7000-8000-000000007312'
    ) <> '00000000-0000-7000-8000-000000007311'::uuid then
    raise exception 'OSG_SCENARIO_13_CANONICAL_GUEST_RESOLUTION_FAILED';
  end if;
end $$;

commit;
