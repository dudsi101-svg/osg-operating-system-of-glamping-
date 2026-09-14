# OSG — Availability Conflict Policy v0.1

Status: kandydat do freeze
Data: 2026-09-14

## 1. Cel

Określić zachowanie systemu, gdy nowy AvailabilityBlock koliduje z istniejącą Reservation/Stay.

## 2. Zasada

AvailabilityBlock nie może po cichu anulować ani relokować istniejącej rezerwacji.

## 3. Typy konfliktu

A. Block dotyczy wyłącznie przyszłej niesprzedanej dostępności → utwórz bez konfliktu.
B. Block nachodzi na CONFIRMED ReservationItem bez Stay → utwórz block + ConflictCase wymagający rozwiązania.
C. Block nachodzi na EXPECTED/CHECKED_IN Stay → CRITICAL ConflictCase; blokada nie zmienia historii pobytu.
D. Safety-critical incident → block może zostać aktywowany natychmiast, ale obowiązkowo uruchamia relocation/cancellation workflow.

## 4. ConflictCase

Minimalne pola:
- id
- organization_id
- property_id
- availability_block_id
- reservation_item_id/stay_id
- severity
- reason
- status
- resolution_type
- resolved_by
- resolved_at

## 5. Resolution types

RELOCATE_UNIT
SHORTEN_STAY
CANCEL_RESERVATION
OVERRIDE_BLOCK
SPLIT_STAY
MANUAL_EXCEPTION

Każda resolution pozostawia audit trail.

## 6. Metrics

Block powodujący istniejącą rezerwację nie może sztucznie usuwać sprzedanej nocy z historycznych KPI.
Sellable capacity dla przyszłych niesprzedanych nocy może zostać zmniejszone.

## 7. Revenue opportunity

LostRevenueOpportunity może powstać dla niewykorzystanej przyszłej sprzedaży, ale nie zastępuje faktycznych refundów/kompensacji istniejących rezerwacji.

## 8. Automation

Safety-critical:
Incident.Reported → AvailabilityBlock.Created → ConflictDetected → operator/owner alert.

Automatyzacja nie wykonuje sama refundu ani anulacji bez polityki i odpowiednich uprawnień.

## 9. P0 tests

AVC-001 — maintenance block bez bookings → accept.
AVC-002 — block koliduje z confirmed reservation → ConflictCase created.
AVC-003 — safety block podczas checked-in stay → block + CRITICAL conflict, brak cichego checkout/cancel.
AVC-004 — relocation → nowe StaySegment, historia pierwotnego segmentu zachowana.
AVC-005 — resolved conflict nie usuwa audit trail.