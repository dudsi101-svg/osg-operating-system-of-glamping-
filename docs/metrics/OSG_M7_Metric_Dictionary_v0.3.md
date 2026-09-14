# OSG — M7 Metric Dictionary v0.3

Status: canonical pre-freeze candidate
Date: 2026-09-15
Supersedes: v0.2 for occupancy/accommodation-night semantics.

## Core distinction

OSG separates:
1. **Sellable Unit Night** — capacity that could be sold.
2. **Commercial Accommodation Night** — delivered/sold accommodation night.
3. **Physical Utilization** — actual physical use from StaySegments.

These concepts must not be used interchangeably.

## OSG_OCCUPANCY_V1

Question: jaki procent efektywnej komercyjnej pojemności noclegowej został wykorzystany przez dostarczone noce?

Formula:
`resolved_final_commercial_accommodation_nights / effective_commercial_capacity_nights`

Where:
`effective_commercial_capacity_nights = raw_sellable_unit_nights OR already-delivered commercial nights`

Reason: a retrospective AvailabilityBlock cannot erase from denominator an accommodation night that was actually delivered. The overlap is still surfaced as Data Quality/operations conflict.

Source:
- `osg_commercial_accommodation_nights()`
- `osg_unit_night_facts()`
- `osg_property_occupancy_metrics()`

Historical reports use FINAL commercial-night facts. PROVISIONAL active-stay nights must be labeled when used for real-time view.

## OSG_RAW_SELLABLE_CAPACITY_V1

Count of unit-nights with sellable_capacity=true before the delivered-night protection described above.

Used for availability diagnostics and explainability, not blindly as the standard historical occupancy denominator.

## OSG_PHYSICAL_UTILIZATION_V1

Question: jak intensywnie fizycznie wykorzystywano bazę?

Based on actual StaySegment occupation/time, independent of commercial-night accounting.

Can be expressed as:
- occupied unit-hours / physical unit-hours,
- normalized occupied unit-night intervals / physical unit-nights.

This is an operational/asset-use metric, not standard hospitality Occupancy.

## OSG_ADR_V1

Formula:
`net_recognized_accommodation_revenue / resolved_final_commercial_accommodation_nights`

Revenue source:
POSTED REVENUE Allocations attributable to accommodation Charges, respecting NORMAL/REVERSAL direction.

Late checkout does not create an extra ADR denominator night unless commercial accommodation itself was extended.
No-show/cancellation fee does not create an accommodation night.

Canonical implementation:
`osg_property_revenue_metrics()`.

## OSG_REVPAR_V1

Formula:
`net_recognized_accommodation_revenue / effective_commercial_capacity_nights`

## OSG_TREVPAR_V1

Formula:
`net_recognized_total_property_revenue / effective_commercial_capacity_nights`

## OSG_ALOS_V1

Formula:
`final_commercial_accommodation_nights / completed_stays`

This avoids physical late-checkout hours creating a fake additional night.

## OSG_DIRECT_BOOKING_SHARE_V1

Period semantics: Reservation.booked_at in Property timezone.

`direct_confirmed_bookings / all_confirmed_bookings`

Direct channels: DIRECT + DIRECT_ASSISTED.

## OSG_DIRECT_REVENUE_SHARE_V1

Economic-period metric:
`recognized revenue attributed to direct channels / recognized revenue with known channel`

Separate from booking acquisition share.

## OSG_OTA_COST_V1

`net OTA_COMMISSION allocations + attributable payment/channel fees`

Never infer OTA cost solely as guest-price minus bank payout.

## OSG_STAY_CM_V1

`net stay revenue - net direct variable OPEX`

Canonical implementation:
`osg_stay_contribution_margin()`.

## OSG_UNIT_CONTRIBUTION_MARGIN_V1

`net unit revenue - net direct unit OPEX`

## OSG_UNIT_OPERATING_MARGIN_V1

`net unit revenue - direct OPEX - shared OPEX - allocated overhead`

CAPEX shown separately.

## OSG_CAPEX_PER_UNIT_V1

Net CAPEX Allocations attributed to Unit in selected economic period.

## OSG_MAINTENANCE_COST_PER_UNIT_V1

Net Maintenance OPEX allocated to Unit in economic period.

## OSG_REVENUE_PER_GUEST_V1

`net recognized Stay revenue / actual_guest_count`

If actual_guest_count missing → INSUFFICIENT_DATA.

## OSG_UPSELL_PER_COMPLETED_STAY_V1

`net service/add-on revenue / completed_stays`

## OSG_REPEAT_GUEST_RATE_V1

`completed stays whose canonical guest identity had an earlier completed Stay / eligible completed stays`

Identity resolution uses GuestProfileAlias provenance and affects confidence.

## OSG_INCIDENT_DOWNTIME_V1

Report separately:
- physical downtime hours,
- sellability-impact hours,
- affected raw sellable unit-nights.

Not equal to lost revenue.

## OSG_ESTIMATED_LOST_REVENUE_V1

Scenario/estimate only:
`affected demand-capable nights × reference expected revenue model`

Must expose model version, assumptions and confidence.

## OSG_BREAK_EVEN_OCCUPANCY_V1

Scenario metric with pinned assumptions:
`fixed operating costs / expected contribution per sold accommodation night / effective capacity`

## OSG_DATA_CONFIDENCE_V1

Value-weighted confidence:
`sum(abs(allocation_amount) × confidence_weight) / sum(abs(allocation_amount))`

Weights:
VERIFIED=1.00; SYSTEM_DERIVED=0.95; ESTIMATED=0.60; MANUAL=0.50; UNKNOWN=0.00.

## OSG_CASH_CHANGE_V1

`cash inflows - cash outflows` across selected Property MoneyAccounts.

Never label as profit/economic result.

## Explainability

Every metric response identifies:
- metric version,
- period/grain,
- PropertyStayPolicy version where relevant,
- source fact counts,
- unresolved commercial nights,
- data confidence,
- anomalies and explain route.
