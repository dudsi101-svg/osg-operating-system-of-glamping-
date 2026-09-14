# OSG — Permission Matrix v0.1

Status: roboczy
Data: 2026-09-14

Legenda: R = read, W = write, A = approve, X = brak domyślnego dostępu.

| Obszar | Owner | Finance | Operator | Housekeeping | Maintenance | Accountant | Read-only | Guest |
|---|---|---|---|---|---|---|---|---|
| Property config | RW | R | R | R | R | R | R | X |
| Units/Resources | RW | R | RW | R | RW | R | R | X |
| Reservations | RW | R | RW | R-limited | R-limited | R | R | own-only |
| Guest personal data | RW | R-limited | RW-limited | minimal | minimal | R-limited | X | own-only |
| Stays | RW | R | RW | R-limited | R-limited | R | R | own-only |
| Turnovers/Tasks | R | X | RW | RW-own | RW-own | X | R | X |
| Incidents | RW | R-cost | RW | W-report | RW | R | R | own-related limited |
| Services | RW | R | RW | R | R | R | R | own-booking |
| Folio/Charges | RW | RW | RW-limited | X | X | R | X | own-only |
| Payments | RW | RW | R-limited | X | X | R | X | own-only |
| Financial Documents | RW | RW | W-upload/R-limited | X | R-own-workorder | RW | X | X |
| Cash Movements | RW | RW | X | X | X | R | X | X |
| Economic Events | RWA | RWA | W-draft limited | X | X | R | X | X |
| Allocations | RWA | RWA | W-proposal | X | X | R | X | X |
| Settlements | RWA | RWA | R-own | X | X | R | X | X |
| CAPEX projects | RWA | RWA | RW-operational | X | R | R | R | X |
| Analytics operating | R | R | R | R-limited | R-limited | R | R | X |
| Analytics financial | R | R | limited | X | X | R | X | X |
| Users/Roles | RWA | X | X | X | X | X | X | X |
| Audit | R | R-financial | R-operational | X | X | R-accounting | X | X |

## Field-level restrictions

1. Housekeeping nie widzi pełnego telefonu/email gościa, jeśli workflow tego nie wymaga.
2. Operator nie widzi pełnych danych bankowych ani prywatnych rozrachunków właścicielskich, chyba że scope explicitly na to pozwala.
3. Accountant nie otrzymuje prawa modyfikacji operational truth.
4. Maintenance widzi dane gościa tylko, jeśli są konieczne do realizacji konkretnej naprawy.
5. Guest nigdy nie widzi wewnętrznych kosztów, notatek operacyjnych, incident severity internal ani danych innych gości.

## Approval rules candidate

- EconomicEvent POSTED: Finance lub Owner.
- Manual Allocation powyżej progu: creator + niezależny approver.
- HARD_CLOSED period reopen: Owner + Finance.
- Permission changes high-risk: Owner/Org Admin.
- NON_BUSINESS reclassification high-value: Owner approval.

## AI

AI dziedziczy permission scope użytkownika inicjującego żądanie. AI_SERVICE nie jest superuserem.