# OSG — Semantic API Contract v0.1

Status: pre-freeze candidate
Date: 2026-09-15

## 1. Purpose

Expose stable business meaning to UI, reports and AI without allowing each consumer to reinterpret raw tables.

Semantic API is read-oriented. Commands remain in domain APIs.

## 2. Core query families

### Property performance
`GET /v1/semantic/properties/{property_id}/performance?from=&to=`

Returns:
- accommodation_revenue
- total_revenue
- allocated_opex
- economic_operating_result
- capex
- sellable_unit_nights
- sold_unit_nights
- occupancy
- ADR
- RevPAR
- TRevPAR
- weighted_data_confidence

### Unit economics
`GET /v1/semantic/properties/{property_id}/units/performance?from=&to=`

Per Unit:
- revenue
- direct_opex
- shared_opex
- overhead
- contribution_margin
- operating_margin
- capex
- occupancy
- ADR/RevPAR where meaningful
- maintenance cost
- incident downtime
- data confidence

### Stay economics
`GET /v1/semantic/stays/{stay_id}/economics`

Returns:
- recognized revenue
- direct variable cost
- contribution margin
- source allocations
- confidence

### Cash
`GET /v1/semantic/properties/{property_id}/cash-flow?from=&to=`

Returns cash-only facts. Must never be labeled profit.

### Settlements
`GET /v1/semantic/settlements/open`

Returns current derived balances by creditor/debtor/currency.

### Operations now
`GET /v1/semantic/properties/{property_id}/operations/today`

Returns:
- arrivals
- departures
- turnovers
- blocked/at-risk units
- service/resource schedule
- incidents
- urgent stock issues

### Data Quality
`GET /v1/semantic/properties/{property_id}/data-quality`

Returns open issues, severity, affected metrics and confidence summary.

## 3. Required metadata on every KPI response

Every metric object includes:
- `metric_code`
- `metric_version`
- `value`
- `currency/unit`
- `period`
- `grain`
- `data_confidence`
- `as_of`
- `explain_url`

## 4. AI access

AI reads through the same Semantic API under the initiating user's authorization context.

AI must not:
- bypass permission scope,
- reinterpret Accounting/Cash/Economic results as interchangeable,
- use raw tables when a canonical metric exists,
- hide estimated/manual allocation confidence.

## 5. Metric stability

Changing formula semantics creates a new metric version.
Historical reports can request/pin an explicit version when required.

## 6. Error semantics

Semantic endpoints use OSG stable error model:
- `INVALID_PERIOD`
- `PROPERTY_NOT_FOUND`
- `SEMANTIC_POLICY_MISSING`
- `INSUFFICIENT_DATA`
- `FORBIDDEN`

`INSUFFICIENT_DATA` is preferable to fabricated zero where denominator/source facts are unavailable.

## 7. Explainability

Every material metric must support drill-down to source facts. See `OSG_Explainability_Contract_v0.1.md`.
