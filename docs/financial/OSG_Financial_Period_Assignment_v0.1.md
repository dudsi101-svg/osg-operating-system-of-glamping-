# OSG — Financial Period Assignment v0.1

Status: pre-freeze P0 contract
Date: 2026-09-15

## 1. Rule

Every `POSTED` EconomicEvent must reference a `FinancialPeriod` that:
- belongs to the same Organization,
- covers `economic_date`,
- matches Property scope,
- is not HARD_CLOSED at posting time.

A POSTED event with `financial_period_id = NULL` is invalid.

## 2. Property scope

For Property-owned EconomicEvent:
`FinancialPeriod.property_id = EconomicEvent.property_id`.

For explicit Organization-level EconomicEvent:
`FinancialPeriod.property_id IS NULL`.

OSG does not silently move a Property event into an organization-level period to bypass closure.

## 3. Assignment

Posting workflow may auto-resolve the unique matching FinancialPeriod by date/property if exactly one exists.

If:
- none exists → `FINANCIAL_PERIOD_REQUIRED`,
- more than one overlapping period exists → configuration/data-quality error,
- target is HARD_CLOSED → `FINANCIAL_PERIOD_HARD_CLOSED`.

## 4. Period integrity

For the same `(organization_id, property_id)` periods must not overlap.

This should be a DB-level exclusion/constraint proof before v1.0.

## 5. Adjustments

A current-period adjustment concerning a historical period has:
- `financial_period_id` = current recognition period,
- `relates_to_financial_period_id` = historical period,
- `economic_date` within current recognition period,
- explicit reason,
- REVERSAL/NORMAL direction as appropriate.

## 6. Why

Without mandatory period assignment, HARD_CLOSE is only cosmetic because unassigned events could mutate historical economics outside period controls.
