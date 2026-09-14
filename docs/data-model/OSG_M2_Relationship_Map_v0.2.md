# OSG — M2 Relationship Map v0.2

Status: roboczy zaawansowany
Data: 2026-09-14

## 1. Założenie

Relacje OSG są projektowane jako jawne kontrakty z kardynalnością, ownership i ograniczeniami integralności.

## 2. Organization / Tenant

Organization 1—N Property
Organization 1—N Party
Organization 1—N UserAccount
Organization 1—N Integration

Reguła: każdy rekord tenant-owned posiada organization_id i nie może referować rekordu innej Organization bez jawnego mechanizmu cross-tenant.

## 3. Property Graph

Property 1—N Zone
Property 1—N UnitType
Property 1—N Unit
Property 1—N Resource
Property 1—N Asset
Property 1—N AvailabilityBlock

UnitType 1—N Unit
Zone 0..1—N Zone
Zone 1—N Unit/Resource/Asset

Unit 1—N StaySegment
Unit 1—N AvailabilityBlock
Resource 1—N ResourceReservation
Asset N—1 logical location (Unit/Resource/Zone) przez jawny typ relacji lokalizacyjnej

## 4. Reservation / Stay

GuestProfile 1—N Reservation
Reservation 1—N ReservationItem
Reservation 1—N Folio
ReservationItem 0..N—1 Stay

Decyzja v0.2: ReservationItem może prowadzić do wielu Stay tylko w wyjątkowym scenariuszu reaktywacji/split execution; domyślnie 0..1. Implementacja powinna wymagać explicit reason dla kolejnego Stay.

Stay 1—N StaySegment
Stay N—M GuestProfile przez StayGuest

Warunek: segmenty jednego Stay nie mogą się nakładać, a aktywne segmenty tej samej Unit nie mogą się nakładać z segmentami innego Stay.

## 5. Folio / Commerce

Reservation 1—N Folio
Folio 1—N Charge
Folio 1—N Payment
Payment N—M Charge przez PaymentAllocation

Charge może wskazywać ReservationItem, ServiceBooking, FeeSource lub AdjustmentSource.
Payment może istnieć przed rzeczywistym CashMovement.
CashMovement może istnieć bez Payment.

## 6. Experience

Service 1—N ServiceBooking
ServiceBooking 0..N—1 ResourceReservation
ServiceBooking 0..N—1 ServiceExecution
ServiceBooking 0..N—1 Charge

ServiceBooking musi mieć dokładnie jeden primary commercial context:
- Reservation
- Stay
- GuestProfile / walk-in

ResourceReservation może istnieć również bez ServiceBooking dla blokad technicznych i operator use.

## 7. Operations

Stay 0..N—1 Turnover
Turnover 1—N Task
Task 1—N WorkLog
Incident 0..N—1 Task
Incident 0..N—1 WorkOrder
Incident 0..N—1 AvailabilityBlock

Task ma jeden primary context i opcjonalne secondary links.
WorkLog zawsze wskazuje Task i wykonawcę.

## 8. Financial Truth

FinancialDocument 1—N FinancialDocumentLine
FinancialDocumentLine 0..N—1 EconomicEvent
Charge 0..N—1 EconomicEvent
EconomicEvent 1—N Allocation po POSTED
CashMovement N—M FinancialDocument/EconomicEvent przez ReconciliationLink

Allocation posiada jawne FK do wymiarów tam, gdzie relacja jest stabilna:
- property_id required dla business allocation
- unit_id optional
- stay_id optional
- resource_id optional
- asset_id optional
- service_id optional
- channel_id optional
- investment_project_id optional
- cost_center_id optional
- economic_bearer_party_id optional/required zależnie od event type

Zakaz: generic entity_type/entity_id dla kluczowych wymiarów finansowych.

## 9. Settlements

SettlementEntry:
- creditor_party_id
- debtor_party_id
- source_economic_event_id lub source_allocation_id
- amount
- currency
- status

SettlementEntry 0..N—1 SettlementApplication
SettlementApplication wskazuje CashMovement lub kompensatę.

Saldo strony jest projekcją, nie niezależnym faktem.

## 10. Identity

UserAccount N—M Role przez RoleAssignment
Role N—M Permission
RoleAssignment może mieć scope Organization lub Property.

Party 0..1—1 UserAccount jako osoba/organizacja logująca się; brak wymogu posiadania UserAccount przez Party.

## 11. Integration

Integration 1—N ExternalRecord
ExternalRecord 0..N—1 ExternalReference
OSG Entity 0..N—1 ExternalReference

ExternalReference posiada uniqueness na (integration_id, external_type, external_id).

## 12. File / Audit / Event

Entity 0..N—1 AttachmentLink
FileObject 1—N AttachmentLink

Entity 1—N AuditEvent logicznie
Domain aggregate 1—N DomainEvent logicznie

Audit i event log nie są FK wymaganymi przez każdą tabelę; są append-only warstwą systemową.

## 13. Agregaty domenowe v0.2

Organization Aggregate
Property Aggregate
Reservation Aggregate
Stay Aggregate
Folio Aggregate
ServiceBooking Aggregate
Turnover Aggregate
Incident Aggregate
EconomicEvent Aggregate
Settlement Aggregate

Zmiany wewnątrz agregatu mogą być transakcyjne. Zmiany między agregatami powinny preferować kontrakty i Domain Events.

## 14. Najważniejsze invariants

- cross-tenant FK forbidden
- posted EconomicEvent fully allocated
- confirmed PaymentAllocation <= confirmed Payment
- active StaySegments cannot overlap per Unit
- effective ResourceReservations cannot exceed capacity
- financial facts after posting use reversal/correction
- one primary source of truth per controlled field
