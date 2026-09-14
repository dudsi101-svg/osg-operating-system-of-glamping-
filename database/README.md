# OSG Database — PRE-V1 Guide

Status: semantic candidate approaching v1 freeze; executable proof pending
Date: 2026-09-15

## Important

Everything under `database/schema`, `database/proof`, `database/semantic` and `database/seeds` is still DEV/pre-freeze material. It is **not yet the production migration chain**.

Do not mark Schema v1.0 FINAL until P0 executable proofs pass.

## Clean DEV load order

### A. Base relational schema
1. `schema/osg_schema_v0.95_core.sql`
2. `schema/osg_schema_v0.95_extensions.sql`
3. `schema/osg_schema_v0.95_supporting.sql`

### B. Core semantic/invariant patches discovered during validation
4. `schema/osg_schema_v0.96_patch.sql`
5. `schema/osg_schema_v0.96_financial_guard_patch.sql`
6. `schema/osg_schema_v0.96_stay_policy_patch.sql`
7. `schema/osg_schema_v0.97_availability_impact_patch.sql`
8. `schema/osg_schema_v0.98_economic_direction_patch.sql`
9. `schema/osg_schema_v0.99_property_context_guards.sql`

### C. Pre-v1 hardening patches
10. `schema/osg_schema_pre_v1_closed_period_guard_patch.sql`
11. `schema/osg_schema_pre_v1_financial_period_assignment_patch.sql`
12. `schema/osg_schema_pre_v1_command_idempotency_patch.sql`
13. `schema/osg_schema_pre_v1_reporting_currency_guard.sql`
14. `schema/osg_schema_pre_v1_guest_identity_resolution.sql`
15. `schema/osg_schema_pre_v1_guest_alias_guards.sql`
16. `schema/osg_schema_pre_v1_overnight_anchor_patch.sql`

### D. Semantic Folio prerequisite + Folio guards
17. `semantic/osg_semantic_folio_v0.1.sql`
18. `schema/osg_schema_pre_v1_folio_guards.sql`

`Folio` close guard queries the canonical Folio-balance semantic view, so this order is intentional.

### E. Hard-invariant proof functions/guards
19. `proof/financial_conservation_guards_v0.1.sql`
20. `proof/resource_capacity_guard_v0.1.sql`
21. `proof/financial_posting_workflow_v0.2.sql`
22. `proof/tenant_rls_v0.1.sql` — only in a dedicated runtime-role/RLS proof environment

`financial_posting_workflow_v0.1.sql` is historical/obsolete.

### F. Remaining semantic/read layer
23. `semantic/osg_semantic_occupancy_v0.1.sql` — content semantics v0.2
24. `semantic/osg_semantic_accommodation_nights_v0.1.sql`
25. `semantic/osg_semantic_financial_truth_v0.1.sql` — content semantics v0.2
26. `semantic/osg_semantic_cash_v0.1.sql`
27. `semantic/osg_semantic_revenue_v0.1.sql` — content semantics v0.3
28. `semantic/osg_semantic_operations_v0.1.sql`
29. `semantic/osg_semantic_guest_v0.1.sql`
30. `semantic/osg_data_quality_checks_v0.1.sql`
31. `semantic/osg_data_quality_accommodation_nights_v0.1.sql`

### G. Reference configuration
32. `seeds/glamping_nad_stawem_master_v0.95.sql`
33. `seeds/glamping_nad_stawem_stay_policy_v0.97.sql` — file name historical; content includes v0.98 overnight anchor fixture
34. `seeds/glamping_nad_stawem_financial_periods_v0.99.sql`

### H. Reference business scenarios
35+. one or more scenario seeds/tests.

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
- `scenario_10_late_invoice_closed_period_v0.96.sql` — content aligned to shared period fixture
- `scenario_12_turnover_at_risk_v0.96.sql`

Negative/transactional tests:
- `tests/sql/scenario_11_resource_capacity_v0.96.sql`
- `tests/sql/p0_invariants_v0.1.sql`
- `tests/sql/folio_invariants_pre_v1.sql`

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

### Identity
- Guest identity resolution uses alias/provenance entities rather than destructive merge.

## P0 proof rule

A valid scenario seed proves representability, not concurrency/invariant correctness.

Schema v1.0 FINAL requires executable validation from:
- `../tests/specs/OSG_P0_Proof_Execution_Plan_v0.1.md`
- Issues #1–#5, #8 and #9

Critical proof families:
1. temporal StaySegment overlap,
2. Resource capacity concurrency,
3. atomic Financial Truth posting + immutable posted facts + FinancialPeriod behavior,
4. tenant isolation using realistic DB/API/background-job identities,
5. idempotent integrations/automations/commands,
6. same-tenant cross-Property integrity,
7. clean-load all schema/semantic/fixture artifacts.

P1 live-commerce proof:
- Issue #10 Folio currency/refund/close invariants.

## Runtime roles / RLS

RLS must be tested using a realistic application DB role. Table owner/superuser execution does not constitute tenant-isolation proof.

## Historical files

Do not include in normal current load:
- `schema/osg_logical_schema_v0.1.sql`
- `proof/financial_posting_workflow_v0.1.sql`
- `seeds/glamping_nad_stawem_reference_v0.1.sql`

They remain only as architecture-evolution evidence.

## Promotion to v1

After all P0 proofs pass:
1. consolidate v0.95 + accepted patches into clean canonical v1.0 DDL,
2. remove replaced duplicate trigger/helper definitions,
3. create real versioned migrations,
4. run clean-load + upgrade-path + concurrency + RLS tests,
5. pin Semantic Layer and Metric Dictionary v1,
6. create Schema v1.0 FINAL checkpoint/tag.
