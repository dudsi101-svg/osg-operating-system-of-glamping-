# ADR-004 — API-first and contract versioning

Status: accepted
Date: 2026-09-14

## Decision

OSG uses API-first architecture. Public/internal domain contracts that cross process/module boundaries are versioned explicitly.

Versioned artifacts include:
- OpenAPI contracts
- Domain Event schemas
- integration canonical contracts
- metric definitions
- database migration history

## Why

OSG will combine web UI, integrations, automations and AI. Shared contracts reduce hidden coupling and allow independent implementation by multiple agents/teams.

## Consequences

- breaking contract changes require explicit versioning
- UI must not become the only expression of business behavior
- AI accesses controlled APIs/semantic services rather than unrestricted database access
