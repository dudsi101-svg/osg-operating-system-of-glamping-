# ADR-005 — Event-driven cross-domain coordination

Status: accepted
Date: 2026-09-14

## Decision

OSG uses Domain Events for cross-domain reactions while keeping transactional state changes inside aggregates.

Examples:
- Stay.CheckedOut → Turnover.Create
- Service.Booked → ResourceReservation.Create + Charge.Create
- EconomicEvent.Posted + payer/bearer mismatch → SettlementEntry.Create

## Why

Direct cross-domain mutation increases coupling and makes parallel development by specialized agents unsafe.

## Consequences

- events require versioned schemas
- handlers must be idempotent
- eventual consistency is acceptable between aggregates
- automation execution history is observable
- hidden side effects are prohibited
