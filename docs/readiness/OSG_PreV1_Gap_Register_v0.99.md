# OSG — Pre-v1 Gap Register v0.99

Date: 2026-09-15
Status: ACTIVE / canonical readiness register

## Purpose

A gap is closed only when the required level is satisfied:
- **SEMANTIC** — business meaning resolved,
- **SCHEMA** — represented/protected in pre-v1 DDL,
- **EXECUTED** — verified in real PostgreSQL/runtime,
- **DISCOVERED** — validated against real Glamping Nad Stawem workflow/data.

Documentation alone does not equal EXECUTED.

---

# A. Semantics resolved + represented in schema/artifacts

## GAP-001 UUID strategy
Application-generated UUIDv7; DB native uuid.
Status: SEMANTIC+SCHEMA. Execution trivial/pending app implementation.

## GAP-002 Financial Truth layer separation
FinancialDocument ≠ CashMovement ≠ EconomicEvent ≠ Allocation.
Status: SEMANTIC+SCHEMA.

## GAP-003 CAPEX/OPEX at Allocation level
One invoice can contain multiple economic classifications.
Status: SEMANTIC+SCHEMA; Scenario 05.

## GAP-004 business/private mixed allocation
NON_BUSINESS excluded from Property economic result; confidence/rationale preserved.
Status: SEMANTIC+SCHEMA; Scenario 04.

## GAP-005 paid_by vs economic_bearer / settlements
SettlementEntry derived from payer/bearer mismatch; applications conserve repayment.
Status: SEMANTIC+SCHEMA; execution proof pending.

## GAP-006 OTA gross vs net payout
Guest revenue, commission, clearing and bank payout remain distinct.
Status: SEMANTIC+SCHEMA; Scenario 02.

## GAP-007 Reservation vs Stay / relocation
One Stay may contain multiple StaySegments; history not overwritten.
Status: SEMANTIC+SCHEMA; overlap/concurrency execution pending.

## GAP-008 temporary Unit unavailability vs lifecycle
Unit lifecycle = PLANNED/ACTIVE/RETIRED. Temporary OOS = AvailabilityBlock.
Status: SEMANTIC+SCHEMA (ADR-012).

## GAP-009 sellability impact semantics
AvailabilityBlock explicitly states sellability/operations/guest impact.
Status: SEMANTIC+SCHEMA.

## GAP-010 stay policy historical semantics
Versioned PropertyStayPolicy defines check-in/out/readiness/overnight anchor.
Overlapping active policy ranges forbidden.
Status: SEMANTIC+SCHEMA; actual GNS times DISCOVERY pending.

## GAP-011 commercial accommodation night vs physical utilization
Commercial night separated from raw StaySegment physical use; relocation uses overnight anchor.
Status: SEMANTIC+SEMANTIC_SQL. Runtime validation pending.

## GAP-012 Financial period assignment and closure
Every reviewed/posted EconomicEvent belongs to unique matching FinancialPeriod; period ranges cannot overlap; HARD_CLOSED history is immutable in-place.
Status: SEMANTIC+SCHEMA; execution pending.

## GAP-013 prior-period adjustments/reversals
Current-period event can reference historical period; effect_direction NORMAL/REVERSAL preserves economic category polarity.
Status: SEMANTIC+SCHEMA; execution pending.

## GAP-014 Property reporting currency
Release 1: one reporting currency per Property; POSTED Property EconomicEvent must use it.
Status: SEMANTIC+SCHEMA.

## GAP-015 same-tenant cross-Property integrity
Critical relationships cannot mix Property A and Property B inside one Organization.
Status: SEMANTIC+SCHEMA guards; Issue #9 execution pending.

## GAP-016 Folio settlement semantics
Net Charges − (gross Payments − Refunds); Payment history preserved after Refund; CLOSED requires near-zero balance.
Status: SEMANTIC+SCHEMA; Issue #10 execution pending.

## GAP-017 generic command idempotency
CommandIdempotency ledger complements integration/automation ledgers.
Status: SEMANTIC+SCHEMA; concurrency execution pending.

## GAP-018 Guest identity merge provenance
Non-destructive alias/candidate/merge-event model; Repeat Guest resolves canonical identity.
Status: SEMANTIC+SCHEMA; production match thresholds pending.

## GAP-019 semantic KPI definitions
Occupancy, ADR, RevPAR, TRevPAR, Unit/Stay economics, cash, settlements and confidence have canonical semantic SQL/contracts.
Status: SEMANTIC_SQL; PostgreSQL runtime execution pending.

---

# B. P0 executable gates — BLOCK Schema v1 FINAL

## P0-001 StaySegment temporal overlap
Issue #1.
Need real PostgreSQL exclusion/concurrency proof + stable error mapping.

## P0-002 Resource capacity concurrency
Issue #2.
Need multiple simultaneous connections/transactions; exactly-one acceptance / capacity arithmetic under lock.

## P0-003 Atomic Financial Truth posting
Issue #3.
Must cover:
- balance conservation,
- rollback on failure,
- immutable POSTED data,
- FinancialPeriod assignment,
- HARD_CLOSED reject,
- current-period reversal/adjustment,
- DomainEvent+Outbox atomicity,
- duplicate command single effect.

## P0-004 Tenant isolation
Issue #4.
Need realistic runtime DB role/RLS + API + job tests. Owner/superuser tests do not count.

## P0-005 Integration/automation/command idempotency
Issue #5.
Need concurrent claims/replay/retry proof.

## P0-006 Clean load current pre-v1 graph
Issue #8.
Need zero-to-loaded PostgreSQL execution of schema, patches, guards, semantic layer, reference config and scenarios.

## P0-007 Same-tenant cross-Property isolation
Issue #9.
Need negative/positive tests against guards and API mapping.

Current Schema v1 FINAL verdict: **NO-GO until P0-001..007 PASS.**

---

# C. P1 execution before live guest/financial operations

## P1-001 Folio invariants
Issue #10.
Payment/refund currency, over-refund, close balance, controlled reopen.

## P1-002 Commercial accommodation-night edge cases
Need executable tests for:
- relocation before/after overnight anchor,
- late checkout,
- very late arrival,
- early departure,
- unresolved segment at anchor,
- active/provisional Stay.

## P1-003 Guest merge/undo
Need tests preventing cycles/chains and proving repeat-guest analytics after merge/undo.

## P1-004 Audit redaction
Field-level policy before real guest PII/financial sensitive values enter audit logs.

## P1-005 Outbox worker
Locking, batching, retry and poison-event handling need runtime implementation.

## P1-006 RLS coverage automation
Production migration/test tooling must ensure every tenant-owned table receives expected RLS policy.

---

# D. Real Glamping Nad Stawem discovery

## DISC-001 Reservation/PMS/channel flow
Issue #6.
Need actual PMS/channel manager/API/export/webhook path.
Not a Core blocker unless a missing business concept is discovered.

## DISC-002 Bank/cash import
Issue #7.
Need bank/source inventory and first import format/API strategy.

## DISC-003 Actual PropertyStayPolicy
Confirm:
- check-in time,
- checkout time,
- cleaning/readiness buffer,
- overnight attribution anchor policy if operationally relevant.
Current 15:00/11:00/03:00 are fixtures only.

## DISC-004 Actual economic/legal Party model
Reference data uses synthetic identities. Production must map:
- legal invoice recipient,
- economic glamping business bearer,
- owner/investor,
- operator,
without equating Organization automatically to a legal person.

## DISC-005 Real payment/refund flow
Need actual terminal/payment provider/OTA/prepayment behavior before live Folio automation.

---

# E. Owner/configuration decisions — mechanisms exist, values pending

## CFG-001 Approval thresholds
Amounts/risk thresholds for manual allocation, reversal, settlement correction, sensitive export.

## CFG-002 CAPEX small-asset threshold
Mechanism exists; actual policy pending finance/accounting context.

## CFG-003 Retention periods
Lifecycle model exists; exact periods require legal/accounting validation.

## CFG-004 Actual OTA commission rules
Versioned CommissionRule exists; commercial terms pending.

## CFG-005 Rate/pricing source
Need actual source-of-truth before publishing/automating price changes.

---

# F. Deliberately deferred from Release 1 Core

- full tax/VAT accounting engine,
- depreciation accounting as statutory accounting,
- native iOS/Android,
- own Channel Manager,
- own full Booking Engine,
- autonomous dynamic-pricing writes,
- payroll/HR,
- advanced warehouse/WMS,
- multi-currency managerial accounting/FX engine,
- enterprise tenant billing.

These are not gaps if Release 1 boundary remains unchanged.

---

# G. Promotion rule

`Schema v1.0 FINAL` requires:
1. P0 executable gates PASS,
2. no newly discovered semantic P0,
3. current patches consolidated into one clean canonical DDL,
4. real migration chain generated and tested from zero,
5. Semantic Layer smoke tests PASS,
6. schema/API/event versions pinned,
7. checkpoint and tag created.

External discovery may continue after Schema v1 if it maps cleanly to existing canonical contracts.
