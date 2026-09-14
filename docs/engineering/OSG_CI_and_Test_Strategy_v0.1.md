# OSG — CI & Test Strategy v0.1

Status: roboczy zaawansowany
Data: 2026-09-14

## 1. Cel

CI ma chronić semantykę OSG, nie tylko składnię kodu.

## 2. Poziomy testów

### L0 — Static
- lint
- formatting
- type checking
- OpenAPI/schema validation
- JSON Schema validation
- migration naming

### L1 — Database invariants
- clean schema apply
- migration upgrade path
- seed apply
- exclusion constraints
- cross-tenant leakage tests
- posted financial immutability
- full allocation invariant
- idempotency uniqueness

### L2 — Domain tests
- state machine legal/illegal transitions
- posting/reversal flows
- settlement derivation
- availability conflict resolution
- payment/refund/deposit semantics

### L3 — Contract tests
- API request/response contracts
- event envelope compatibility
- integration adapter canonical mapping
- permission enforcement

### L4 — End-to-end reference scenarios
Minimum 12 canonical scenarios from docs/scenarios.

### L5 — Security/data isolation
- tenant boundary
- role boundary
- field-level restrictions
- AI_SERVICE permission inheritance

## 3. Required CI gates before merge

P0:
- schema applies from empty DB
- schema upgrades from previous version
- invariant suite green
- permission isolation green
- no breaking API/event change without version bump

P1:
- reference dataset loads
- canonical scenarios pass
- metric smoke tests pass

## 4. CI matrix

Jobs:
1. static
2. db-schema
3. db-invariants
4. domain-tests
5. api-contracts
6. security-tests
7. scenario-tests

Merge requires all P0 jobs green.

## 5. Test data

No real guest PII in CI.
Use deterministic synthetic fixtures.
Reference property dataset: Glamping Nad Stawem synthetic model.

## 6. Financial test rules

Every Financial Truth change must include tests for:
- accounting view unaffected where applicable
- cash view unaffected where applicable
- economic view expected delta
- reversal path
- explainability chain

## 7. Migration tests

Each migration PR must prove:
- apply on empty database
- upgrade from previous schema
- rollback or recovery plan
- seed compatibility
- no tenant boundary regression

## 8. Flaky test policy

Flaky P0 test = defect.
No permanent rerun-until-green workaround.

## 9. Agent workflow

Agent modifying a domain must update or add tests in the same PR unless change is documentation-only.
Independent reviewer checks semantic coverage, not just green status.
