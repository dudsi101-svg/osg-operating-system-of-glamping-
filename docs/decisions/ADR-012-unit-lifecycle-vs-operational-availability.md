# ADR-012 — Unit lifecycle vs temporary operational availability

Status: ACCEPTED pre-freeze
Date: 2026-09-15

## Context

A current `Unit.lifecycle_status = OUT_OF_SERVICE` cannot safely be used in historical capacity calculations. If Forest is temporarily disabled today, that current status must not make Forest appear unavailable for every historical night.

OSG already has a time-bounded entity designed for operational availability: `AvailabilityBlock`.

## Decision

`Unit.lifecycle_status` describes long-lived existence lifecycle only:
- PLANNED
- ACTIVE
- RETIRED

Temporary or episodic conditions are not Unit lifecycle states.

Examples handled by AvailabilityBlock / operations:
- maintenance,
- renovation,
- safety block,
- owner use,
- temporary technical failure,
- seasonal short-term closure.

## Historical capacity

Physical capacity for date D is derived from:
- commissioned_at,
- retired_at,
- lifecycle existence.

Sellability for a unit-night is then modified by time-bounded AvailabilityBlocks.

## Current UI state

The UI may show a derived current state such as:
- AVAILABLE
- OCCUPIED
- DIRTY
- BLOCKED
- OUT_OF_SERVICE

but this is a projection from Unit + Stay + Turnover + AvailabilityBlock + Incident, not a mutable source field on Unit.

## Consequences

- historical Occupancy/RevPAR does not change when a unit is blocked today,
- operational history is explicit and auditable,
- Digital Twin can explain why/when a Unit was unavailable,
- one current enum no longer overwrites time-dependent truth.
