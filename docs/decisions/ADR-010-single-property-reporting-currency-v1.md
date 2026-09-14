# ADR-010 — Single Property reporting currency in Release 1

Status: ACCEPTED pre-freeze
Date: 2026-09-15

## Context

OSG source facts may originate in different currencies (bank, OTA, invoice), but managerial KPI cannot safely sum mixed currencies without an explicit FX model.

Release 1 targets Glamping Nad Stawem with PLN reporting and explicitly excludes full multi-currency accounting.

## Decision

Each Property has one reporting currency (`Property.currency`).

For a Property-owned POSTED EconomicEvent:
`EconomicEvent.currency = Property.currency`.

Therefore all Allocations and Semantic Layer managerial KPI for that Property are directly additive.

## Source currency preservation

Source facts may retain original currency:
- FinancialDocument
- CashMovement
- Payment
- Refund

If a source fact differs from Property reporting currency, conversion must occur explicitly before EconomicEvent POST.

Release 1 may initially require manual/verified converted economic value if no FX engine exists.

## Future extension

A later additive model may introduce:
- FxConversion / FxRateSource
- source amount/currency
- reporting amount/currency
- realized FX differences

This must not alter the meaning of existing v1 Property reporting metrics.

## Consequence

Semantic functions can safely return a single currency for Property-level economic KPI.
They must fail/data-quality flag mixed-currency POSTED EconomicEvents rather than silently summing them.
