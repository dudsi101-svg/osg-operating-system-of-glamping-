#!/usr/bin/env bash
set -euo pipefail

SOURCE_DB="${PGDATABASE:-osg_source}"
RC_DB="osg_rc_test"
ARTIFACT_DIR="artifacts"
DDL_PATH="$ARTIFACT_DIR/osg_schema_v1_rc1.generated.sql"
LOG_PATH="$ARTIFACT_DIR/osg_schema_v1_rc1_equivalence.log"

mkdir -p "$ARTIFACT_DIR"
: > "$LOG_PATH"
exec > >(tee -a "$LOG_PATH") 2>&1

echo "OSG_RC source_db=$SOURCE_DB target_db=$RC_DB"

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

for f in "${schema_files[@]}"; do
  test -f "$f" || { echo "OSG_RC_FAILURE missing_schema_artifact=$f" >&2; exit 1; }
  echo "OSG_RC_SOURCE_LOAD $f"
  psql -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -f "$f" >/dev/null
done

echo "OSG_RC source patch-chain loaded"

pg_dump \
  --schema-only \
  --no-owner \
  --no-privileges \
  --format=plain \
  --file="$DDL_PATH" \
  "$SOURCE_DB"

test -s "$DDL_PATH" || { echo "OSG_RC_FAILURE generated DDL empty" >&2; exit 1; }
if grep -Eq '^(COPY |INSERT INTO )' "$DDL_PATH"; then
  echo "OSG_RC_FAILURE schema-only artifact unexpectedly contains row data" >&2
  exit 1
fi

echo "OSG_RC generated_schema_bytes=$(wc -c < "$DDL_PATH")"
echo "OSG_RC generated_schema_sha256=$(sha256sum "$DDL_PATH" | awk '{print $1}')"

dropdb --if-exists "$RC_DB"
createdb "$RC_DB"
psql -X -v ON_ERROR_STOP=1 -d "$RC_DB" -f "$DDL_PATH" >/dev/null

echo "OSG_RC flattened candidate clean-load PASS"

inventory_sql="
select 'relation:'||c.relkind::text||':'||count(*)::text
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind in ('r','v','m','S')
group by c.relkind
union all
select 'function:'||count(*)::text
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
union all
select 'trigger:'||count(*)::text
from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and not t.tgisinternal
union all
select 'constraint:'||count(*)::text
from pg_constraint co join pg_namespace n on n.oid=co.connamespace
where n.nspname='public'
order by 1;
"

psql -X -At -d "$SOURCE_DB" -c "$inventory_sql" > /tmp/osg_source_inventory.txt
psql -X -At -d "$RC_DB" -c "$inventory_sql" > /tmp/osg_rc_inventory.txt

echo "OSG_RC source inventory"
cat /tmp/osg_source_inventory.txt
echo "OSG_RC flattened inventory"
cat /tmp/osg_rc_inventory.txt
diff -u /tmp/osg_source_inventory.txt /tmp/osg_rc_inventory.txt

echo "OSG_RC structural inventory equivalence PASS"

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
)

for f in "${seed_files[@]}"; do
  echo "OSG_RC_SEED $f"
  psql -X -v ON_ERROR_STOP=1 -d "$RC_DB" -f "$f" >/dev/null
done

for f in "${scenario_files[@]}"; do
  echo "OSG_RC_SCENARIO $f"
  psql -X -v ON_ERROR_STOP=1 -d "$RC_DB" -f "$f" >/dev/null
done

export PGDATABASE="$RC_DB"

psql -X -v ON_ERROR_STOP=1 -f tests/sql/stay_segment_overlap_pre_v1.sql >/dev/null
python tests/integration/resource_concurrency_pre_v1.py
python tests/integration/financial_posting_pre_v1.py
python tests/integration/idempotency_pre_v1.py
python tests/integration/idempotency_business_effects_pre_v1.py
python tests/integration/tenant_isolation_pre_v1.py
python tests/integration/property_context_pre_v1.py
python tests/integration/settlement_concurrency_pre_v1.py
python tests/integration/folio_invariants_pre_v1.py
python tests/integration/charge_reversal_pre_v1.py
psql -X -v ON_ERROR_STOP=1 -f tests/sql/scenario_11_resource_capacity_v0.96.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 -f tests/sql/p0_invariants_v0.1.sql >/dev/null
psql -X -v ON_ERROR_STOP=1 -f tests/sql/folio_invariants_pre_v1.sql >/dev/null

psql -X -v ON_ERROR_STOP=1 <<'SQL'
select count(*) as organizations from organization;
select count(*) as properties from property;
select count(*) as units from unit;
select count(*) as reservations from reservation;
select count(*) as economic_events from economic_event;
SQL

echo "PASS OSG Issue #15 flattened Schema v1.0 RC1 behavioral equivalence proof"
