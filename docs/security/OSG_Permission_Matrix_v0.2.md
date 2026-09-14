# OSG — Permission Matrix v0.2

Status: pre-freeze candidate
Date: 2026-09-15

Legend:
- **RW** read/write/execute within assigned scope
- **R** read only
- **A** approval authority subject to policy/threshold
- **L** limited/field-filtered read
- **—** no access by default

Roles are permission bundles, not hard-coded identities. RoleAssignment is scoped to Organization or Property.

## 1. Baseline role matrix

| Capability | ORG_ADMIN | OWNER | FINANCE | OPERATOR | HOUSEKEEPING | MAINTENANCE | ACCOUNTANT | READ_ONLY |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Property master read | RW | R | R | R | L | L | R | R |
| Property master manage | RW | — | — | — | — | — | — | — |
| Unit/Resource config | RW | R | R | RW | L | RW* | R | R |
| Reservation read | R | R | R | RW | L | L | R | R |
| Reservation create/edit | — | — | — | RW | — | — | — | — |
| Reservation cancel | — | — | — | RW | — | — | — | — |
| Stay check-in/out | — | — | — | RW | — | — | — | — |
| Stay relocate | — | — | — | RW | — | R | — | — |
| Guest operational contact | — | L | — | RW | L | L | — | — |
| Guest full CRM/PII | R | R | — | L | — | — | — | — |
| Guest marketing consent | — | R | — | RW | — | — | — | — |
| Turnover read/update | R | R | — | RW | RW | L | — | R |
| Task read/update | R | R | — | RW | RW | RW | — | R |
| Incident report | RW | RW | — | RW | RW | RW | — | R |
| Incident resolve/close | RW | R | — | RW | — | RW | — | R |
| Asset/service history | R | R | R | R | L | RW | R | R |
| WorkOrder manage | RW | R | R | RW | — | RW | R | R |
| Service booking | R | R | R | RW | L | L | — | R |
| Folio/Charge operational read | R | R | R | RW | — | — | R | R |
| Add normal guest Charge | — | R | R | RW | — | — | — | — |
| Record Payment | — | R | RW | RW* | — | — | R | — |
| FinancialDocument read | R | RW | RW | L* | — | L* | RW | R* |
| FinancialDocument upload/draft | RW | RW | RW | RW* | — | RW* | RW | — |
| CashMovement read | R | RW | RW | — | — | — | R | R* |
| Cash import/reconcile | RW | RW | RW | — | — | — | R | — |
| EconomicEvent read | R | RW | RW | L | — | L | R | R* |
| EconomicEvent create draft | RW | RW | RW | RW* | — | RW* | — | — |
| Allocation edit draft | RW | RW | RW | RW* | — | RW* | — | — |
| Post EconomicEvent | A/RW | A/RW | RW* | — | — | — | — | — |
| Reverse/adjust posted event | A/RW | A/RW | RW* | — | — | — | — | — |
| Allocation approval | A | A | A* | — | — | — | — | — |
| Settlement read | R | RW | RW | L* | — | — | R | R* |
| Settlement apply repayment | RW | RW | RW | — | — | — | — | — |
| Settlement manual correction | A | A | A* | — | — | — | — | — |
| Analytics/KPI read | R | R | R | R | L | L | R | R |
| Data Quality read | R | R | R | R | L | L | R | R |
| Data Quality resolve/ignore | RW | RW | RW | RW* | — | RW* | — | — |
| Integration health read | R | R | R | R | — | — | R | R |
| Integration configure | RW | — | — | — | — | — | — | — |
| User/Role manage | RW | — | — | — | — | — | — | — |
| Audit read | R | R | R | — | — | — | R* | — |
| Sensitive export | A/RW | A/RW | RW* | — | — | — | RW* | — |

`*` means policy-limited subset rather than unconditional permission.

## 2. Operator expense boundary

OPERATOR may submit expenses/receipts and propose business allocation if policy allows, but cannot independently approve/post high-risk or above-threshold economic facts.

This supports Kuba-like workflow without giving unrestricted financial authority.

Example:
Operator uploads receipt → creates Draft FinancialDocument/EconomicEvent proposal → Finance/Owner verifies/posts where required.

## 3. Maintenance financial boundary

MAINTENANCE may attach estimated cost, receipt or contractor document to WorkOrder/Incident, but cannot silently convert technical estimate into POSTED OPEX/CAPEX.

## 4. Accountant boundary

ACCOUNTANT primarily accesses:
- source documents,
- export/accounting status,
- reconciliation evidence required for accounting,
- tax/accounting fields where configured.

ACCOUNTANT does not become owner of OSG Economic Truth merely because the accounting system classifies a document.

## 5. Field-level restrictions

### Guest fields

Operational minimum may include:
- display name,
- stay/unit,
- guest count,
- arrival/departure,
- operational requests relevant to assigned work.

Restricted by default:
- full contact history,
- marketing consent history,
- sensitive notes,
- identity documents if ever introduced,
- unrelated historical stays.

### Finance fields

Restricted by default:
- full bank account identifiers,
- owner/private funding details,
- tax IDs beyond need,
- settlement balances,
- non-business allocation details.

Housekeeping/Maintenance do not receive these fields.

## 6. Approval separation

Configurable high-risk policies may require:
- creator != approver,
- Finance + Owner double approval,
- threshold-specific approval,
- explicit rationale.

Examples:
- large MANUAL/ESTIMATED allocation,
- NON_BUSINESS reclassification,
- reversal in closed period,
- manual settlement correction,
- sensitive export.

## 7. AI_SERVICE

AI_SERVICE has no broad autonomous human-equivalent role.

Runtime rule:
`effective_permissions = initiating_user_permissions ∩ AI_allowed_actions`

High-risk write actions still execute normal approval/audit workflows.

## 8. INTEGRATION_SERVICE

Each integration identity receives only provider-specific permissions.

Examples:
- PMS adapter: reservation/source-record sync permissions
- bank importer: CashMovement import only
- messaging provider: outbound message delivery only

No generic integration superuser.

## 9. Guest

GUEST authorization is ownership-based, not broad property role.

Can access only explicitly associated Reservation/Stay/Folio/ServiceBooking and guest-portal-safe fields.

## 10. Fail closed

If property/tenant scope cannot be resolved, authorization denies the request.
Background jobs and AI tools must provide explicit Organization context.
