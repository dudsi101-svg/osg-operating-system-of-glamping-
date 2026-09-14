# OSG — P0 Proof Execution Plan v0.1

Status: gotowy do wykonania w DEV
Data: 2026-09-14

## Cel

Przekształcić najważniejsze invariants OSG z dokumentacji w wykonywalne dowody przed Schema v1.0 FINAL.

## Environment

- PostgreSQL DEV instance
- schema candidate v0.95
- synthetic Glamping Nad Stawem seed
- isolated test database per CI job

## Suite A — Temporal integrity

A1. overlapping StaySegments same Unit rejected
A2. adjacent StaySegments accepted
A3. cancelled/non-active segment does not block future occupancy
A4. relocation creates second segment without rewriting first

## Suite B — Resource concurrency

B1. exclusive Resource two concurrent reservations → one success
B2. capacity Resource exact fill → success
B3. capacity overflow → reject
B4. expired hold ignored
B5. buffer overlap considered

## Suite C — Financial posting

C1. balanced allocations → POSTED
C2. imbalance → rollback
C3. allocation from another tenant → rollback
C4. posted event direct mutation → reject
C5. reversal creates linked corrective history
C6. duplicate command → deterministic no duplicate effect
C7. HARD_CLOSED period → posting/correction policy enforced

## Suite D — Settlements

D1. payer != bearer creates settlement
D2. repayment partially applies
D3. final repayment closes balance
D4. over-application rejected
D5. correction preserves conservation

## Suite E — Tenant isolation

E1. reservation ORG_A → unit ORG_B rejected
E2. allocation ORG_A → asset ORG_B rejected
E3. API read scope cannot access ORG_B
E4. background job without org scope rejected
E5. cache key collision cannot leak cross-tenant value

## Suite F — Idempotency

F1. duplicate webhook ×5 → one Reservation effect
F2. concurrent duplicate command → one aggregate mutation
F3. automation retry → one Turnover
F4. replay batch → no duplicated Charges/Payments
F5. duplicate posting command → one POSTED event

## Suite G — End-to-end reference scenarios

Run all scenarios from `docs/scenarios/OSG_End_to_End_Scenarios_v0.1.md`.

## Pass criteria

- 100% P0 tests passing
- zero cross-tenant leakage
- zero non-deterministic duplicate effects
- all rejected operations return stable OSG error code
- audit/domain event evidence exists for successful critical writes

## Failure handling

Any failed P0 test blocks Schema v1.0 FINAL.
Failure must produce one of:
- schema fix,
- domain service fix,
- corrected invariant,
- ADR if semantics change.