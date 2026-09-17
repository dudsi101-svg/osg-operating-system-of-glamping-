# OSG — RC1 Database Function Promotion Register v0.1

Data: 2026-09-16
Status: RC1 DECISION RECORD
Scope: objects historically developed under `database/proof/` that are present or intentionally absent from `database/rc/osg_schema_v1_rc1.sql`.

## Purpose

The pre-freeze phase used `database/proof/` as an executable proving ground. Some objects created there are no longer merely test helpers: the accepted runtime invariants depend on them. This register makes that boundary explicit without rewriting already-proven semantics during RC consolidation.

The canonical RC1 DDL is generated from the accepted patch chain and proven byte-equivalent/behaviorally equivalent by GitHub Actions Issue #15.

## PROMOTED — runtime-candidate database functions

### `osg_assert_payment_not_overallocated(p_payment_id uuid)`
Historical source: `database/proof/financial_conservation_guards_v0.1.sql`.

Decision: **PROMOTE TO RC1 RUNTIME CANDIDATE**.

Reason: Payment allocation conservation is a business invariant. The function is part of the accepted write workflow/guard surface and must not be treated as disposable test scaffolding.

### `osg_assert_settlement_not_overapplied(p_settlement_id uuid)`
Historical source: `database/proof/financial_conservation_guards_v0.1.sql`.

Decision: **PROMOTE TO RC1 RUNTIME CANDIDATE**.

Reason: Settlement conservation must remain transactionally enforceable. True-concurrency proof demonstrates that it is part of correctness, not merely observability.

### `osg_assert_resource_capacity(...)`
Historical source: `database/proof/resource_capacity_guard_v0.1.sql`.

Decision: **PROMOTE TO RC1 RUNTIME CANDIDATE**.

Reason: Resource row serialization is the accepted normal-path mechanism for exclusive/capacity reservation safety. The GiST/exclusion layer alone is not the application concurrency contract.

Requirement: the assertion and corresponding `ResourceReservation` mutation must execute in the same database transaction.

### `osg_post_economic_event_v02(...)`
Historical source: `database/proof/financial_posting_workflow_v0.2.sql`.

Decision: **PROMOTE TO RC1 RUNTIME CANDIDATE**.

Reason: this is the accepted atomic Financial Truth posting workflow: aggregate lock, allocation conservation, FinancialPeriod resolution, HARD_CLOSED validation, POSTED transition, DomainEvent and Outbox append.

Name note: the historical `_v02` identifier is retained in RC1 to avoid an unproven rename during consolidation. A production naming cleanup, if desired, must be an explicit migration with compatibility proof.

## INCLUDED READ HELPER — not itself a correctness boundary

### `osg_charge_applied_amount(p_charge_id uuid)`
Historical source: `database/proof/financial_conservation_guards_v0.1.sql`.

Decision: **KEEP IN RC1 AS READ/DERIVATION HELPER**.

It may support diagnostics/projections, but it must not be interpreted as the complete Charge/Folio correction invariant. Charge immutability and reversal conservation are enforced by the dedicated pre-v1 Charge guards proven under Issue #11.

## NOT PROMOTED from historical proof files

### `database/proof/tenant_rls_v0.1.sql`
Decision: **TEST/PROTOTYPE ONLY — NOT PRODUCTION RLS BASELINE**.

Reason: it intentionally covers only selected critical tables and explicitly states that production policy must cover all tenant-owned tables. Runtime-role RLS behavior is proven in CI, but production-wide RLS rollout remains separate gate RC-005.

Therefore absence of these proof policies from the flattened RC1 baseline is intentional, not a regression.

### `database/proof/constraints_v0.1.sql`
Decision: **HISTORICAL MODEL PROOF ONLY**.

Reason: it targets an older pluralized proof schema and is not part of the accepted current clean-load chain. Current constraints/guards in the canonical schema supersede it.

### `database/proof/financial_posting_workflow_v0.1.sql`
Decision: **HISTORICAL / SUPERSEDED BY v0.2**.

It is not loaded into RC1 and must not be reintroduced alongside the accepted v0.2 workflow.

## Source-path policy

During RC1, the historical source files remain in `database/proof/` to preserve evolution evidence. Their directory name is no longer authoritative for runtime classification; this register and the canonical RC1 DDL are authoritative.

Before Schema v1.0 FINAL / production migrations:

1. production migrations must explicitly create the promoted runtime functions;
2. test-only RLS proof artifacts must not be copied wholesale into production migrations;
3. production-wide RLS must be generated/reviewed separately;
4. any rename/signature change of promoted functions requires migration + compatibility/invariant proof;
5. removing a promoted function requires proving an equivalent replacement enforcement path.

## Evidence

Issue #15 deterministic equivalence run: `35113431149` — PASS.

Canonical generated schema SHA-256:
`4c43fa53da21192b4160936b26770a1d9845acc5780f3d2c4d4b32a0be589f0d`

Canonical RC1 path:
`database/rc/osg_schema_v1_rc1.sql`

## Verdict

The RC1 baseline may legitimately contain functions born in the proof phase when executable evidence established them as required runtime invariants. Test/prototype artifacts remain excluded unless promoted explicitly through a later gate.
