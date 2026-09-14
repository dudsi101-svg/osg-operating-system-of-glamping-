# OSG — Pre-Build Gap Register v0.1

Status: aktywny
Data: 2026-09-14

## Cel

Jawnie śledzić braki blokujące Schema Freeze albo późniejszy production build.

| ID | Gap | Severity | Blokuje | Domyślne rozwiązanie robocze |
|---|---|---|---|---|
| GAP-001 | Nieznany obecny PMS/source reservation flow | P1 | final integration contract | adapter + canonical reservation contract; discovery przed live integration |
| GAP-002 | Brak finalnej semantyki zaliczek/prepayments | P0 | commerce schema freeze | Payment może istnieć przed revenue recognition; przygotować Deposit/Liability policy |
| GAP-003 | Brak finalnej polityki cancellation/refund/no-show revenue recognition | P0 | finance freeze | policy engine/versioned cancellation terms |
| GAP-004 | AvailabilityBlock kontra istniejąca Reservation | P0 | operations freeze | block nie może unieważnić commitment po cichu; konflikt + relocation workflow |
| GAP-005 | Approval thresholds | P1 | finance/security | configurable thresholds per Organization; wartości ustalić przed PROD |
| GAP-006 | CAPEX_SMALL_ASSET threshold | P2 | reporting | konfigurowalne; nie hard-code |
| GAP-007 | Period close policy | P1 | finance posting | OPEN/SOFT/HARD model przyjęty; kalendarz i approvers do ustalenia |
| GAP-008 | VAT/tax managerial view | P1 | accounting exports | oddzielić tax view od economic view; wymaga księgowej walidacji |
| GAP-009 | Depreciation in managerial result | P2 | advanced economics | nie w R1 core operating result; osobna późniejsza warstwa |
| GAP-010 | Retention periods | P1 | privacy production | retention classes gotowe, terminy do prawnej/księgowej walidacji |
| GAP-011 | Guest merge confidence thresholds | P2 | CRM | manual review dla niepewnych dopasowań |
| GAP-012 | Resource capacity enforcement implementation | P0 | booking safety | transaction/locking + overlap check; test concurrency required |
| GAP-013 | StaySegment overlap enforcement | P0 | occupancy safety | PostgreSQL range/exclusion constraint candidate |
| GAP-014 | Cross-tenant FK physical enforcement | P0 | security | composite tenant keys/RLS/guard triggers do proof test |
| GAP-015 | Allocation sum enforcement | P0 | financial integrity | deferred constraint/transactional posting service |
| GAP-016 | Actual owner/operator legal entity mapping | P1 | settlements | configure Party + legal/business entities during implementation discovery |

## Reguła

P0 musi być rozwiązane albo mieć przetestowany mechanizm przed Schema Freeze GO.
P1 musi być rozwiązane przed produkcyjnym użyciem danego modułu.
P2 może wejść do roadmapy po pierwszym release, jeśli nie zniekształca core truth.