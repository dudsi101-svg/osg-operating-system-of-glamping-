# OSG — M10 Application Boundary v0.1

Status: kandydat zakresu pierwszego release'u
Data: 2026-09-14

## 1. Cel Release 1

Udowodnić pełny przepływ biznesowy Glampingu Nad Stawem od rezerwacji i pobytu do operacji i Financial Truth, bez próby zastąpienia całego PMS/ERP.

## 2. IN — wymagane

### Foundation
- Organization / Property
- Users / Roles / Permissions
- Audit
- Domain events basic
- DEV/STAGING/PROD
- backups/health checks

### Property
- Unit / UnitType
- Resource
- Asset basic
- AvailabilityBlock

### Reservations / Stay
- import/manual Reservation
- ReservationItem
- Stay / StaySegment
- arrivals/departures view

### Operations
- Turnover
- Tasks
- Incidents
- readiness
- basic maintenance history

### Experience
- Service
- ServiceBooking
- ResourceReservation
- charge creation

### Commerce
- Folio
- Charges
- Payments
- PaymentAllocation

### Financial Truth
- FinancialDocument basic
- CashMovement
- EconomicEvent
- Allocation
- CAPEX/OPEX
- Settlements
- reconciliation basic

### Analytics
- occupancy
- ADR
- RevPAR
- TRevPAR
- Stay Contribution Margin
- unit operating view
- data quality/confidence

## 3. OUT — odłożone

- własny Channel Manager
- pełny Booking Engine
- dynamic pricing automation
- pełna księgowość podatkowa
- payroll/HR
- rozbudowany magazyn
- native iOS/Android
- zaawansowany marketing CRM
- autonomiczne AI wykonujące wysokiego ryzyka działania
- multi-currency accounting
- pełny enterprise multi-tenant billing

## 4. First Release success criteria

1. Każdy rzeczywisty pobyt można prześledzić end-to-end.
2. Operator widzi arrivals/departures/turnovers/incidents.
3. Właściciel widzi cash vs economic result.
4. Koszt może być poprawnie zaalokowany lub oznaczony jako unresolved.
5. Settlement Michał/Kuba wynika z faktów, nie ręcznej osobnej tabeli.
6. Forest/Boho/Loft/Ostoja/Aura mają unit-level economics.
7. Każda kluczowa liczba ma explainability.
8. Import nie tworzy duplikatów.
9. Audit pokazuje krytyczne zmiany.
10. System działa responsywnie jako PWA.

## 5. Non-goals

Release 1 nie ma maksymalizować liczby funkcji. Ma potwierdzić poprawność rdzenia OSG.

## 6. Build order candidate

R0 foundation
R1 property + identity
R2 reservation/stay
R3 operations
R4 commerce
R5 financial truth
R6 experience
R7 analytics
R8 integrations hardening
