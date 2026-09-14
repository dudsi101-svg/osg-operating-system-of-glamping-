# OSG — M6 Permissions & Security v0.1

Status: roboczy
Data: 2026-09-14

## 1. Model

RBAC z ograniczonym ABAC:
UserAccount → RoleAssignment → Role → Permission
RoleAssignment ma scope Organization lub Property.

## 2. Baseline roles

ORG_ADMIN
OWNER
FINANCE
OPERATOR
HOUSEKEEPING
MAINTENANCE
ACCOUNTANT
READ_ONLY
GUEST
INTEGRATION_SERVICE
AI_SERVICE

## 3. Permission namespaces

property.*
reservation.*
stay.*
guest.*
service.*
operations.*
incident.*
asset.*
financial.document.*
financial.cash.*
financial.economic.*
financial.allocation.*
settlement.*
analytics.*
integration.*
user.*
audit.*

## 4. Sensitive access

Financial, personal i security-related data mają field-level restrictions tam, gdzie entity-level permission jest za szerokie.

## 5. Least privilege

Housekeeping widzi informacje potrzebne do wykonania pracy, nie pełne dane finansowe/gościa.
Accountant widzi dokumenty i eksport, nie musi zarządzać pobytami.
Guest widzi wyłącznie własny pobyt i dozwolone usługi.
AI_SERVICE nie posiada większych uprawnień niż użytkownik inicjujący żądanie.

## 6. Approval separation

Wysokiego ryzyka workflow powinny wspierać separation of duties:
creator != approver dla konfigurowalnych klas zmian.

## 7. Audit

Logowane są:
- login/security events
- permission changes
- financial approvals
- manual overrides
- data export
- sensitive record access, jeśli wymagane

## 8. Service accounts

Integracje korzystają z oddzielnych identities.
Brak współdzielonych kont operatorów dla integracji.

## 9. MFA

MFA obowiązkowe docelowo dla:
ORG_ADMIN
OWNER
FINANCE
i użytkowników z prawem approval high-risk.

## 10. AI policy

AI działa przez semantic/API layer.
Brak bezpośredniego unrestricted DB access.
Write actions wymagają tych samych permissions i audit trail co działania człowieka.
