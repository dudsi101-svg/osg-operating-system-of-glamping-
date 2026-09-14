# OSG — Availability Conflict & Relocation v0.1

Status: decyzja modelowa robocza
Data: 2026-09-14

## Problem

AvailabilityBlock może pojawić się po tym, jak Unit jest już sprzedany. System nie może po cichu unieważnić istniejącego commitment.

## Decyzja

AvailabilityBlock blokuje przyszłą sellability, ale istniejąca aktywna Reservation/Stay tworzy `AvailabilityConflict`, który wymaga jawnego resolution workflow.

## AvailabilityConflict

Pola logiczne:
- id
- property_id
- unit_id
- availability_block_id
- reservation_item_id / stay_id
- conflict_type
- severity
- detected_at
- status
- resolution_type
- resolved_at
- resolved_by

Status:
OPEN → IN_REVIEW → RESOLVED

## Resolution types

- RELOCATE_SAME_PROPERTY
- RELOCATE_EXTERNAL
- REPAIR_BEFORE_ARRIVAL
- PARTIAL_RELOCATION
- CANCEL_WITH_POLICY_OVERRIDE
- MANUAL_ACCEPT_RISK

## Przed przyjazdem

Incident/Block powstaje
→ system wyszukuje dotknięte ReservationItems
→ tworzy AvailabilityConflict
→ proponuje wolne kompatybilne Units
→ operator wybiera resolution
→ jeśli relokacja: ReservationItem assigned unit zmienia się z pełnym audit trail

## W trakcie pobytu

Incident/Block powstaje
→ istniejący Stay pozostaje faktem
→ relokacja tworzy kolejny StaySegment
→ poprzedni segment nie jest nadpisywany
→ koszty/kompensacje mogą zostać przypisane do Incident i Stay

## Ważne rozróżnienie

AvailabilityBlock ≠ Reservation cancellation.
AvailabilityBlock ≠ Stay termination.
AvailabilityConflict jest warstwą koordynującą sprzeczność pomiędzy physical availability i commercial commitment.

## Invariants

1. Utworzenie Block nie usuwa Reservation.
2. Aktywna rezerwacja dotknięta Block generuje Conflict.
3. Konflikt P0/P1 musi być widoczny w Command Center.
4. Relokacja w trakcie pobytu wykorzystuje StaySegment.
5. Manual accept risk wymaga uprawnienia i reason.
6. Block nie może zostać uznany za rozwiązany tylko dlatego, że rezerwacja istnieje.

## Wniosek

GAP-004 ma rozwiązanie domenowe. Potrzebna będzie encja AvailabilityConflict albo równoważny agregat/wzorzec workflow; rekomendacja: osobna encja ze względu na audyt i operacje.