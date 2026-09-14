# ADR-008 — Versioned PropertyStayPolicy and canonical unit-night semantics

Status: ACCEPTED pre-freeze
Date: 2026-09-15

## Context

Occupancy, RevPAR, turnover deadlines and sellable-capacity calculations require a historical definition of the operational stay window. Hard-coding 15:00/11:00 in application code would make historical metrics change when property policy changes.

## Decision

OSG uses a versioned `PropertyStayPolicy` entity containing at minimum:
- `default_checkin_time`
- `default_checkout_time`
- `readiness_buffer`
- `valid_from`
- `valid_to`
- `version_no`

Canonical unit-night D is the property-local interval:

`[D at default_checkin_time, D+1 at default_checkout_time)`

The Property timezone is authoritative for local operational time.

## Capacity semantics

OSG keeps separate facts:
- physical unit-night capacity
- sellable unit-night capacity
- actual occupied unit-night

`AvailabilityBlock.sellability_impact=true` removes the overlapping unit-night from sellable capacity.

Actual occupancy is derived from `StaySegment`, not from Reservation status.

## Consequences

- historical metrics remain reproducible after policy changes,
- AvailabilityBlock can affect denominator without changing physical inventory,
- occupied/non-sellable overlap can be detected as an operational conflict,
- Revenue Engine and Operations Center share one definition of the night.

## Rejected alternative

Hard-coded default check-in/check-out times in frontend/backend configuration without historical versioning.
