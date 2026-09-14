# ADR-011 — Commercial occupancy vs physical utilization

Status: ACCEPTED pre-freeze
Date: 2026-09-15

## Context

A physical `StaySegment` answers where a guest actually was over time. Hospitality occupancy/ADR answer a different commercial question: how many sellable accommodation nights were consumed/sold.

Using raw segment overlap as the sole sold-night fact creates errors for:
- late checkout crossing the next check-in boundary,
- relocation during daytime after the overnight service was already consumed,
- very late arrival after midnight,
- retained cancellation/no-show fees,
- operational blocking while an existing guest remains physically present.

## Decision

OSG maintains three distinct concepts.

### 1. Sellable Unit Night
Capacity denominator for a local night D.
Derived from Unit lifecycle + PropertyStayPolicy + AvailabilityBlock.

### 2. Commercial Accommodation Night
Night of accommodation actually delivered/sold for hospitality KPI.

Historical fact is derived from an executed Stay and its commercial accommodation interval, normalized to local night dates. It is not extended merely by a late checkout.

Default v1 derivation:
- Stay must exist and not be CANCELLED,
- ReservationItem must be ACTIVE,
- night dates are bounded by ReservationItem arrival/departure,
- for CHECKED_OUT early departure, nights after the actual final occupied overnight are excluded when the Stay execution clearly ended early,
- no-show without Stay creates zero commercial accommodation nights; any retained cancellation/no-show revenue is a separate revenue class and does not inflate occupancy/ADR denominator.

A future explicit `AccommodationNightFact` materialization may persist these facts once production semantics are validated.

### 3. Physical Utilization
Actual physical use over time from StaySegment.
This may be measured in hours or normalized unit-night intervals and is useful for operations/maintenance, not as the sole standard hospitality occupancy denominator.

## Relocation attribution

For a Commercial Accommodation Night D, the Unit is attributed using a configurable overnight anchor within the stay window.

Reference v1 anchor: **03:00 local time on D+1**.

The active StaySegment containing that instant owns the night.

Examples:
- guest sleeps in Forest and is relocated at 10:00 next morning → night remains Forest,
- guest relocates at 22:00 before sleeping → night belongs to destination Unit.

If no segment contains the anchor, DataQualityIssue is raised and the night remains unresolved rather than guessed.

## KPI consequences

### OSG_OCCUPANCY_V1
`commercial_accommodation_nights / sellable_unit_nights`

### OSG_ADR_V1
`recognized accommodation revenue attributable to accommodation service / commercial_accommodation_nights`

### OSG_PHYSICAL_UTILIZATION_V1
separate metric based on actual StaySegment usage.

## Forecast occupancy

Future occupancy/pace is a separate projection based on confirmed ReservationItems and must be labeled forecast/booked occupancy, not historical observed occupancy.

## Consequence

One model can now answer three different questions without false equivalence:
- what could we sell?
- what accommodation nights did we commercially deliver?
- where/how long was the property physically occupied?
