# OSG — Data Quality Catalog v0.1

Status: roboczy
Data: 2026-09-14

## Cele jakości danych

OSG powinien mierzyć nie tylko wynik biznesowy, ale również wiarygodność danych użytych do jego wyliczenia.

## Kategorie problemów

### COMPLETENESS
- Reservation bez channel
- Stay bez primary context
- FinancialDocument bez wymaganych linii
- EconomicEvent bez allocations
- CAPEX bez InvestmentProject powyżej progu

### CONSISTENCY
- ReservationItem unit z innego Property
- Payment currency != Folio currency bez FX workflow
- Allocation property niezgodne ze źródłowym Stay
- Settlement creditor = debtor

### TIMELINESS
- bank sync stale
- reservation sync stale
- overdue unreconciled movements
- unresolved incident beyond SLA

### DUPLICATION
- duplicate GuestProfile candidate
- duplicate FinancialDocument number+issuer+amount
- duplicate external reservation
- duplicate CashMovement import

### RECONCILIATION
- payment without matching settlement/cash path
- cash movement without classification above SLA
- document total mismatch
- OTA payout mismatch

### CONFIDENCE
- UNKNOWN allocation
- ESTIMATED without rationale
- manual override without approval

## Severity

P0 — może prowadzić do fałszywych danych finansowych, naruszenia izolacji lub podwójnego pobytu.
P1 — materialnie wpływa na decyzje operacyjne/finansowe.
P2 — obniża kompletność/analitykę, ale nie blokuje podstawowej operacji.
P3 — kosmetyczne/uzupełniające.

## DataQualityIssue fields

- issue_code
- severity
- entity_type
- entity_id
- detected_at
- detection_rule_version
- status
- owner
- due_at
- resolution
- resolved_at

## Przykładowe reguły

DQ-FIN-001 — posted event allocation mismatch → P0
DQ-STAY-001 — overlapping active stay segments → P0
DQ-TNT-001 — cross-tenant reference → P0
DQ-INT-001 — duplicate external reservation effect → P0
DQ-REC-001 — confirmed payment unreconciled > configured SLA → P1
DQ-CAP-001 — CAPEX no project above threshold → P1
DQ-GST-001 — probable duplicate guest → P2
DQ-MET-001 — KPI source facts contain >20% UNKNOWN confidence → P1 warning

## Data confidence score

Nie tworzymy jednej magicznej oceny jakości bez kontekstu. Score może istnieć per metric/report i powinien pokazywać udział:
- VERIFIED
- SYSTEM_DERIVED
- ESTIMATED
- MANUAL
- UNKNOWN

## Operacyjna zasada

P0 może blokować posting/checkout/assignment zależnie od reguły. P1 zwykle ostrzega lub wymaga approval. P2/P3 trafia do backlogu jakości danych.