# OSG — Implementation Architecture v0.1

Status: implementation-ready candidate
Data: 2026-09-14

## 1. Monorepo

apps/
- web/        Next.js PWA
- api/        FastAPI

packages/
- contracts/  OpenAPI/event schemas/shared contracts
- ui/         shared UI components
- config/     shared configuration

backend modules (inside api or src/modules):
- foundation
- property
- reservations
- stays
- commerce
- experiences
- operations
- finance
- analytics
- integrations
- identity
- audit

infrastructure/
- db
- migrations
- observability
- deployment

## 2. Backend boundaries

Each module owns:
- domain models
- services/use cases
- repository interfaces
- API routes
- emitted events
- tests

Modules do not query another module's tables directly from application logic unless explicitly approved as read model/query layer.

## 3. Write path

HTTP/API command
→ authentication
→ authorization
→ validation
→ domain service
→ transaction
→ persistence
→ domain event outbox
→ response

## 4. Read path

HTTP query
→ authorization
→ optimized query/read model
→ response

Read models may denormalize data, but remain projections.

## 5. Event outbox

Domain events created in the same DB transaction as state change are stored in an outbox.
Background worker publishes/processes them idempotently.

This avoids state committed but event lost.

## 6. Background worker

Responsibilities:
- event handlers
- integrations
- retries
- reports
- notifications
- data-quality scans

Worker shares contracts but not uncontrolled direct business mutations.

## 7. Database access

PostgreSQL is primary source for OSG-owned state.
Use explicit transaction boundaries.
Financial posting and concurrency-sensitive availability/resource operations use serialized/locked workflows where required.

## 8. Frontend

Primary application surfaces:
- Command Center
- Property
- Reservations & Stays
- Operations
- Financial Truth
- Settlements
- Experiences
- Guest CRM
- Revenue/Analytics
- Maintenance
- Settings/Integrations

Frontend never reimplements authoritative business rules that belong to API/domain layer.

## 9. Authentication

External identity provider acceptable.
OSG maintains UserAccount/RoleAssignment mapping and authorization semantics.

## 10. File storage

Binary files in object storage.
DB stores FileObject metadata, checksum, classification and typed links.

## 11. Observability

Minimum:
- structured logs
- request/correlation IDs
- error tracking
- integration sync health
- job failures
- health endpoints
- DB migration status

## 12. Environment separation

DEV: synthetic data
STAGING: production-like configuration, non-production data
PROD: live Glamping Nad Stawem data

No production credentials or exports in DEV repository fixtures.

## 13. Technology candidate

Frontend: Next.js + TypeScript
API: FastAPI + Python
DB: PostgreSQL
Object storage/auth: managed provider acceptable
Deployment: web and API independently deployable

These choices are implementation candidates; domain contracts remain technology-neutral.
