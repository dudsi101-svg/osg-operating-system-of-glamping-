# OSG — Pre-Freeze Gap Register v0.96

Data: 2026-09-14
Status: ACTIVE

## Purpose

Keep semantic, technical and discovery gaps explicit. A gap is not considered closed merely because documentation describes an intended solution.

## A. Resolved conceptually and reflected in artifacts

### GAP-001 — UUID strategy mismatch
Old proof used UUIDv4 DB defaults while domain docs required UUIDv7.
Resolution: ADR-007; application-generated UUIDv7, native PostgreSQL `uuid` storage.
Status: RESOLVED_CONCEPTUALLY.

### GAP-002 — Prior-period adjustment lacked explicit historical-period reference
Resolution: v0.96 schema patch adds `relates_to_financial_period_id` + `adjustment_reason`.
Validated by Scenario 10.
Status: RESOLVED_CONCEPTUALLY / PENDING_EXECUTION.

### GAP-003 — Allocation could theoretically be inserted after EconomicEvent POSTED
Resolution: v0.96 financial guard patch blocks INSERT/UPDATE/DELETE allocations for POSTED event.
Status: RESOLVED_CONCEPTUALLY / PENDING_EXECUTION.

### GAP-004 — Full refund could leave Folio commercially outstanding
Resolution: Scenario 07 uses linked reversing Charge plus Refund; payment history remains intact.
Status: RESOLVED_CONCEPTUALLY / PENDING_EXECUTION.

### GAP-005 — Capacity > 1 Resource not enforceable via simple exclusion constraint
Resolution: transactional Resource row lock + capacity guard; exclusive resources retain exclusion constraint.
Status: RESOLVED_CONCEPTUALLY / CONCURRENCY_PROOF_PENDING.

### GAP-006 — Mixed accounting/cash cost vs economic business relevance
Resolution: EconomicEvent + multi-dimensional Allocation + NON_BUSINESS + confidence/rationale.
Scenario 04 validates representation.
Status: RESOLVED_CONCEPTUALLY.

### GAP-007 — One invoice containing CAPEX and OPEX
Resolution: FinancialDocumentLine → separate EconomicEvents/Allocations.
Scenario 05.
Status: RESOLVED_CONCEPTUALLY.

### GAP-008 — Historical unit relocation
Resolution: one Stay + multiple StaySegments; Reservation history remains unchanged.
Scenario 06.
Status: RESOLVED_CONCEPTUALLY.

### GAP-009 — OTA gross revenue vs net payout
Resolution: Charges/Payment/OTA clearing/CashMovement/commission EconomicEvent/Reconciliation remain separate.
Scenario 02.
Status: RESOLVED_CONCEPTUALLY.

### GAP-010 — Operator-funded expense and settlement
Resolution: `paid_by` vs `economic_bearer`, SettlementEntry + SettlementApplication.
Scenario 03.
Status: RESOLVED_CONCEPTUALLY.

## B. Open P0 technical proofs

### P0-001 StaySegment temporal overlap
Owner: GitHub Issue #1
Need: real PostgreSQL exclusion test + error mapping.

### P0-002 Resource concurrency
Owner: Issue #2
Need: two concurrent DB transactions; exactly one winner for exclusive; capacity arithmetic under lock.

### P0-003 Atomic Financial posting
Owner: Issue #3
Need: balanced/imbalanced/concurrent/retry/closed-period tests.

### P0-004 Tenant isolation
Owner: Issue #4
Need: composite FK + realistic runtime role RLS + API/background-job tests.

### P0-005 Idempotency
Owner: Issue #5
Need: concurrent claims, webhook replay, automation retry, posting retry.

## C. Open external discovery

### DISC-001 Actual reservation/PMS/channel flow
Issue #6.
Not a Core-schema blocker unless discovery reveals a genuinely missing semantic concept.

### DISC-002 Bank/cash import path
Issue #7.
Need first concrete import adapter/dedup/reconciliation mapping.

## D. Configuration/legal gaps — not core schema blockers

### CFG-001 Approval amount thresholds
Mechanism defined; actual values pending owner policy.

### CFG-002 CAPEX small-asset threshold
Mechanism defined; value pending finance/accounting policy.

### CFG-003 Retention periods
Data lifecycle model defined; exact periods require legal/accounting validation.

### CFG-004 Channel commission configuration
Requires actual commercial terms.

## E. P1 technical/design items

### P1-001 Charge arithmetic / rounding
`gross_amount` is authoritative commercial amount. `quantity × unit_price` may require explicit rounding/remainder rules for nightly breakdown. Need a versioned rounding contract before production invoicing/report detail depends on it.

### P1-002 Commercial snapshot normalization
Current v0.95 uses selected JSON fields for policy/pricing snapshots. First real PMS payload should determine whether some fields deserve relational normalization. Must not prematurely vendor-model the Core.

### P1-003 Economic bearer production identity
Reference scenarios use a synthetic Party for the glamping business. Production implementation must map the actual legal/economic entity rather than equating Organization or owner-person with the business automatically.

### P1-004 RLS coverage automation
Proof covers critical tables only. Production migrations should apply/test tenant policies consistently to all tenant-owned tables.

### P1-005 Audit data redaction
Audit schema exists, but field-specific redaction policy needs implementation before real PII is used.

### P1-006 Outbox worker semantics
Contract exists; actual locking, batching and poison-event handling need implementation proof.

## F. Freeze policy

Schema v1.0 FINAL requires all P0 technical proofs PASS.
P1 items may remain configurable/additive only if they do not invalidate core entity boundaries or P0 invariants.

Current verdict: **v0.96 semantic candidate stable; technical proof pending.**
