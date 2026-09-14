# OSG — Approval Policy Framework v0.1

Status: kandydat do freeze
Data: 2026-09-14

## 1. Cel

Zapewnić, że ryzykowne zmiany nie zależą od jednej osoby ani od zakodowanych wyjątków specyficznych dla Michała/Kuby.

## 2. Model

ApprovalPolicy jest konfiguracją Organization/Property.
Warunki mogą używać:
- action_type
- amount threshold
- allocation confidence
- classification
- period status
- role autora
- risk level

## 3. Outcomes

NO_APPROVAL
SINGLE_APPROVAL
DUAL_CONTROL
OWNER_APPROVAL
FINANCE_APPROVAL
CUSTOM_CHAIN

## 4. Baseline policy v0.1

Wartości kwotowe nie są jeszcze zamrożone; mechanizm jest obowiązkowy.

Domyślnie approval wymagają:
- manual/estimated economic allocation powyżej progu,
- reclassification BUSINESS ↔ NON_BUSINESS powyżej progu,
- correction dotycząca HARD/SOFT closed period,
- manual Settlement correction,
- CAPEX bez InvestmentProject powyżej progu,
- high-risk permission change,
- manual override conflict PMS/OSG wpływający na pobyt/finanse.

## 5. Separation of duties

Dla polityki DUAL_CONTROL autor nie może być własnym final approverem.

## 6. Approval entity

ApprovalRequest:
- subject_type/id
- policy_id/version
- requested_by
- requested_at
- risk_context snapshot
- status

ApprovalDecision:
- request_id
- approver
- decision APPROVE/REJECT
- decided_at
- comment/reason

## 7. Versioning

ApprovalPolicy jest versioned. Historyczna decyzja wskazuje wersję reguły obowiązującą w momencie requestu.

## 8. Expiry

Approval request może wygasać, jeśli underlying record zmienił się po utworzeniu requestu. Wtedy wymagany jest nowy approval.

## 9. AI/agents

AI może przygotować proposal i rationale, ale nie otrzymuje automatycznie prawa do high-risk approval. Approval działa identycznie dla zmian inicjowanych przez człowieka i AI.

## 10. Invariants

APP-001 — approver musi mieć właściwy permission/scope.
APP-002 — DUAL_CONTROL wymaga innego user_id niż creator.
APP-003 — approval jest nieważne po materialnej zmianie subject version.
APP-004 — decision nie jest cicho edytowana; korekta tworzy nową decyzję/workflow.
APP-005 — posted high-risk action wskazuje approval evidence, jeśli polityka tego wymaga.