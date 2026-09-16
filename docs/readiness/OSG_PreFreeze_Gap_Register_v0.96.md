# OSG — Pre-Freeze Gap Register v0.96

Data aktualizacji: 2026-09-16
Status: PRE-FREEZE TECHNICAL PROOFS COMPLETE / RC CONSOLIDATION OPEN

## Purpose

Keep semantic, technical and discovery gaps explicit. A gap is not considered closed merely because documentation describes an intended solution. Technical gaps below are closed only where executable PostgreSQL evidence exists.

## A. Resolved model/semantic gaps

### GAP-001 — UUID strategy mismatch
Old proof used UUIDv4 DB defaults while domain docs required UUIDv7.
Resolution: ADR-007; application-generated UUIDv7, native PostgreSQL `uuid` storage.
Status: RESOLVED.

### GAP-002 — Prior-period adjustment lacked explicit historical-period reference
Resolution: v0.96 schema patch adds `relates_to_financial_period_id` + `adjustment_reason`; Scenario 10 and FinancialPeriod proof execute successfully.
Status: RESOLVED / EXECUTED.

### GAP-003 — Allocation could theoretically be inserted after EconomicEvent POSTED
Resolution: posted-allocation guard blocks INSERT/UPDATE/DELETE for a POSTED event; immutable-set proof passes.
Status: RESOLVED / EXECUTED.

### GAP-004 — Full refund could leave Folio commercially outstanding
Resolution: original Charge + linked reversing Charge + Refund preserve history and return Folio balance to zero; executable Folio proof passes.
Status: RESOLVED / EXECUTED.

### GAP-005 — Capacity > 1 Resource not enforceable via simple exclusion constraint
Resolution: transactional Resource row lock + capacity guard; EXCLUSIVE retains exclusion constraint as defense-in-depth. True-concurrency proof passes.
Status: RESOLVED / EXECUTED.

### GAP-006 — Mixed accounting/cash cost vs economic business relevance
Resolution: EconomicEvent + multi-dimensional Allocation + NON_BUSINESS + confidence/rationale. Scenario 04 executes.
Status: RESOLVED / EXECUTED.

### GAP-007 — One invoice containing CAPEX and OPEX
Resolution: FinancialDocumentLine → separate EconomicEvents/Allocations. Scenario 05 executes.
Status: RESOLVED / EXECUTED.

### GAP-008 — Historical unit relocation
Resolution: one Stay + multiple StaySegments; Reservation history remains unchanged. Scenario 06 executes.
Status: RESOLVED / EXECUTED.

### GAP-009 — OTA gross revenue vs net payout
Resolution: Charges/Payment/OTA clearing/CashMovement/commission EconomicEvent/Reconciliation remain separate. Scenario 02 executes.
Status: RESOLVED / EXECUTED.

### GAP-010 — Operator-funded expense and settlement
Resolution: `paid_by` vs `economic_bearer`, SettlementEntry + SettlementApplication. Scenario 03 plus true-concurrency Settlement conservation proof pass.
Status: RESOLVED / EXECUTED.

### GAP-011 — Polymorphic ExternalReference could target another tenant
Discovered by Issue #4 runtime proof. Composite FKs could not protect a polymorphic `osg_entity_id` target.
Resolution: explicit fail-closed tenant-target guard for supported OSG entity types; ORG_A → ORG_B mapping is rejected.
Status: RESOLVED / EXECUTED.

### GAP-012 — Concurrent Charge reversals could exceed original amount
Discovered by Issue #11 true-concurrency proof. `FOR SHARE` allowed two -600 reversals against original +1000 to both commit because both transactions could inspect the same pre-commit reversible balance.
Resolution: original Charge is now the row-level serialization point using `FOR UPDATE`; rerun proves exactly one concurrent reversal commits and the loser receives `OSG_CHARGE_OVER_REVERSED`.
Status: RESOLVED / EXECUTED.

## B. P0 technical proof gates — COMPLETE

### P0-001 StaySegment temporal overlap — PASS
Owner: Issue #1 — CLOSED.
Evidence: active overlap rejects, adjacency accepted, cancelled semantics accepted, stable overlap mapping.

### P0-002 Resource concurrency — PASS
Owner: Issue #2 — CLOSED.
Evidence: true concurrent EXCLUSIVE and capacity arithmetic, expiry and buffers.

### P0-003 Atomic Financial posting — PASS
Owner: Issue #3 — CLOSED.
Evidence: balanced atomic post, rollback, immutable POSTED facts, reversal, FinancialPeriod/HARD_CLOSED, duplicate-post one effect.

### P0-004 Tenant isolation — PASS
Owner: Issue #4 — CLOSED.
Evidence: DB relationship guards + runtime-role RLS + fail-closed worker + ExternalReference guard + security-audit evidence.

### P0-005 Idempotency — PASS
Owner: Issue #5 — CLOSED.
Evidence: concurrent claims, PMS replay, command replay/payload mismatch, automation retry, Financial posting retry and one business effect.

### P0-006 Same-tenant cross-Property integrity — PASS
Owner: Issue #9 — CLOSED.
Evidence: invalid Property A → Property B relationships fail while explicit Organization-level facts remain valid.

### P0-007 Settlement conservation — PASS
Owner: Issue #14 — CLOSED.
Evidence: exact 430 = 200 + 230, over-application rejection and true one-winner concurrency.

### P0-008 Canonical clean-load/reference scenarios — PASS
Owner: Issue #8 — CLOSED.
Evidence: full current pre-v1 chain, reference configuration, scenarios and invariant suite run successfully on PostgreSQL 16.

Latest full proof after all evidence-backed repairs: GitHub Actions run `35093917785` — PASS.

## C. P1 commerce proof gates completed before live payments

### P1-COM-001 Folio balance/currency/refund invariants — PASS
Owner: Issue #10 — CLOSED.

### P1-COM-002 Charge immutability/reversal conservation — PASS
Owner: Issue #11 — CLOSED.
Includes true-concurrency reversal conservation after GAP-012 repair.

## D. Open external discovery

### DISC-001 Actual reservation/PMS/channel flow
Issue #6 — OPEN.
Not a Core-schema blocker unless discovery reveals a genuinely missing semantic concept.

### DISC-002 Bank/cash import path
Issue #7 — OPEN.
Need first concrete import adapter/dedup/reconciliation mapping.

## E. Configuration/legal gaps — not current Core-schema blockers

### CFG-001 Approval amount thresholds
Mechanism defined; actual values pending owner policy.

### CFG-002 CAPEX small-asset threshold
Mechanism defined; value pending finance/accounting policy.

### CFG-003 Retention periods
Data lifecycle model defined; exact periods require legal/accounting validation.

### CFG-004 Channel commission configuration
Requires actual commercial terms.

## F. Remaining P1 implementation/design gaps

### P1-001 Charge arithmetic / rounding
`gross_amount` is authoritative commercial amount. `quantity × unit_price` still needs a versioned rounding/remainder contract before production invoicing/report detail depends on nightly arithmetic.

### P1-002 Commercial snapshot normalization
Current pre-v1 model uses selected JSON fields for policy/pricing snapshots. First real PMS payload should determine whether some fields deserve relational normalization. Do not vendor-model the Core prematurely.

### P1-003 Economic bearer production identity
Reference scenarios use a synthetic Party for the glamping business. Production implementation must map the actual legal/economic entity rather than equating Organization or owner-person with the business automatically.

### P1-004 Production-wide RLS coverage
Critical runtime-role proof is green. Production migrations still need systematic RLS application/verification for all tenant-owned tables.

### P1-005 Audit data redaction
Audit schema exists, but field-specific redaction policy is required before real PII.

### P1-006 Outbox worker operations
Atomic outbox creation/idempotency is proven. Production worker locking, batching, retry/backoff and poison-event operations remain implementation work.

## G. RC / consolidation gaps — blockers for `Schema v1.0 FINAL`

### RC-001 Consolidated v1.0 DDL
Current accepted truth is still represented as v0.95 base + additive/pre-v1 patches.
Need one clean canonical Schema v1.0 Candidate baseline without duplicated/replaced definitions.
Status: OPEN.

### RC-002 Consolidated-schema behavioral equivalence
Need clean-load + full regression/concurrency/RLS proof against the consolidated candidate itself, not only the historical patch chain.
Status: OPEN.

### RC-003 Production migration chain / upgrade path
Need versioned migrations and proof that an existing supported schema can upgrade to v1 without data/invariant loss.
Status: OPEN.

### RC-004 Independent freeze review
PR/schema candidate needs independent review before merge/final tag; writer does not self-merge.
Status: OPEN.

## H. Freeze policy

The original pre-freeze technical P0 proof set is now **PASS**.

`Schema v1.0 FINAL` is still withheld because the accepted behavior must be consolidated into a canonical v1 baseline and proven through a real migration/upgrade path plus production-wide RLS review.

Current verdict: **eligible to enter Schema v1.0 RC consolidation; NOT FINAL.**
