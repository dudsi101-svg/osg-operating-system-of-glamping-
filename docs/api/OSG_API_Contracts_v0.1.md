# OSG — API Contracts v0.1

Status: conceptual API contract
Data: 2026-09-14

## 1. Cel

API-first boundary dla frontendów, integracji i AI. Kontrakty są domenowe; UI nie zapisuje bezpośrednio krytycznych tabel.

## 2. Zasady

- versioned API
- authenticated actor context
- permission enforcement backend-side
- idempotency keys dla komend zewnętrznych
- correlation_id dla workflow
- optimistic concurrency dla edytowalnych agregatów
- POSTED financial facts immutable through ordinary update endpoints

## 3. Command vs Query

Queries odczytują projekcje i fakty.
Commands wykonują intencję biznesową i walidują invariants.

Przykład: nie `PATCH economic_event status=POSTED`, lecz `POST /economic-events/{id}/post`.

## 4. Property

GET /v1/properties/{property_id}
GET /v1/properties/{property_id}/units
GET /v1/units/{unit_id}/state
POST /v1/units/{unit_id}/availability-blocks
POST /v1/availability-blocks/{id}/end

## 5. Reservations / Stay

GET /v1/reservations
POST /v1/reservations
GET /v1/reservations/{id}
POST /v1/reservations/{id}/confirm
POST /v1/reservations/{id}/cancel
POST /v1/reservation-items/{id}/assign-unit
POST /v1/stays/{id}/check-in
POST /v1/stays/{id}/move-unit
POST /v1/stays/{id}/check-out

## 6. Operations

GET /v1/operations/today
GET /v1/tasks
POST /v1/tasks
POST /v1/tasks/{id}/start
POST /v1/tasks/{id}/complete
POST /v1/incidents
POST /v1/incidents/{id}/triage
POST /v1/incidents/{id}/resolve
GET /v1/units/{id}/maintenance-history

## 7. Services

GET /v1/services
GET /v1/resources/{id}/availability
POST /v1/service-bookings
POST /v1/service-bookings/{id}/cancel
POST /v1/service-bookings/{id}/complete

## 8. Folio / Payments

GET /v1/folios/{id}
POST /v1/folios/{id}/charges
POST /v1/charges/{id}/reverse
POST /v1/folios/{id}/payments
POST /v1/payments/{id}/allocate
POST /v1/payments/{id}/refund
POST /v1/folios/{id}/close

## 9. Financial Truth

GET /v1/financial/documents
POST /v1/financial/documents
POST /v1/financial/documents/{id}/verify
GET /v1/cash-movements
POST /v1/economic-events
POST /v1/economic-events/{id}/allocations
POST /v1/economic-events/{id}/post
POST /v1/economic-events/{id}/reverse
GET /v1/settlements
POST /v1/settlements/{id}/apply
POST /v1/reconciliations

## 10. Analytics

GET /v1/analytics/property-summary
GET /v1/analytics/unit-performance
GET /v1/analytics/stay-margin/{stay_id}
GET /v1/analytics/channel-performance
GET /v1/analytics/data-confidence
GET /v1/analytics/metrics/{metric_code}/explain

## 11. AI semantic endpoints

GET /v1/intelligence/context/property/{id}
POST /v1/intelligence/query

AI query response musi zawierać:
- answer
- metric/data references
- confidence/data quality indicators
- permission-filtered evidence

AI write operations nie korzystają z specjalnego bypass API; używają tych samych command endpoints co człowiek.

## 12. Error model

Każdy błąd domenowy ma:
- code
- message
- entity/reference
- rule_id
- correlation_id
- retryable boolean

Przykłady:
UNIT_OCCUPANCY_CONFLICT
RESOURCE_CAPACITY_EXCEEDED
POSTED_EVENT_IMMUTABLE
PAYMENT_OVERALLOCATION
TENANT_SCOPE_VIOLATION
PERIOD_HARD_CLOSED

## 13. Idempotency

Commandy narażone na retry przyjmują `Idempotency-Key`.
System przechowuje wynik komendy dla klucza w zdefiniowanym okresie.

## 14. Concurrency

Edytowalne agregaty posiadają version/etag. Konflikt zapisu zwraca CONCURRENCY_CONFLICT zamiast last-write-wins dla krytycznych danych.