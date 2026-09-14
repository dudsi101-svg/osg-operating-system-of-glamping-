# ADR-007 — UUIDv7 as application-generated canonical identifiers

Status: Accepted
Date: 2026-09-14

## Context

OSG requires globally unique, stable identifiers that are reasonably index-friendly and sortable by creation time. Early proof SQL used PostgreSQL `gen_random_uuid()`, which produces UUIDv4 and conflicts with the documented UUIDv7 decision.

## Decision

Canonical OSG business entity IDs use UUIDv7.

UUIDv7 is generated in the application/shared ID layer before INSERT. PostgreSQL stores it as native `uuid` and does not need to own ID generation for core business entities.

## Consequences

- schema is not coupled to a database-specific UUIDv7 function/version,
- IDs can be generated before persistence and used in events/outbox in one transaction,
- ordered UUIDs improve index locality compared with fully random UUIDv4,
- tests must verify valid UUID shape/version where relevant,
- DB proof scripts may use deterministic fixture UUIDs.

## Exceptions

Purely internal ephemeral/technical rows may use database-generated UUID where explicitly documented, but external/domain identities remain UUIDv7.

## Migration from proof v0.1

`gen_random_uuid()` defaults in proof schema are not canonical and should be removed in schema v0.95 candidate. Existing proof data has no production compatibility requirement.