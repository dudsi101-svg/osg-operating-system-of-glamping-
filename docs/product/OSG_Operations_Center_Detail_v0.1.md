# OSG — Operations Center Detail v0.1

Status: product contract
Data: 2026-09-14

## 1. Cel

Operations Center ma odpowiadać operatorowi na trzy pytania:
1. Co muszę zrobić teraz?
2. Co jest zagrożone?
3. Co blokuje pobyt lub doświadczenie gościa?

## 2. Główne sekcje

### Arrivals
- expected today
- ETA
- unit readiness
- payment/form blockers
- special operational requirements

### Departures
- expected checkout
- actual checkout status
- overdue checkout
- next-arrival pressure

### Turnovers
- unit
- previous stay
- next stay
- deadline READY
- task progress
- blocker
- assigned team/person

### Services / Wellness
- upcoming ServiceBookings
- Resource status
- preparation deadline
- conflicts
- no-show/late status

### Incidents
- severity
- affected Unit/Resource/Asset
- guest impact
- availability impact
- owner/assignee
- elapsed time

### Tasks
- NOW
- NEXT
- OVERDUE
- BLOCKED

### Stock warnings
- operational consumables below reorder threshold

## 3. Priority engine

Priority nie może być wyłącznie ręcznym polem.
OSG może wyliczać operational urgency z:
- time to guest impact,
- severity,
- next arrival,
- safety,
- revenue impact,
- dependency blockers.

Manual priority pozostaje osobnym inputem.

## 4. Critical path example

Forest checkout 11:00
Next arrival 15:00
Turnover expected 120 min
At 13:30 status still PENDING

System:
- marks at-risk,
- raises urgency,
- alerts operator,
- shows remaining tasks/blockers.

## 5. Readiness contract

Unit readiness states:
DIRTY → CLEANING → INSPECTION → READY
or BLOCKED from any relevant state.

READY może wymagać completion konkretnego TaskTemplate zależnie od Unit type.

## 6. Operator actions

- start/complete Task
- report Incident
- assign/reassign Task
- mark inspection
- update ETA after guest contact
- create manual task
- acknowledge alert
- request maintenance/work order

Operator nie może z ekranu operacyjnego cicho zmieniać posted finance ani anulować rezerwacji bez właściwego workflow.

## 7. Timeline

Każdy Unit/Stay ma operational timeline:
checkout → turnover → tasks → ready → check-in → incidents/services.

## 8. Failure visibility

Nie chowamy FAILED automation. Jeśli checkout nie utworzył Turnover, Operations Center pokazuje brak procesu jako alert danych/automatyzacji.

## 9. Mobile-first

Ekran operatora powinien być projektowany przede wszystkim pod telefon:
- jedna ręka,
- szybkie statusy,
- mało tekstu,
- szybkie zdjęcie usterki,
- działanie w słabym zasięgu z controlled offline queue gdzie bezpieczne.

## 10. Offline boundary

Offline można kolejkować low-risk operational updates (np. Task progress, zdjęcie szkody).
Nie wykonujemy offline krytycznych zmian finansowych, rezerwacyjnych ani capacity booking bez synchronizacji/konflikt check.

## 11. KPI

- turnover duration
- % ready before deadline
- overdue task rate
- incident MTTR
- incident guest-impact time
- service preparation compliance
- operator workload by day

## 12. Product principle

Operations Center nie jest dashboardem analitycznym. To ekran działania.