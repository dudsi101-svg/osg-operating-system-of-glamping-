# OSG — Pre-Build Gap Register v0.2

Status: aktywny
Data: 2026-09-14

## Zmiany względem v0.1

Projektowo rozwiązano GAP-002, GAP-003, GAP-004 oraz przygotowano techniczną strategię dla GAP-012..015. Nie oznacza to jeszcze produkcyjnego zamknięcia — wymagane są testy/proof.

| ID | Gap | Severity | Status | Następny krok |
|---|---|---|---|---|
| GAP-001 | Nieznany obecny PMS/source reservation flow | P1 | OPEN | discovery realnego flow |
| GAP-002 | Zaliczki/prepayments | P0 | MODEL_RESOLVED | test schema/API z prepayment/refund |
| GAP-003 | Cancellation/refund/no-show recognition | P0 | MODEL_RESOLVED | policy fixtures + accounting validation |
| GAP-004 | AvailabilityBlock kontra istniejąca Reservation | P0 | MODEL_RESOLVED | dodać AvailabilityConflict do schema draft |
| GAP-005 | Approval thresholds | P1 | OPEN-CONFIG | ustalić wartości przed PROD |
| GAP-006 | CAPEX_SMALL_ASSET threshold | P2 | OPEN-CONFIG | config Organization |
| GAP-007 | Period close policy | P1 | PARTIAL | fixtures OPEN/SOFT/HARD |
| GAP-008 | VAT/tax managerial view | P1 | OPEN | walidacja księgowa |
| GAP-009 | Depreciation managerial | P2 | DEFERRED | poza R1 core |
| GAP-010 | Retention periods | P1 | OPEN | walidacja prawna/księgowa |
| GAP-011 | Guest merge thresholds | P2 | OPEN | CRM rules later |
| GAP-012 | Resource capacity concurrency | P0 | STRATEGY_READY | PostgreSQL concurrency proof |
| GAP-013 | StaySegment overlap | P0 | STRATEGY_READY | exclusion constraint proof |
| GAP-014 | Cross-tenant FK enforcement | P0 | STRATEGY_READY | composite FK + RLS proof |
| GAP-015 | Allocation sum enforcement | P0 | STRATEGY_READY | transactional posting proof |
| GAP-016 | Legal entity mapping Owner/Operator | P1 | OPEN-CONFIG | implementation discovery |

## Schema Freeze blockers teraz

P0 wymagające wykonania proof/test:
- resource capacity concurrency,
- StaySegment exclusion,
- tenant isolation physical constraints,
- allocation posting transaction.

P1 nie blokuje technicznego proof-of-model, ale blokuje odpowiednie moduły PROD.

## Wniosek

Architektura nie ma już nierozwiązanej koncepcyjnie luki P0. Pozostałe P0 są problemami implementacyjno-walidacyjnymi, a nie brakiem modelu domenowego.