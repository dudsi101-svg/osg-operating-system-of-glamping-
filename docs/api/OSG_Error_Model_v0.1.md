# OSG — Error Model v0.1

Status: roboczy
Data: 2026-09-14

## 1. Cele

Błędy mają być jednoznaczne dla UI, integracji, automatyzacji i agentów AI.

## 2. Kategorie

VALIDATION_ERROR
AUTHENTICATION_REQUIRED
PERMISSION_DENIED
NOT_FOUND
CONFLICT
STATE_TRANSITION_NOT_ALLOWED
INVARIANT_VIOLATION
IDEMPOTENCY_CONFLICT
EXTERNAL_DEPENDENCY_ERROR
RATE_LIMITED
TEMPORARY_FAILURE
DATA_QUALITY_BLOCK
APPROVAL_REQUIRED
PERIOD_CLOSED

## 3. Shape

```json
{
  "error": {
    "code": "STAY_UNIT_CONFLICT",
    "category": "CONFLICT",
    "message": "Selected unit is not available for the requested interval.",
    "correlation_id": "...",
    "details": {
      "unit_id": "...",
      "conflicting_entity_id": "..."
    },
    "retryable": false
  }
}
```

## 4. Zasady

- `code` jest stabilnym kodem maszynowym.
- `message` jest dla człowieka i może być lokalizowane.
- `details` nie może ujawniać danych spoza uprawnień.
- każde 5xx ma correlation_id.
- błędy domenowe nie są maskowane jako ogólne 500.

## 5. Przykładowe kody domenowe

RESERVATION_INVALID_DATES
STAY_UNIT_CONFLICT
RESOURCE_CAPACITY_EXCEEDED
FOLIO_CLOSED
PAYMENT_OVERALLOCATION
ECONOMIC_EVENT_NOT_FULLY_ALLOCATED
ECONOMIC_EVENT_ALREADY_POSTED
SETTLEMENT_OVERAPPLICATION
PERIOD_HARD_CLOSED
TENANT_BOUNDARY_VIOLATION
APPROVAL_REQUIRED_FOR_MANUAL_ALLOCATION
EXTERNAL_RECORD_CONFLICT

## 6. Retry semantics

Retryable:
- TEMPORARY_FAILURE
- EXTERNAL_DEPENDENCY_ERROR (czasami)
- RATE_LIMITED

Non-retryable bez zmiany danych/decyzji:
- INVARIANT_VIOLATION
- STATE_TRANSITION_NOT_ALLOWED
- PERMISSION_DENIED
- PERIOD_CLOSED

## 7. AI / automation behavior

Agent/automation nie może automatycznie obchodzić błędu domenowego.
Może:
- ponowić błąd techniczny zgodnie z policy,
- eskalować konflikt,
- zaproponować korektę danych,
- zażądać approval.
