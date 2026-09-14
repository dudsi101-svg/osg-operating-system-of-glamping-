# OSG — Aggregate & Concurrency Model v0.1

Status: pre-freeze candidate
Date: 2026-09-15

## 1. Aggregate principles

An aggregate is a transactional consistency boundary, not merely a menu/module boundary.
Cross-aggregate side effects prefer Domain Events/outbox unless one database transaction is required by a hard invariant.

## 2. Aggregate roots

### Organization
Owns tenant-level configuration and identity boundary.
Concurrency: optimistic for mutable configuration.

### Property
Owns core property configuration and policies.
Children such as Unit/Resource/Asset are separate operational aggregates after creation; they are not all locked through one Property row.

### Reservation
Root: Reservation.
Transactional children:
- ReservationItem creation/update where commercial consistency requires it
- CommercialPolicySnapshot creation on confirmed commercial change

Concurrency:
- row_version/If-Match
- import conflict policy when external source owns commercial facts

### Stay
Root: Stay.
Children:
- StaySegment
- StayGuest

Hard invariant:
- no overlapping active StaySegments on the same Unit globally

Concurrency:
- optimistic Stay version for normal transitions
- DB exclusion constraint for Unit/time overlap

### Folio
Root: Folio.
Children/facts:
- Charge
- PaymentAllocation belongs to Payment/Charge reconciliation semantics

Concurrency:
- optimistic Folio changes
- posted/reversed Charge semantics preserve history
- payment overallocation protected transactionally

### ServiceBooking
Root: ServiceBooking.
Related ResourceReservation is a separate capacity fact coordinated in the same command workflow where required.

Concurrency:
- optimistic ServiceBooking state
- Resource lock/capacity check for booking acceptance

### Turnover
Root: Turnover.
Tasks reference it but have independent lifecycle.
Concurrency: optimistic.

### Task
Independent work aggregate.
WorkLog is append-oriented execution evidence.

### Incident
Root: Incident.
May cause cross-aggregate AvailabilityBlock, Task, WorkOrder and ConflictCase through orchestrated workflow/events.
Concurrency: optimistic Incident state; safety automation may execute transactionally for immediate block creation.

### EconomicEvent
Root: EconomicEvent.
Draft Allocation set belongs to posting workflow.

Concurrency:
- draft edits optimistic where exposed,
- POST command locks event and validates Allocation conservation,
- POSTED facts immutable,
- correction/reversal creates new economic facts.

### SettlementEntry
Root: SettlementEntry.
SettlementApplication is append-only application of repayment/compensation.
Concurrency:
- lock SettlementEntry before applying amount,
- applied total cannot exceed original amount.

### Integration processing
Root/claim key: Integration + external event/idempotency identity.
ExternalRecord is append/source evidence.
Concurrency: unique claim; exactly-one domain effect target.

## 3. Concurrency matrix

| Aggregate/workflow | Main strategy | DB hard guard |
|---|---|---|
| Reservation | optimistic | tenant FKs / invariants |
| Stay | optimistic | temporal exclusion on Unit |
| Resource booking EXCLUSIVE | transactional | temporal exclusion |
| Resource capacity >1 | transactional lock Resource | sum capacity check |
| Folio | optimistic | payment/charge conservation workflow |
| Turnover | optimistic | state machine |
| Incident | optimistic | safety/business rules |
| EconomicEvent draft | optimistic | tenant FKs |
| EconomicEvent posting | transactional lock | balance + immutability |
| Settlement application | transactional lock | conservation |
| Integration event | unique idempotent claim | unique key |
| Domain/Audit event | append-only | unique ID |

## 4. Lock ordering

To avoid deadlocks, multi-lock workflows use deterministic order.

Reference order:
1. tenant/organization context validation
2. aggregate root
3. capacity/resource row(s) sorted by UUID
4. financial/settlement root rows sorted by UUID
5. dependent insert/update

Avoid holding locks while performing network calls.

## 5. Cross-domain transaction rule

One transaction is justified only when partial completion would create an invalid state that cannot safely be reconciled asynchronously.

Examples:
- EconomicEvent status + Allocation validation + outbox event → one transaction.
- Resource capacity acceptance + ResourceReservation → one transaction.

Examples that can be eventually consistent:
- Stay.CheckedOut → Turnover creation through outbox handler.
- Incident.Reported → notification delivery.
- Service.Completed → analytics projection update.

## 6. Agent implementation consequence

An agent modifying an aggregate contract must declare:
- row_version impact,
- command idempotency behavior,
- transaction boundary,
- event emitted,
- affected DB constraints,
- retry behavior.

Cross-aggregate direct table writes are prohibited unless documented as part of an approved transactional workflow.
