# OSG — Command Center Contract v0.1

Status: roboczy
Data: 2026-09-14

## 1. Cel

Command Center jest projekcją najważniejszych faktów operacyjnych na dziś. Nie jest źródłem prawdy.

## 2. Sekcje

### Arrivals
Źródła: Stay EXPECTED + ReservationItem + Unit assignment.
Pola minimalne:
- planned arrival
- unit
- primary guest display name
- guest count
- payment/folio warning
- special operational flags
- readiness status

### Departures
Źródła: active Stay.
Pola:
- unit
- planned checkout
- actual checkout if completed
- open charges warning
- known incident/damage flags

### Turnovers
Źródła: Turnover + Task.
Pola:
- unit
- ready deadline
- status
- assignee
- progress
- blockers
- next arrival

### Wellness / Experiences
Źródła: ServiceBooking + ResourceReservation.
Pola:
- time
- service
- resource
- stay/unit context
- prep task status

### Incidents
Źródła: Incident.
Pola:
- severity
- affected unit/resource/asset
- guest impact
- owner
- age
- blocking status

### Stock alerts
Źródła: Inventory/Reorder projections, gdy moduł aktywny.

### Financial alerts
Nie pełny P&L. Tylko operacyjne wyjątki:
- overdue/unmatched payment
- unreconciled cash above SLA
- unresolved allocation requiring operator/finance action

## 3. Priority engine

Każdy card może otrzymać operational_priority_score na podstawie:
- safety
- guest impact
- deadline proximity
- revenue impact
- dependency blocking

Score jest projekcją wyjaśnialną, nie ręcznym polem prawdy.

## 4. Operator question

Command Center ma odpowiadać przede wszystkim:
> Co muszę zrobić teraz, co jest zagrożone i co blokuje doświadczenie gościa?

## 5. Zakazy

- brak edycji księgowych faktów bez przejścia do odpowiedniego workflow
- brak ukrywania blokad availability
- brak łączenia statusów payment/stay/readiness w jeden kolorystyczny pseudo-status
- brak ręcznej liczby „dzisiejszy zysk” bez wersjonowanej definicji

## 6. Refresh

Projekcja może być aktualizowana event-driven + okresowo reconcilowana.
Każdy element powinien zawierać source entity ids do drill-down.
