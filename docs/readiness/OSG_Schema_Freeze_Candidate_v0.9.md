# OSG — Schema Freeze Candidate v0.9

Status: CANDIDATE / NOT FINAL
Data: 2026-09-14

## 1. Znaczenie

Od tej wersji model traktujemy jako stabilny kandydat. Zmiany fundamentalne wymagają:
- wskazania łamanej reguły/scenariusza
- analizy wpływu
- ADR, jeśli zmieniają architekturę

## 2. Stabilne granice domen

Foundation:
Organization, Party, UserAccount, RoleAssignment

Property:
Property, Zone, UnitType, Unit, Resource, Asset, AvailabilityBlock

Commerce/Stay:
GuestProfile, Reservation, ReservationItem, Stay, StaySegment, StayGuest, Folio, Charge, Payment, PaymentAllocation

Experience:
Service, ServiceBooking, ResourceReservation, ServiceExecution, Package

Operations:
Turnover, Task, WorkLog, Incident, WorkOrder

Financial Truth:
FinancialDocument, FinancialDocumentLine, MoneyAccount, CashMovement, EconomicEvent, Allocation, ReconciliationLink, SettlementEntry, SettlementApplication, InvestmentProject, CostCenter

System:
ExternalRecord, ExternalReference, DomainEvent, AuditEvent, FileObject, DataQualityIssue

## 3. Stabilne invariants

- Organization is tenant boundary
- Reservation != Stay
- Charge != Payment != CashMovement
- FinancialDocument != EconomicEvent != Allocation
- posted financial facts use correction/reversal
- active StaySegments cannot overlap per Unit
- Resource capacity cannot be exceeded
- posted EconomicEvent is fully allocated
- CAPEX separated from operating result
- payer separated from economic bearer
- domain integrations are idempotent
- AI access is permission-bound

## 4. Stabilne cross-domain contracts

- Stay.CheckedOut → operations reaction
- Service.Booked → resource/charge/preparation reactions
- EconomicEvent.Posted → settlement/data-quality reactions
- ExternalRecord.Received → mapping pipeline

## 5. Remaining non-schema blockers

These do not require redesigning core entities:
- identify real PMS/reservation source
- exact approval thresholds
- exact CAPEX small-asset threshold
- legal retention periods
- first bank import method
- operational configuration of cancellation policies

## 6. Remaining schema-risk items

Before v1.0 Freeze verify technically:
1. exclusion constraint for StaySegment overlap
2. resource capacity concurrency under race conditions
3. transaction-safe economic event posting
4. tenant isolation at DB/service layer
5. settlement application conservation
6. event idempotency under retries

## 7. Change policy after v0.9

Allowed without ADR:
- new optional descriptive fields
- new enum value when backward-compatible
- new projection/report
- new secondary index

Requires ADR or explicit schema review:
- changing aggregate ownership
- merging/splitting core entities
- changing financial semantics
- changing tenant boundary
- changing public API/event contract incompatibly

## 8. Recommendation

Proceed to implementation-ready architecture and proof tests.
Do not yet mark v1.0 FINAL until six schema-risk items are executed against PostgreSQL/test harness.
