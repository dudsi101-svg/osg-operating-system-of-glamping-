# OSG — Parallel Implementation Backlog v0.1

Status: implementation planning
Data: 2026-09-14

## 1. Cel

Rozbić przyszłą implementację tak, aby wiele agentów mogło pracować równolegle bez konfliktów write scope.

## 2. Wave A — Foundation

### A1 Database Core
Owner: Foundation/DB Agent
Writes:
- organizations
- parties
- properties
- audit/event infrastructure
Depends on: none
Blocks: all domain persistence

### A2 Identity & Permissions
Owner: Identity Agent
Writes:
- user accounts
- roles
- permissions
- role assignments
Depends on: A1

### A3 Contracts Package
Owner: Contracts Agent
Writes:
- OpenAPI
- event schemas
- shared error model
Depends on: current docs only
Can run parallel with A1/A2.

### A4 Test Harness
Owner: QA Agent
Writes:
- DB fixture harness
- invariant tests
- scenario runner
Depends on: schema proof

## 3. Wave B — Property + Stay

### B1 Property Domain
Owner: Property Agent
Writes only property module + migrations.

### B2 Reservation Domain
Owner: Stay/Reservation Agent
Depends on: A1, B1 public contracts

### B3 Stay Domain
Owner: Stay Agent
Depends on: B2 + Unit contract

### B4 Operations Projection
Owner: Operations Agent
Can start from contracts while B3 is implemented.

## 4. Wave C — Commerce + Financial Truth

### C1 Folio/Charges
Owner: Commerce Agent

### C2 Payments
Owner: Commerce/Payments Agent

### C3 Financial Core
Owner: Finance Agent
Writes:
- economic events
- allocations
- posting workflow
No other agent writes finance core.

### C4 Settlements
Owner: Finance Agent / separate task after C3 contracts stable

## 5. Wave D — Operations + Experience

### D1 Turnover/Task
Owner: Operations Agent

### D2 Incident/Maintenance
Owner: Maintenance Agent

### D3 Services/Resources
Owner: Experience Agent

Cross-domain interactions only via agreed commands/events.

## 6. Wave E — Integrations + Analytics

### E1 Integration Framework
Owner: Integration Agent

### E2 First Reservation Adapter
Blocked until real PMS/source known.

### E3 Metrics
Owner: Analytics Agent
Read-only over domain facts/projections.

### E4 Command Center
Owner: Product/UI Agent
Consumes projections/API; does not create parallel business logic.

## 7. Write scope rule

At any moment each file/module/migration has one writer.
Review agents use comments/PR review, not direct competing commits.

## 8. Integration gates

After each wave:
- invariant suite
- scenario suite
- contracts compatibility
- tenant/security checks
- documentation update

## 9. First actual coding tasks

Recommended initial four parallel branches:
1. `agent/db/core-schema`
2. `agent/contracts/api-events`
3. `agent/qa/invariant-harness`
4. `agent/identity/rbac-core`

Property domain starts after DB base contracts stabilize.

## 10. Rule

No agent creates a convenience shortcut crossing another domain merely to unblock itself. If contract missing: propose contract, mark dependency, review, then implement.
