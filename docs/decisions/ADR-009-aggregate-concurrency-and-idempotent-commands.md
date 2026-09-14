# ADR-009 — Aggregate concurrency and idempotent command policy

Status: ACCEPTED pre-freeze
Date: 2026-09-15

## Context

OSG will receive concurrent writes from operators, owners, integrations, background jobs and eventually AI-assisted actions. A single concurrency strategy is inappropriate for all domains.

## Decision

OSG uses three complementary strategies.

### 1. Optimistic concurrency — mutable aggregates

Use `row_version` + API `If-Match` for normal human/API state changes:
- Reservation
- Stay
- Folio
- ServiceBooking
- Turnover
- Task
- Incident
- selected master data

Stale command → stable `VERSION_CONFLICT` response; client reloads/re-evaluates.

### 2. Transactional pessimistic locking — capacity/conservation workflows

Use explicit DB transaction + row/advisory lock where accepting two simultaneous writes would violate capacity/conservation:
- Resource capacity > 1
- SettlementApplication conservation
- Financial posting
- potentially inventory decrement where negative stock is forbidden

The lock target must be deterministic and tenant-scoped.

### 3. Append-only / immutable facts

Do not solve concurrency by in-place edit for finalized facts:
- POSTED EconomicEvent
- posted Allocation set
- DomainEvent
- AuditEvent
- StockMovement
- confirmed external/import ledger facts where policy marks them final

Corrections create new facts/reversal/adjustment and preserve history.

## Command idempotency

Every retryable mutation exposed to external clients/integrations accepts a stable `Idempotency-Key`.

The idempotency claim is created transactionally before/with business mutation. Duplicate command returns the previously committed outcome or stable in-progress/conflict semantics; it must not execute the business effect twice.

## API contract

- `If-Match`: optimistic aggregate version
- `Idempotency-Key`: duplicate command protection
- `X-Correlation-ID`: cross-domain trace

These identifiers solve different problems and are not interchangeable.

## Consequences

- normal UI edits avoid heavy locking,
- capacity/financial invariants are protected under concurrency,
- retries are safe,
- history remains auditable,
- agent sessions cannot silently overwrite each other's accepted aggregate changes.

## Rejected alternatives

- last-write-wins for all entities,
- SERIALIZABLE transaction isolation for the entire application,
- database locks for every UI edit,
- treating idempotency keys as optimistic version checks.
