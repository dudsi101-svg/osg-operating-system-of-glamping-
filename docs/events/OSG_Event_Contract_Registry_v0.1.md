# OSG — Event Contract Registry v0.1

Status: pre-freeze candidate
Date: 2026-09-15

All cross-domain events use `OSG_Domain_Event_Envelope_v0.1.json` plus a versioned payload schema.

## Versioning rule

- additive optional payload field → same event version allowed,
- required field removal/rename/semantic change → new event_version,
- consumers declare supported event versions,
- outbox retries preserve original version/payload,
- producer does not rewrite historical DomainEvent after schema evolution.

## Registered contracts

### Stay
- `Stay.CheckedOut` v1 — existing schema

Primary consumers:
- Turnover automation
- guest communication
- analytics projection

### EconomicEvent
- `EconomicEvent.Posted` v1 — existing schema

Primary consumers:
- analytics
- settlements/data quality
- reporting projections

### AvailabilityBlock
- `AvailabilityBlock.Created` v1
- `AvailabilityBlock.Ended` v1

Consumers:
- availability/read models
- Reservation conflict detection
- operations alerts
- revenue/capacity projections

### Incident
- `Incident.Reported` v1
- `Incident.Resolved` v1

Consumers:
- safety/block automation
- maintenance
- notifications
- downtime analytics

### Turnover
- `Turnover.Ready` v1

Consumers:
- Unit current-state projection
- arrival readiness
- operations notifications

### Folio
- `Folio.Closed` v1

Consumers:
- guest portal/read model
- finance reconciliation/data-quality

### FinancialPeriod
- `FinancialPeriod.HardClosed` v1
- `FinancialPeriod.Reopened` v1

Consumers:
- financial operations guards/read models
- audit/notifications

### Guest identity
- `GuestProfile.Merged` v1
- `GuestProfile.MergeUndone` v1

Consumers:
- CRM projection
- repeat-guest analytics
- search/indexing

## Event payload rule

Payload contains domain facts required by consumers, not arbitrary full table snapshots.

Sensitive PII should normally be referenced by IDs rather than copied into event payload.

## Correlation/causation

Cross-domain chain example:

`Stay.CheckedOut`
→ AutomationExecution
→ `Turnover.Created`
→ Tasks
→ `Turnover.Ready`

All descendants share `correlation_id`; each direct child points `causation_id` to its triggering event.

## Consumer rule

Event handling is idempotent by `(consumer/action key, event_id)`.
A consumer never assumes exactly-once transport; it creates exactly-one business effect.
