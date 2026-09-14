# OSG — Schema Freeze Assessment v0.95

Data: 2026-09-14
Status: CONDITIONAL GO / NOT FINAL

## Executive conclusion

Model domenowy OSG jest wystarczająco spójny, aby traktować Schema Candidate v0.9 jako stabilną bazę implementacyjną. Nie ma obecnie znanej nierozwiązanej sprzeczności semantycznej klasy P0.

Nie ogłaszamy jeszcze `Schema v1.0 FINAL`, ponieważ część invariantów musi zostać udowodniona wykonywalnie w PostgreSQL/backendzie.

## 1. Conceptual gates

PASS — Organization/tenant boundary
PASS — Property/Unit/Resource/Asset separation
PASS — Reservation vs Stay
PASS — StaySegment relocation history
PASS — Folio/Charge/Payment separation
PASS — Payment vs CashMovement
PASS — FinancialDocument/CashMovement/EconomicEvent/Allocation separation
PASS — CAPEX/OPEX semantics
PASS — Settlement payer/bearer semantics
PASS — Resource concurrency policy
PASS — Availability conflict policy
PASS — Prepayment/refund/OTA clearing semantics
PASS — approval framework
PASS — Domain Events + idempotency contract
PASS — API/error/state-machine boundaries

## 2. P0 executable gates

PENDING EXECUTION — no overlapping StaySegments
PENDING EXECUTION — exclusive Resource concurrency
PENDING EXECUTION — capacity Resource concurrency
PENDING EXECUTION — atomic Financial posting
PENDING EXECUTION — posted financial immutability
PENDING EXECUTION — Settlement conservation
PENDING EXECUTION — cross-tenant references
PENDING EXECUTION — integration idempotency
PENDING EXECUTION — automation idempotency

## 3. External discovery gates

NOT BLOCKING schema core, but blocking production integration:
- real PMS/reservation source unknown,
- exact bank import path unknown,
- channel commission details not configured,
- actual payment provider flow not confirmed.

Adapters must absorb provider differences; Core schema should not wait for a vendor choice unless discovery exposes a missing semantic concept.

## 4. Legal/configuration gates

Still configurable/open, not core-schema blockers:
- retention periods,
- approval amount thresholds,
- CAPEX small-asset threshold,
- accounting/tax export specifics.

## 5. Freeze recommendation

Use `v0.95` as PRE-FREEZE baseline.
All new model changes must now classify themselves as:
- bug fix,
- clarification,
- additive non-breaking extension,
- breaking change.

Breaking change requires ADR and explicit justification against existing scenarios/test vectors.

## 6. Conditions for Schema v1.0 FINAL

1. P0 executable suite passes.
2. At least 12 reference scenarios pass against schema/service layer.
3. Tenant isolation proof passes.
4. Financial posting proof passes under concurrent/retry conditions.
5. No new P0 semantic gap is discovered.
6. PROJECT_INDEX marks canonical v1.0 artifacts.

## 7. Decision

Current status:

**GO** — implementation proof, migrations in DEV, contract tests, API scaffolding.

**NO-GO** — production data, live bank/PMS writes, final schema declaration, autonomous financial AI writes.