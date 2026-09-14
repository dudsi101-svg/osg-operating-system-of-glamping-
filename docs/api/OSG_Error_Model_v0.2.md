# OSG — Error Model v0.2

Status: canonical pre-freeze candidate
Date: 2026-09-15

## 1. Contract

Every domain error has one stable machine code independent of detection layer.

PostgreSQL may raise `OSG_<CODE>`; repository/domain adapter normalizes it to API `code=<CODE>`.
UI, automations and AI react to `code/category/retryable`, not free-text DB messages.

## 2. Response shape

```json
{
  "error": {
    "code": "RESOURCE_CAPACITY_EXCEEDED",
    "category": "CONFLICT",
    "message": "Resource capacity is not available for the requested interval.",
    "correlation_id": "019...",
    "retryable": false,
    "details": {}
  }
}
```

`details` is permission-filtered.

## 3. HTTP mapping

- 400 — malformed request / basic validation
- 401 — AUTHENTICATION_REQUIRED
- 403 — PERMISSION_DENIED / TENANT_SCOPE_REQUIRED
- 404 — safe scoped NOT_FOUND
- 409 — concurrency/state/capacity/idempotency conflict
- 422 — valid request shape but domain invariant cannot be satisfied
- 423 — optional representation for approval/locked business workflow; default API may still use 409/422 with category
- 429 — RATE_LIMITED
- 502/503 — external/temporary dependency failures
- 500 — unexpected defect only

## 4. Stable code registry

### Identity / authorization
- `AUTHENTICATION_REQUIRED`
- `PERMISSION_DENIED`
- `TENANT_SCOPE_REQUIRED`
- `TENANT_BOUNDARY_VIOLATION`
- `PROPERTY_CONTEXT_MISMATCH`

### Concurrency / command execution
- `VERSION_CONFLICT`
- `IDEMPOTENCY_KEY_PAYLOAD_MISMATCH`
- `COMMAND_ALREADY_IN_PROGRESS`
- `COMMAND_ALREADY_COMPLETED`
- `TEMPORARY_CONCURRENCY_CONFLICT`

### Property / availability
- `PROPERTY_NOT_FOUND`
- `UNIT_NOT_FOUND`
- `STAY_POLICY_NOT_FOUND`
- `STAY_POLICY_OVERLAP`
- `AVAILABILITY_CONFLICT`
- `COMMERCIAL_NIGHT_UNIT_UNRESOLVED`

### Reservation / Stay
- `RESERVATION_INVALID_DATES`
- `RESERVATION_INVALID_STATE`
- `RESERVATION_UNIT_TYPE_MISMATCH`
- `STAY_INVALID_STATE`
- `STAY_SEGMENT_OVERLAP`
- `STAY_RELOCATION_TARGET_UNAVAILABLE`

### Resource / Experience
- `RESOURCE_CAPACITY_EXCEEDED`
- `RESOURCE_EXCLUSIVE_CONFLICT`
- `RESOURCE_HOLD_EXPIRED`
- `SERVICE_BOOKING_INVALID_STATE`

### Operations
- `TURNOVER_INVALID_STATE`
- `TURNOVER_BLOCKED`
- `TASK_INVALID_STATE`
- `INCIDENT_INVALID_STATE`
- `UNIT_BLOCK_CONFLICT`

### Folio / Commerce
- `FOLIO_NOT_FOUND`
- `FOLIO_CLOSED`
- `FOLIO_BALANCE_UNAVAILABLE`
- `FOLIO_BALANCE_NOT_ZERO`
- `FOLIO_PENDING_ITEMS`
- `CONTROLLED_FOLIO_REOPEN_REQUIRED`
- `FOLIO_CURRENCY_MISMATCH`
- `PAYMENT_NOT_FOUND`
- `PAYMENT_OVERALLOCATION`
- `REFUND_CURRENCY_MISMATCH`
- `REFUND_EXCEEDS_PAYMENT`
- `FINAL_CHARGE_IMMUTABLE`
- `ORIGINAL_CHARGE_NOT_FOUND`
- `CHARGE_REVERSAL_FOLIO_MISMATCH`
- `CHARGE_REVERSAL_SIGN_INVALID`
- `CHARGE_OVER_REVERSED`

### Financial Truth
- `ECONOMIC_EVENT_NOT_FOUND`
- `ECONOMIC_EVENT_INVALID_STATE`
- `ALLOCATION_REQUIRED`
- `ALLOCATION_NOT_BALANCED`
- `POSTED_EVENT_IMMUTABLE`
- `POSTED_EVENT_ALLOCATION_IMMUTABLE`
- `REPORTING_CURRENCY_NOT_CONFIGURED`
- `ECONOMIC_EVENT_CURRENCY_MISMATCH`
- `FINANCIAL_PERIOD_REQUIRED`
- `FINANCIAL_PERIOD_AMBIGUOUS`
- `FINANCIAL_PERIOD_HARD_CLOSED`
- `ECONOMIC_DATE_OUTSIDE_FINANCIAL_PERIOD`
- `RELATED_FINANCIAL_PERIOD_NOT_FOUND`
- `ADJUSTMENT_REASON_REQUIRED`
- `CONTROLLED_REOPEN_REQUIRED`
- `INVALID_PERIOD_TRANSITION`
- `SETTLEMENT_OVERAPPLICATION`
- `SETTLEMENT_CURRENCY_MISMATCH`

### Approval
- `APPROVAL_REQUIRED`
- `APPROVAL_REJECTED`
- `SEPARATION_OF_DUTIES_REQUIRED`

### Guest identity
- `GUEST_ALIAS_SELF_REFERENCE`
- `GUEST_ALIAS_TARGET_NOT_CANONICAL`
- `GUEST_ALIAS_CHAIN_NOT_ALLOWED`
- `GUEST_ALIAS_CYCLE`
- `GUEST_MERGE_REVIEW_REQUIRED`

### Integration
- `EXTERNAL_RECORD_CONFLICT`
- `EXTERNAL_EVENT_DUPLICATE`
- `EXTERNAL_PAYLOAD_INVALID`
- `INTEGRATION_DEGRADED`
- `EXTERNAL_DEPENDENCY_ERROR`

### Analytics / semantic
- `INVALID_PERIOD`
- `SEMANTIC_POLICY_MISSING`
- `INSUFFICIENT_DATA`
- `METRIC_VERSION_NOT_SUPPORTED`

### System / data quality
- `DATA_QUALITY_BLOCK`
- `TEMPORARY_FAILURE`
- `RATE_LIMITED`
- `INTERNAL_ERROR`

## 5. Normalization examples

DB:
`OSG_ALLOCATION_NOT_BALANCED event=...`

API:
```json
{
  "code":"ALLOCATION_NOT_BALANCED",
  "category":"INVARIANT_VIOLATION",
  "retryable":false
}
```

DB:
`OSG_FINANCIAL_PERIOD_HARD_CLOSED`

API:
`FINANCIAL_PERIOD_HARD_CLOSED / PERIOD_CLOSED / 409`

## 6. Retry classes

### Safe automatic retry
- TEMPORARY_FAILURE
- EXTERNAL_DEPENDENCY_ERROR when provider policy permits
- RATE_LIMITED after retry-after/backoff
- transient DB serialization/deadlock mapped to TEMPORARY_CONCURRENCY_CONFLICT

### Retry only after reload/re-evaluation
- VERSION_CONFLICT
- COMMAND_ALREADY_IN_PROGRESS

### No blind retry
- invariant violations
- permission/tenant errors
- capacity conflicts
- approval required/rejected
- closed period
- property-context mismatch

## 7. Security

A scoped NOT_FOUND may be returned instead of revealing existence of an inaccessible cross-tenant object.
Raw SQL exception text, query details, secrets and unauthorized identifiers never pass directly to clients.

## 8. AI / automation

AI must treat stable domain errors as constraints, not invitations to bypass them.
Permitted response:
- retry transient technical error,
- reload after version conflict,
- surface/resolve business conflict,
- request approval,
- propose correction.

Forbidden:
- disabling a guard,
- silently reopening period,
- changing tenant/property context,
- mutating historical facts to make a command succeed.
