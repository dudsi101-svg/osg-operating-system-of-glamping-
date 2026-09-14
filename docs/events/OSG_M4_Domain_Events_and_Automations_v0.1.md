# OSG — M4 Domain Events & Automations v0.1

Status: roboczy
Data: 2026-09-14

## 1. Cel

Zdefiniować układ nerwowy OSG: zdarzenia, które opisują fakty biznesowe i mogą uruchamiać kontrolowane reakcje w innych domenach.

## 2. Zasada

DomainEvent opisuje fakt, który już wystąpił.
Automation reaguje na event.
Automation nie zmienia historii eventu.

## 3. Envelope eventu

Każdy event zawiera:
- event_id
- event_type
- event_version
- organization_id
- property_id optional
- aggregate_type
- aggregate_id
- occurred_at
- recorded_at
- actor/source
- correlation_id
- causation_id
- payload

## 4. Reservation events

Reservation.Created
Reservation.Held
Reservation.Confirmed
Reservation.Modified
Reservation.Cancelled
Reservation.NoShowMarked
ReservationItem.UnitAssigned
ReservationItem.UnitChanged

## 5. Stay events

Stay.Expected
Stay.CheckedIn
Stay.UnitChanged
Stay.CheckedOut
Stay.Cancelled
StayGuest.Added
StayGuest.Removed

Automations:
Stay.CheckedOut → Turnover.Create
Stay.CheckedIn → mark expected arrival completed
Stay.UnitChanged → update operational occupancy projection

## 6. Property events

Unit.Activated
Unit.Blocked
Unit.Unblocked
Unit.ReadinessChanged
AvailabilityBlock.Created
AvailabilityBlock.Ended
Asset.Installed
Asset.Retired
Resource.Blocked
Resource.Unblocked

## 7. Operations events

Turnover.Created
Turnover.Started
Turnover.Blocked
Turnover.Ready
Task.Created
Task.Assigned
Task.Started
Task.Completed
Task.Overdue
Incident.Reported
Incident.Triaged
Incident.Escalated
Incident.Resolved
Incident.Closed
WorkOrder.Created
WorkOrder.Completed

Automations:
Incident.Reported(severity=CRITICAL) → alert + optional block
Task.Overdue(priority=HIGH) → escalation
Turnover deadline approaching and status != READY → operator alert

## 8. Service events

Service.Booked
Service.Modified
Service.Cancelled
Service.Started
Service.Completed
Service.NoShow
ResourceReservation.Created
ResourceReservation.ConflictDetected

Automations:
Service.Booked → create ResourceReservation if required
Service.Booked → create Charge according to pricing policy
Service.Booked → create preparation Task if template exists

## 9. Commerce events

Folio.Opened
Charge.Created
Charge.Posted
Charge.Reversed
Payment.Recorded
Payment.Confirmed
Payment.Failed
Payment.Refunded
PaymentAllocation.Created
Folio.Closed
Folio.Reopened

## 10. Financial Truth events

FinancialDocument.Imported
FinancialDocument.Verified
FinancialDocument.Posted
CashMovement.Imported
CashMovement.Reconciled
EconomicEvent.Created
EconomicEvent.Posted
EconomicEvent.Reversed
Allocation.Created
Allocation.Changed
Allocation.Approved
SettlementEntry.Created
SettlementEntry.Settled
Period.Closed
Period.Reopened

Automations:
EconomicEvent.Posted + paid_by != economic_bearer → SettlementEntry.Create
CAPEX Allocation + no project + amount above threshold → DataQualityIssue/Create approval block
Unreconciled CashMovement beyond SLA → DataQualityIssue

## 11. Integration events

ExternalRecord.Received
ExternalRecord.Mapped
ExternalRecord.Rejected
Sync.Started
Sync.Completed
Sync.Failed
Conflict.Detected

## 12. Data Quality events

DataQualityIssue.Created
DataQualityIssue.Acknowledged
DataQualityIssue.Resolved

## 13. Automation execution

Każde wykonanie automatyzacji musi mieć:
- automation_rule_id
- trigger_event_id
- execution_id
- status
- started_at
- completed_at
- actions
- error
- retry_count

## 14. Idempotency

Każda automatyzacja reagująca na event musi być idempotentna.
Klucz: (automation_rule_id, trigger_event_id, action_key).

## 15. Retry

Retry jest dozwolony dla błędów technicznych.
Błędy biznesowe przechodzą do FAILED/BLOCKED i wymagają decyzji lub korekty danych.

## 16. Kolejność i eventual consistency

Zmiany wewnątrz jednego agregatu są transakcyjne.
Reakcje między agregatami mogą być eventually consistent, ale muszą mieć obserwowalny status wykonania.

## 17. Zakaz ukrytej automatyzacji

Każda automatyzacja zmieniająca stan biznesowy musi być widoczna w audit/automation history i możliwa do wyjaśnienia użytkownikowi.
