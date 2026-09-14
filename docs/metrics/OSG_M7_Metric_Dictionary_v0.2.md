# OSG — M7 Metric Dictionary v0.2

Status: canonical pre-freeze candidate
Date: 2026-09-15

## 1. Metric contract

Every metric defines:
- code + version
- business question
- grain
- period semantics
- numerator
- denominator
- inclusion/exclusion rules
- source facts
- canonical SQL/API implementation
- confidence/explainability behavior

A formula change that changes business meaning creates a new metric version.

---

## OSG_OCCUPANCY_V1

**Question:** jaki procent sprzedawalnych unit-nights był faktycznie zajęty?

Grain: Property × period.

Period: local unit-night date using versioned PropertyStayPolicy.

Formula:
`occupied_sellable_unit_nights / sellable_unit_nights`

Source:
`osg_unit_night_facts()`.

Rules:
- actual StaySegment is occupancy truth,
- AvailabilityBlock(sellability_impact=true) removes denominator,
- confirmed Reservation alone does not create occupancy,
- occupied + non-sellable is surfaced as conflict/data-quality condition.

---

## OSG_PHYSICAL_OCCUPANCY_V1

Formula:
`occupied_unit_nights / physical_unit_nights`

Purpose: physical use of inventory, including periods where a unit may have become non-sellable operationally.

---

## OSG_ADR_V1

Question: ile średnio rozpoznanego noclegowego revenue przypada na faktycznie sprzedaną/zajętą noc?

Formula:
`net_recognized_accommodation_revenue / sold_unit_nights`

Revenue source:
POSTED revenue Allocations linked to accommodation Charges; NORMAL/REVERSAL direction respected.

Denominator:
actual occupied unit-nights.

Canonical implementation:
`osg_property_revenue_metrics()`.

---

## OSG_REVPAR_V1

Formula:
`net_recognized_accommodation_revenue / sellable_unit_nights`

Canonical implementation:
`osg_property_revenue_metrics()`.

---

## OSG_TREVPAR_V1

Formula:
`net_recognized_total_property_revenue / sellable_unit_nights`

Includes economically allocated accommodation + experiences/add-ons/other managerial revenue.

Does not infer revenue from bank deposits.

---

## OSG_ALOS_V1

Question: jak długo faktycznie trwa przeciętny zakończony pobyt?

Formula:
`actual_occupied_stay_nights / completed_stays`

Rules:
- Stay status CHECKED_OUT,
- split StaySegments do not double-count the same Stay night,
- cancelled/no-show reservations excluded.

---

## OSG_DIRECT_BOOKING_SHARE_V1

Question: jaki udział potwierdzonych bookingów utworzonych w okresie pochodzi z kanałów direct?

Period semantics: Reservation.booked_at converted to Property timezone.

Formula:
`direct_confirmed_bookings / all_confirmed_bookings`

Direct Channel types:
DIRECT + DIRECT_ASSISTED.

Canonical implementation:
`osg_channel_booking_metrics()`.

Important: this is acquisition-period metric, not stay-period metric.

---

## OSG_DIRECT_REVENUE_SHARE_V1

Question: jaki udział rozpoznanego revenue w okresie ekonomicznym pochodzi z rezerwacji direct?

Formula:
`recognized_revenue_attributed_to_direct_channels / recognized_revenue_with_known_channel`

Period: EconomicEvent.economic_date.

Separate metric from booking share.

---

## OSG_OTA_COST_V1

Formula:
`net OTA_COMMISSION allocations + attributable payment/channel fees`

Period: economic date.

OTA cost is economic cost, not difference between guest price and bank payout inferred without evidence.

---

## OSG_STAY_CM_V1

Question: ile pobyt zostawił po bezpośrednich kosztach zmiennych?

Formula:
`net_stay_revenue - net_direct_variable_opex`

Source:
Allocations linked to Stay.

Canonical implementation:
`osg_stay_contribution_margin()`.

Excludes shared/overhead OPEX and CAPEX.

---

## OSG_UNIT_CONTRIBUTION_MARGIN_V1

Formula:
`net_unit_revenue - net_direct_unit_opex`

---

## OSG_UNIT_OPERATING_MARGIN_V1

Formula:
`net_unit_revenue - direct_opex - shared_opex - allocated_overhead`

CAPEX excluded and shown separately.

Canonical implementation:
`osg_unit_economics()`.

---

## OSG_CAPEX_PER_UNIT_V1

Formula:
`net CAPEX allocations attributed to Unit in selected economic period`

This is an investment view, not an operating expense metric.

---

## OSG_MAINTENANCE_COST_PER_UNIT_V1

Formula:
`net OPEX allocations with Maintenance cost center/category attributed to Unit`

Period: economic date.

Can be accompanied by Incident count and downtime.

---

## OSG_REVENUE_PER_GUEST_V1

Formula:
`net recognized Stay revenue / actual_guest_count`

If actual guest count is unavailable, metric is INSUFFICIENT_DATA rather than inferred from booking count without disclosure.

Canonical implementation for single Stay:
`osg_stay_revenue_metrics()`.

---

## OSG_UPSELL_PER_COMPLETED_STAY_V1

Formula:
`net service/add-on revenue / completed_stays`

Canonical implementation:
`osg_property_upsell_metrics()`.

Does not count accommodation revenue as upsell.

---

## OSG_REPEAT_GUEST_RATE_V1

Formula:
`completed_stays whose primary guest had >=1 earlier completed Stay / eligible completed_stays with resolved GuestProfile`

Guest merge/deduplication confidence affects metric confidence.

---

## OSG_INCIDENT_DOWNTIME_V1

Formula:
Duration of AvailabilityBlocks attributable to Incidents, reported separately as:
- physical downtime hours,
- sellability-impact hours,
- affected sellable unit-nights.

Must not automatically be labeled lost revenue.

---

## OSG_ESTIMATED_LOST_REVENUE_V1

Analytical scenario metric, never actual financial loss.

Example model:
`non_sellable_unit_nights_from_incident × reference_expected_ADR_or_demand_model`

Must expose:
- model version,
- assumptions,
- confidence,
- reference rate source.

---

## OSG_BREAK_EVEN_OCCUPANCY_V1

Scenario metric.

Conceptual formula:
`fixed_operating_cost / expected_contribution_per_sold_unit_night / sellable_unit_night_capacity`

Must pin scenario assumptions. Not shown as an observed historical fact.

---

## OSG_DATA_CONFIDENCE_V1

Value-weighted confidence of material economic facts.

Reference weights:
- VERIFIED = 1.00
- SYSTEM_DERIVED = 0.95
- ESTIMATED = 0.60
- MANUAL = 0.50
- UNKNOWN = 0.00

Formula:
`sum(abs(allocation_amount) × confidence_weight) / sum(abs(allocation_amount))`

Using absolute amounts prevents reversals from artificially cancelling uncertainty.

Canonical implementation:
Financial semantic layer.

---

## OSG_CASH_CHANGE_V1

Formula:
`cash inflows - cash outflows` across selected Property MoneyAccounts.

Source:
CashMovement.

This metric must never be labeled profit, economic result or accounting result.

Canonical implementation:
`osg_property_cash_flow()`.

---

## Explainability requirement

Every KPI returns:
- metric code/version,
- period/grain,
- source fact counts,
- confidence,
- formula,
- explain/drilldown route,
- anomalies that may materially affect interpretation.

See `docs/analytics/OSG_Explainability_Contract_v0.1.md`.
