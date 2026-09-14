# OSG — Command Contracts v0.1

Status: roboczy zaawansowany
Data: 2026-09-14

## 1. Cel

Zdefiniować najważniejsze write use-cases niezależnie od UI i frameworka.

## 2. Reservation

### CreateReservation
Input:
- property_id
- primary_guest_ref
- channel_id
- reservation_items[]
- pricing_snapshot
- idempotency_key optional/required for external callers

Output:
- reservation_id
- reference_code
- commercial_status

### ConfirmReservation
Preconditions:
- reservation exists
- not cancelled/no-show
- required commercial data complete

Emits:
Reservation.Confirmed

## 3. Stay

### CheckInStay
Input:
- stay_id
- actual_checkin_at
- actual_guest_count
- actor

Preconditions:
- state EXPECTED
- assigned unit available for actual interval or explicit override workflow

### ChangeStayUnit
Input:
- stay_id
- new_unit_id
- effective_at
- reason

Effect:
- close current StaySegment
- create new StaySegment
- emit Stay.UnitChanged

### CheckOutStay
Effect:
- actual checkout
- state CHECKED_OUT
- event triggers Turnover workflow

## 4. Operations

### ReportIncident
Input:
- property_id
- affected entity
- severity
- description
- guest_impact
- safety_related

### CompleteTask
Precondition:
- task active
- if task type requires WorkLog, WorkLog must exist or be submitted atomically

## 5. Experience

### BookService
Input:
- service_id
- commercial context
- requested time
- quantity/guest count

Transaction validates resource availability where required.

## 6. Commerce

### PostCharge
Creates immutable POSTED charge.

### ConfirmPayment
Records confirmation without assuming bank settlement.

### AllocatePayment
Validates available payment amount and outstanding charge amount.

### RefundPayment
Creates refund fact; never rewrites original confirmed payment.

## 7. Financial Truth

### CreateEconomicEvent
Creates DRAFT event.

### SetAllocations
Allowed before POSTED or through correction workflow.

### PostEconomicEvent
Atomic workflow:
1. lock event
2. verify state
3. verify allocation sum
4. verify tenant integrity
5. verify required approval
6. set POSTED
7. enqueue DomainEvent in outbox

### ReverseEconomicEvent
Creates reversal event with reference to original.
Original remains immutable.

## 8. Settlement

### ApplySettlement
Input:
- settlement_entry_id
- application_source
- amount

Validates conservation and prevents over-settlement.

## 9. Availability

### CreateAvailabilityBlock
Runs conflict check against confirmed reservations/stays.
If conflict exists:
- rejects by default, or
- creates explicit conflict requiring approved override/remediation flow

## 10. Common command metadata

Every sensitive command carries:
- actor
- correlation_id
- idempotency_key when applicable
- reason for manual override where required

## 11. Rule

Commands express intent.
They never expose generic CRUD semantics for critical workflows such as posting financial events, checkout or settlement.
