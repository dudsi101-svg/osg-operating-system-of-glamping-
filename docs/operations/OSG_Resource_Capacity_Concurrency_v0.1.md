# OSG — Resource Capacity & Concurrency Contract v0.1

Status: kandydat do freeze
Data: 2026-09-14

## 1. Problem

Dwie osoby mogą niemal równocześnie próbować zarezerwować ten sam ograniczony Resource. Zwykłe `check availability → insert` jest podatne na race condition.

## 2. Effective window

Każda ResourceReservation posiada:
- requested_start/end,
- buffer_before/after,
- effective_start/end,
- capacity_used.

Konflikt liczony jest po effective window.

## 3. Capacity modes

EXCLUSIVE — jak sauna/jacuzzi przy prywatnym użyciu; capacity logicznie 1.
CAPACITY — np. sala na N osób/jednostek capacity.
UNLIMITED — brak concurrency guard poza blokadami.

## 4. Transactional booking

Operacja `ReserveResource`:
1. rozpoczyna transakcję,
2. lockuje Resource lub używa serializable/advisory lock dla resource_id,
3. pobiera aktywne overlapping reservations,
4. sumuje capacity_used,
5. sprawdza availability blocks,
6. tworzy reservation tylko gdy limit nie jest przekroczony,
7. emituje event,
8. commit.

## 5. Database constraint

Dla EXCLUSIVE Resource preferowany jest PostgreSQL exclusion constraint po `tstzrange(effective_start,effective_end,'[)')` i resource_id.

Dla capacity > 1 sam exclusion constraint nie wystarcza — wymagany jest transakcyjny service + lock + invariant test.

## 6. Statuses affecting capacity

Capacity konsumują wyłącznie statusy:
HELD (jeśli hold jeszcze ważny), CONFIRMED, IN_PROGRESS.

Nie konsumują:
CANCELLED, EXPIRED, REJECTED, COMPLETED po zakończeniu okna.

## 7. Holds

Hold ma `expires_at`. Wygasły hold nie może blokować capacity nawet jeśli cleanup job jeszcze go fizycznie nie zaktualizował.

## 8. Modification

Zmiana czasu istniejącej rezerwacji przechodzi przez ten sam concurrency check co nowe utworzenie.

## 9. P0 tests

RC-001 — dwie równoległe rezerwacje EXCLUSIVE → dokładnie jedna wygrywa.
RC-002 — capacity 8, istnieje 6 + próba 3 → reject.
RC-003 — capacity 8, istnieje 6 + próba 2 → accept.
RC-004 — cancelled reservation nie konsumuje capacity.
RC-005 — expired hold nie konsumuje capacity.
RC-006 — buffer overlap blokuje rezerwację mimo braku overlap requested window.