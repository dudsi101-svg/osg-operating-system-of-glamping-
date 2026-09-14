# OSG — M2 Relationship Map v0.1

Status: roboczy
Data: 2026-09-14

## Cel

Formalizacja relacji pomiędzy głównymi encjami OSG przed projektowaniem schematu SQL.

## 1. Tenancy i organizacja

- 1 Organization → N Properties
- 1 Organization → N Parties
- 1 Organization → N UserAccounts
- rekord należący do Organization A nie może wskazywać rekordu Organization B, chyba że przyszła integracja międzyorganizacyjna wyraźnie to dopuszcza

## 2. Property Graph

- 1 Property → N Zones
- 1 Property → N UnitTypes
- 1 Property → N Units
- 1 Property → N Resources
- 1 Property → N Assets
- 1 Property → N Channels
- 1 UnitType → N Units
- 1 Zone → 0..N child Zones
- 1 Zone → N Units / Resources / Assets
- 1 Unit → N AvailabilityBlocks
- 1 Resource → N ResourceReservations

## 3. Guest i sprzedaż

- 1 Party(PERSON) → 0..1 GuestProfile
- 1 GuestProfile → N Reservations jako primary guest
- 1 Reservation → 1..N ReservationItems
- 1 Reservation → 0..N Folios
- 1 ReservationItem → 0..1 Stay
- 1 Stay → 1..N StaySegments
- 1 Stay → N StayGuests
- 1 GuestProfile ↔ N StayGuests

## 4. Folio i płatności

- 1 Folio → N Charges
- 1 Folio → N Payments
- 1 Payment → N PaymentAllocations
- 1 Charge → N PaymentAllocations
- suma PaymentAllocations dla Payment nie może przekraczać kwoty potwierdzonej płatności
- suma PaymentAllocations dla Charge nie może przekraczać niepokrytej wartości Charge, poza jawnie obsłużonymi korektami/nadpłatami

## 5. Experience

- 1 Service → N ServiceBookings
- 1 ServiceBooking → 0..N ResourceReservations
- 1 ServiceBooking → 0..N ServiceExecutions
- 1 ServiceBooking → 0..N Charges
- 1 Resource → N ResourceReservations
- ServiceBooking może być powiązany z Reservation, Stay lub GuestProfile

## 6. Operations

- 1 Stay → 0..N Turnovers
- 1 Turnover → N Tasks
- 1 Task → N WorkLogs
- 1 Incident → N Tasks
- 1 Incident → 0..N WorkOrders
- 1 Incident → 0..N AvailabilityBlocks
- 1 WorkOrder → 0..N FinancialDocuments lub EconomicEvents przez jawne relacje

## 7. Financial Truth

- 1 FinancialDocument → 1..N FinancialDocumentLines
- 1 FinancialDocumentLine → 0..N EconomicEvents
- 1 EconomicEvent → 1..N Allocations po POSTED
- 1 EconomicEvent → 0..N Reconciliation links
- 1 MoneyAccount → N CashMovements jako source
- 1 MoneyAccount → N CashMovements jako destination
- 1 CashMovement → 0..N Reconciliation links
- 1 Allocation może wskazywać Property, Unit, Stay, Resource, Asset, Service, Channel, InvestmentProject, CostCenter i economic bearer zgodnie z semantyką
- 1 InvestmentProject → N CAPEX Allocations
- 1 SettlementEntry wynika z różnicy między paid_by a economic_bearer i może być rozliczana przez CashMovement/SettlementPayment

## 8. System i historia

- 1 UserAccount → N RoleAssignments
- 1 Role → N Permissions
- 1 Entity → N AuditEvents
- 1 Domain entity → N DomainEvents
- 1 Integration → N ExternalRecords
- 1 OSG Entity → N ExternalReferences
- 1 FileObject → N typed attachments

## 9. Zasady kardynalności wymagające constraintów

1. Unit należy dokładnie do jednego Property.
2. ReservationItem musi należeć do Reservation tego samego Property.
3. StaySegment musi należeć do Stay wynikającego z ReservationItem tego samego Property.
4. Aktywne StaySegments tej samej Unit nie mogą nakładać się czasowo.
5. ResourceReservations nie mogą przekraczać capacity Resource w tym samym przedziale effective time.
6. Posted EconomicEvent musi być w pełni zaalokowany zgodnie z regułami tolerancji walutowej/zaokrągleń.
7. Cross-organization foreign keys są domyślnie zabronione.

## 10. Kolejne prace

- doprecyzować relacje optional/required dla Folio, Stay i ServiceBooking
- ustalić reprezentację relacji Allocation do wielu wymiarów bez utraty integralności FK
- doprecyzować settlement lifecycle
- przygotować diagram ERD po stabilizacji M3 Business Rules
