# OSG — Financial Period Close Contract v0.1

Status: pre-freeze P0 contract
Date: 2026-09-15

## 1. States

`OPEN → SOFT_CLOSED → HARD_CLOSED`

Reopen is exceptional workflow, not ordinary state edit.

## 2. OPEN

Normal create/review/post operations allowed subject to permissions/approvals.

## 3. SOFT_CLOSED

Historical period is considered operationally closed, but controlled corrections may be allowed with approval.

Expected behavior:
- ordinary users cannot silently alter material facts,
- approved correction may reopen or post adjustment according to policy,
- audit records reason/approver.

## 4. HARD_CLOSED

Facts recognized in the period are immutable in place.

Forbidden without controlled reopen:
- changing POSTED event critical fields,
- switching original POSTED event to REVERSED,
- adding/editing/removing its Allocations,
- moving event to another period,
- changing period boundaries.

Preferred correction:
Create current-period `ADJUSTMENT` / `REVERSAL` EconomicEvent with:
- `effect_direction` preserving category polarity,
- `reverses_event_id` where applicable,
- `relates_to_financial_period_id` pointing to the historical period,
- explicit `adjustment_reason`.

Thus reports can show both:
- when correction was recognized,
- which historical period it concerns.

## 5. Controlled reopen

Reopen requires:
- explicit permission,
- ApprovalPolicy if configured,
- reason,
- AuditEvent,
- actor/time,
- no silent direct row update.

Reference implementation may use a privileged domain procedure/session guard; ordinary application SQL path fails closed.

## 6. Reporting

Default historical economic reports use recognition in the actual current `financial_period_id`.
Optional comparative/restated reporting may expose `relates_to_financial_period_id`, but must label restatement explicitly.

## 7. Why

The purpose is not accounting-system imitation. It is preserving managerial historical truth and preventing an operator, import retry or AI action from rewriting previously closed economics without evidence.
