#!/usr/bin/env bash
set -euo pipefail

SOURCE_DB="osg_preservation_source"
TARGET_DB="osg_preservation_target"
ARTIFACT_DIR="artifacts/data-preservation"
SOURCE_FP="$ARTIFACT_DIR/source-fingerprint.json"
TARGET_FP="$ARTIFACT_DIR/target-fingerprint.json"
DATA_DUMP="$ARTIFACT_DIR/pre-v1-business-data.dump"
LOG_PATH="$ARTIFACT_DIR/proof.log"

mkdir -p "$ARTIFACT_DIR"
: > "$LOG_PATH"
exec > >(tee -a "$LOG_PATH") 2>&1

schema_files=(
  database/schema/osg_schema_v0.95_core.sql
  database/schema/osg_schema_v0.95_extensions.sql
  database/schema/osg_schema_v0.95_supporting.sql
  database/schema/osg_schema_v0.96_patch.sql
  database/schema/osg_schema_v0.96_financial_guard_patch.sql
  database/schema/osg_schema_v0.96_stay_policy_patch.sql
  database/schema/osg_schema_v0.97_availability_impact_patch.sql
  database/schema/osg_schema_v0.98_economic_direction_patch.sql
  database/schema/osg_schema_v0.99_property_context_guards.sql
  database/schema/osg_schema_pre_v1_external_reference_tenant_guard.sql
  database/schema/osg_schema_pre_v1_closed_period_guard_patch.sql
  database/schema/osg_schema_pre_v1_financial_period_assignment_patch.sql
  database/schema/osg_schema_pre_v1_command_idempotency_patch.sql
  database/schema/osg_schema_pre_v1_reporting_currency_guard.sql
  database/schema/osg_schema_pre_v1_guest_identity_resolution.sql
  database/schema/osg_schema_pre_v1_guest_alias_guards.sql
  database/schema/osg_schema_pre_v1_overnight_anchor_patch.sql
  database/semantic/osg_semantic_folio_v0.1.sql
  database/schema/osg_schema_pre_v1_folio_guards.sql
  database/schema/osg_schema_pre_v1_charge_reversal_guards.sql
  database/proof/financial_conservation_guards_v0.1.sql
  database/proof/resource_capacity_guard_v0.1.sql
  database/proof/financial_posting_workflow_v0.2.sql
  database/semantic/osg_semantic_occupancy_v0.1.sql
  database/semantic/osg_semantic_accommodation_nights_v0.1.sql
  database/semantic/osg_semantic_financial_truth_v0.1.sql
  database/semantic/osg_semantic_cash_v0.1.sql
  database/semantic/osg_semantic_revenue_v0.1.sql
  database/semantic/osg_semantic_operations_v0.1.sql
  database/semantic/osg_semantic_guest_v0.1.sql
  database/semantic/osg_data_quality_checks_v0.1.sql
  database/semantic/osg_data_quality_accommodation_nights_v0.1.sql
)

seed_files=(
  database/seeds/glamping_nad_stawem_master_v0.95.sql
  database/seeds/glamping_nad_stawem_stay_policy_v0.97.sql
  database/seeds/glamping_nad_stawem_financial_periods_v0.99.sql
)

scenario_files=(
  database/seeds/scenario_01_direct_stay_sauna_v0.95.sql
  database/seeds/scenario_02_ota_net_payout_v0.95.sql
  database/seeds/scenario_03_operator_expense_settlement_v0.95.sql
  database/seeds/scenario_04_mixed_business_private_allocation_v0.95.sql
  database/seeds/scenario_05_capex_opex_one_invoice_v0.95.sql
  database/seeds/scenario_06_incident_relocation_v0.95.sql
  database/seeds/scenario_07_prepayment_full_refund_v0.96.sql
  database/seeds/scenario_08_duplicate_pms_event_v0.96.sql
  database/seeds/scenario_09_shared_electricity_allocation_v0.96.sql
  database/seeds/scenario_10_late_invoice_closed_period_v0.96.sql
  database/seeds/scenario_12_turnover_at_risk_v0.96.sql
  database/seeds/scenario_13_rc1_data_preservation_fixture.sql
)

for f in "${schema_files[@]}" "${seed_files[@]}" "${scenario_files[@]}"; do
  test -f "$f" || { echo "OSG_DATA_PRESERVATION_FAILURE missing_artifact=$f" >&2; exit 1; }
done

echo "OSG_DATA_PRESERVATION source=$SOURCE_DB target=$TARGET_DB"

dropdb --if-exists "$SOURCE_DB"
createdb "$SOURCE_DB"
for f in "${schema_files[@]}"; do
  echo "OSG_DATA_PRESERVATION_SOURCE_SCHEMA $f"
  psql -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -f "$f" >/dev/null
done
for f in "${seed_files[@]}"; do
  echo "OSG_DATA_PRESERVATION_SOURCE_SEED $f"
  psql -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -f "$f" >/dev/null
done
for f in "${scenario_files[@]}"; do
  echo "OSG_DATA_PRESERVATION_SOURCE_SCENARIO $f"
  psql -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -f "$f" >/dev/null
done

python tools/fingerprint_public_data.py --dbname "$SOURCE_DB" --output "$SOURCE_FP"

# Archive only business rows. The pre-v1 lineage is DEV/test history rather than a
# supported production version, so this is a preservation/portability proof, not a
# claim that v0.x has an in-place production upgrade contract.
pg_dump \
  --format=custom \
  --data-only \
  --no-owner \
  --no-privileges \
  --file="$DATA_DUMP" \
  "$SOURCE_DB"

test -s "$DATA_DUMP"
echo "OSG_DATA_PRESERVATION dump_bytes=$(wc -c < "$DATA_DUMP")"
echo "OSG_DATA_PRESERVATION dump_sha256=$(sha256sum "$DATA_DUMP" | awk '{print $1}')"

dropdb --if-exists "$TARGET_DB"
createdb "$TARGET_DB"
PGDATABASE="$TARGET_DB" python database/migrations/apply.py --migration-dir database/migrations

# Source and target schemas are separately proven byte/behavior equivalent. During
# this portability proof triggers are disabled only for the historical bulk restore;
# exact row fingerprints and stable semantic projections must match afterwards.
pg_restore \
  --exit-on-error \
  --data-only \
  --disable-triggers \
  --no-owner \
  --no-privileges \
  --dbname="$TARGET_DB" \
  "$DATA_DUMP"

python tools/fingerprint_public_data.py --dbname "$TARGET_DB" --output "$TARGET_FP"
python tools/fingerprint_public_data.py --compare "$SOURCE_FP" "$TARGET_FP"

# Explicit identity/provenance and migration-ledger smoke checks.
psql -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<'SQL'
do $$
begin
  if osg_canonical_guest_profile(
      '00000000-0000-7000-8000-000000000001',
      '00000000-0000-7000-8000-000000007312'
    ) <> '00000000-0000-7000-8000-000000007311'::uuid then
    raise exception 'OSG_DATA_PRESERVATION_GUEST_ALIAS_CHANGED';
  end if;

  if (select count(*) from guest_merge_event
      where id='00000000-0000-7000-8000-000000007351') <> 1 then
    raise exception 'OSG_DATA_PRESERVATION_GUEST_MERGE_PROVENANCE_LOST';
  end if;

  if (select count(*) from public.osg_schema_migration) <> 1 then
    raise exception 'OSG_DATA_PRESERVATION_MIGRATION_LEDGER_INVALID';
  end if;
end $$;
SQL

# The restored corpus must still satisfy the core cross-row checks.
PGDATABASE="$TARGET_DB" psql -X -v ON_ERROR_STOP=1 -f tests/sql/p0_invariants_v0.1.sql >/dev/null
PGDATABASE="$TARGET_DB" psql -X -v ON_ERROR_STOP=1 -f tests/sql/folio_invariants_pre_v1.sql >/dev/null

echo "PASS OSG Issue #16 representative pre-v1 data preservation into production v1 baseline"
