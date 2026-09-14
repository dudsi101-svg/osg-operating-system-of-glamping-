# OSG — Role-Based Information Architecture v0.1

Status: product architecture
Data: 2026-09-14

## 1. Cel

OSG nie powinien mieć jednego identycznego interfejsu dla wszystkich. Każda rola otrzymuje perspektywę dopasowaną do decyzji i zadań, które rzeczywiście wykonuje.

## 2. Wspólny rdzeń

Wszystkie perspektywy korzystają z tych samych encji i API. Różnią się:
- priorytetem informacji,
- zakresem danych,
- dozwolonymi akcjami,
- poziomem szczegółowości.

## 3. OWNER / FINANCE

Start: Owner Finance Cockpit.

Primary navigation:
- Overview
- Financial Truth
- Settlements
- Revenue
- Investments
- Units economics
- Approvals
- Reports

Secondary:
- Reservations read
- Operations read
- Assets/Maintenance
- Integrations/Data Health

## 4. OPERATOR

Start: Operations Center.

Primary:
- Today
- Arrivals
- Departures
- Turnovers
- Services
- Tasks
- Incidents
- Guests

Secondary:
- Units/Resources
- basic revenue/economic indicators allowed by role
- stock
- maintenance

Operator nie zaczyna od P&L.

## 5. HOUSEKEEPING

Start: My Tasks / Units to Prepare.

Visible:
- Unit
- checkout/next arrival timing
- cleaning checklist
- operational guest requirements
- issue reporting
- photo attachment

Hidden by default:
- pricing
- revenue
- settlements
- owner finances
- unnecessary guest PII

## 6. MAINTENANCE

Start: Incidents / Work Orders.

Visible:
- affected asset/resource/unit
- severity
- technical history
- warranty info
- tasks/work logs
- attachments
- required readiness deadline

Financial visibility ograniczona do potrzebnego kosztu/estimate scope.

## 7. ACCOUNTANT

Start: Finance Documents / Export / Reconciliation status.

Visible:
- FinancialDocuments
- document lines
- accounting metadata
- exports
- economic classification where permission allows
- unresolved reconciliation

Nie zarządza operacyjnym Stay/Tasks.

## 8. GUEST

Start: Your Stay.

Zakres zgodny z Guest Portal Contract.

## 9. ORG_ADMIN

Start: Organization Health.

Primary:
- properties
- users/roles
- integrations
- configuration
- audit/security
- data quality

## 10. Mobile priority

Operator/Housekeeping/Maintenance: mobile-first.
Owner/Finance: responsive desktop/tablet-first with mobile summary.
Guest: mobile-first.

## 11. Cross-role shortcuts

OSG może pokazywać deep links zależne od context, np. Owner widzi problem rentowności Forest → otwiera Unit → incidents/maintenance history bez zmiany źródła prawdy.

## 12. Notification policy

Powiadomienie musi odpowiadać roli:
- operator: action required,
- owner: material risk/approval,
- housekeeping: assigned task/deadline,
- maintenance: incident/work order,
- accountant: document/reconciliation exception,
- guest: own stay/service.

## 13. Principle

Navigation follows responsibility, not database tables.