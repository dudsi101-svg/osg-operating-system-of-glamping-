# OSG Database — Schema v1.0 RC1 Guide

Status: **RC1 CANDIDATE / NOT FINAL**
Date: 2026-09-16

## Current canonical candidate

Fresh-install Schema v1.0 RC1 candidate:

`rc/osg_schema_v1_rc1.sql`

Deterministic SHA-256:

`4c43fa53da21192b4160936b26770a1d9845acc5780f3d2c4d4b32a0be589f0d`

The file was generated from the accepted pre-v1 base+patch chain on PostgreSQL 16, normalized for deterministic `pg_dump` restrict markers, clean-loaded into a second database and exercised through the full accepted reference/invariant/concurrency suite.

Authoritative equivalence evidence:
- GitHub Issue #15
- deterministic proof run `35113431149` — PASS
- promotion run `35113875981` — PASS

The CI harness `../tests/integration/schema_v1_rc1_equivalence.sh` now regenerates the candidate and, when the committed RC1 file exists, requires byte-for-byte equality. A schema change that causes RC1 drift therefore fails until it is explicitly reviewed/reconsolidated.

## Important boundary

`Schema v1.0 RC1` is **not Schema v1.0 FINAL** and it is **not the production migration chain**.

Still required before FINAL:
1. versioned production migrations,
2. representative upgrade-path proof with existing data,
3. production-wide RLS coverage for every tenant-owned table,
4. independent freeze review.

Real PMS/channel and bank/cash adapter discovery remain production-pilot work and do not automatically reopen Core schema boundaries.

## Production RLS is intentionally not finalized in RC1

The tenant-isolation test installs realistic runtime-role RLS policies in the isolated CI database and proves fail-closed behavior. Historical `proof/tenant_rls_v0.1.sql` covers only selected tables and is **not** the production RLS baseline.

Production-wide RLS remains RC-005. Do not infer that RC1 contains the final policy rollout simply because tenant isolation tests pass.

## Runtime functions that originated in `database/proof/`

Some functions developed during proof became accepted runtime invariants and are present in the consolidated RC1 schema. Their classification is recorded in:

`../docs/engineering/OSG_RC1_Database_Function_Promotion_Register_v0.1.md`

Promoted runtime candidates include:
- `osg_assert_payment_not_overallocated(...)`
- `osg_assert_settlement_not_overapplied(...)`
- `osg_assert_resource_capacity(...)`
- `osg_post_economic_event_v02(...)`

`osg_charge_applied_amount(...)` remains an included read/derivation helper.

Historical proof-only files such as `proof/tenant_rls_v0.1.sql`, `proof/constraints_v0.1.sql` and superseded `proof/financial_posting_workflow_v0.1.sql` are not promoted as production baselines.

## Accepted pre-v1 chain — reproduction/evolution evidence

The files below remain in the repository to preserve architecture history and to regenerate/compare RC1. They are no longer the preferred fresh-install interface once RC1 is present.

### A. Base relational schema
1. `schema/osg_schema_v0.95_core.sql`
2. `schema/osg_schema_v0.95_extensions.sql`
3. `schema/osg_schema_v0.95_supporting.sql`

### B. Core semantic/invariant patches
4. `schema/osg_schema_v0.96_patch.sql`
5. `schema/osg_schema_v0.96_financial_guard_patch.sql`
6. `schema/osg_schema_v0.96_stay_policy_patch.sql`
7. `schema/osg_schema_v0.97_availability_impact_patch.sql`
8. `schema/osg_schema_v0.98_economic_direction_patch.sql`
9. `schema/osg_schema_v0.99_property_context_guards.sql`

### C. Pre-v1 hardening patches
10. `schema/osg_schema_pre_v1_external_reference_tenant_guard.sql`
11. `schema/osg_schema_pre_v1_closed_period_guard_patch.sql`
12. `schema/osg_schema_pre_v1_financial_period_assignment_patch.sql`
13. `schema/osg_schema_pre_v1_command_idempotency_patch.sql`
14. `schema/osg_schema_pre_v1_reporting_currency_guard.sql`
15. `schema/osg_schema_pre_v1_guest_identity_resolution.sql`
16. `schema/osg_schema_pre_v1_guest_alias_guards.sql`
17. `schema/osg_schema_pre_v1_overnight_anchor_patch.sql`

### D. Folio semantic prerequisite + commercial guards
18. `semantic/osg_semantic_folio_v0.1.sql`
19. `schema/osg_schema_pre_v1_folio_guards.sql`
20. `schema/osg_schema_pre_v1_charge_reversal_guards.sql`

`Folio` close guard queries the canonical Folio-balance semantic view, so the order is intentional.

### E. Runtime-candidate functions proven in the proof phase
21. `proof/financial_conservation_guards_v0.1.sql`
22. `proof/resource_capacity_guard_v0.1.sql`
23. `proof/financial_posting_workflow_v0.2.sql`

`proof/tenant_rls_v0.1.sql` is loaded only in dedicated historical/prototype RLS proof contexts, not in the RC1 generation chain.

### F. Semantic/read layer
24. `semantic/osg_semantic_occupancy_v0.1.sql`
25. `semantic/osg_semantic_accommodation_nights_v0.1.sql`
26. `semantic/osg_semantic_financial_truth_v0.1.sql`
27. `semantic/osg_semantic_cash_v0.1.sql`
28. `semantic/osg_semantic_revenue_v0.1.sql`
29. `semantic/osg_semantic_operations_v0.1.sql`
30. `semantic/osg_semantic_guest_v0.1.sql`
31. `semantic/osg_data_quality_checks_v0.1.sql`
32. `semantic/osg_data_quality_accommodation_nights_v0.1.sql`

### G. Reference configuration
33. `seeds/glamping_nad_stawem_master_v0.95.sql`
34. `seeds/glamping_nad_stawem_stay_policy_v0.97.sql`
35. `seeds/glamping_nad_stawem_financial_periods_v0.99.sql`

## Reference scenarios

Valid business-path fixtures:
- `scenario_01_direct_stay_sauna_v0.95.sql`
- `scenario_02_ota_net_payout_v0.95.sql`
- `scenario_03_operator_expense_settlement_v0.95.sql`
- `scenario_04_mixed_business_private_allocation_v0.95.sql`
- `scenario_05_capex_opex_one_invoice_v0.95.sql`
- `scenario_06_incident_relocation_v0.95.sql`
- `scenario_07_prepayment_full_refund_v0.96.sql`
- `scenario_08_duplicate_pms_event_v0.96.sql`
- `scenario_09_shared_electricity_allocation_v0.96.sql`
- `scenario_10_late_invoice_closed_period_v0.96.sql`
- `scenario_12_turnover_at_risk_v0.96.sql`

Negative/transactional suites include:
- `../tests/sql/stay_segment_overlap_pre_v1.sql`
- `../tests/sql/scenario_11_resource_capacity_v0.96.sql`
- `../tests/sql/p0_invariants_v0.1.sql`
- `../tests/sql/folio_invariants_pre_v1.sql`
- `../tests/integration/resource_concurrency_pre_v1.py`
- `../tests/integration/financial_posting_pre_v1.py`
- `../tests/integration/idempotency_pre_v1.py`
- `../tests/integration/idempotency_business_effects_pre_v1.py`
- `../tests/integration/tenant_isolation_pre_v1.py`
- `../tests/integration/property_context_pre_v1.py`
- `../tests/integration/settlement_concurrency_pre_v1.py`
- `../tests/integration/folio_invariants_pre_v1.py`
- `../tests/integration/charge_reversal_pre_v1.py`

## RC1 object inventory at equivalence proof

Source patch-chain and flattened RC1 matched exactly at the inventory level:
- 92 ordinary tables,
- 20 views,
- 238 functions,
- 22 non-internal triggers,
- 659 constraints.

Inventory equality supplements, but does not replace, behavioral tests.

## Current semantic model highlights

### Accommodation capacity
- `PropertyStayPolicy` is versioned.
- canonical local night uses check-in D → checkout D+1.
- `overnight_anchor_time` attributes a commercial night after relocation.
- raw sellable capacity, commercial accommodation nights and physical utilization are separate.

### Financial Truth
- FinancialDocument, CashMovement, EconomicEvent and Allocation remain independent.
- POSTED economics are Allocation-driven.
- `effect_direction` preserves category while supporting reversals.
- every REVIEWED/POSTED EconomicEvent must belong to the matching FinancialPeriod.
- HARD_CLOSED periods are fail-closed against in-place historical mutation.
- one reporting currency per Property in Release 1.

### Commerce
- Folio balance is net Charges minus net collected Payments/Refunds.
- Payment history remains after Refund.
- CLOSED Folio must be commercially settled within tolerance.
- final Charges are immutable and corrected with explicit linked reversals.
- concurrent reversals serialize on the original Charge and cannot over-reverse it.

### Identity
- Guest identity resolution uses alias/provenance entities rather than destructive merge.

## Historical files

Do not include these in the current normal chain:
- `schema/osg_logical_schema_v0.1.sql`
- `proof/constraints_v0.1.sql`
- `proof/financial_posting_workflow_v0.1.sql`
- `seeds/glamping_nad_stawem_reference_v0.1.sql`

They remain architecture-evolution evidence.

## Next gate

Proceed from RC1 to a **real versioned migration chain and upgrade-path proof**. Do not modify posted financial history or silently replace accepted RC1 semantics while constructing migrations.
