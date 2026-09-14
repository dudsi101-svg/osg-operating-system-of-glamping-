# OSG — Observability Model v0.1

Status: kandydat implementacyjny
Data: 2026-09-14

## 1. Trzy warstwy obserwowalności

TECHNICAL — czy system działa?
INTEGRATION — czy dane przepływają?
BUSINESS — czy biznesowy proces zakończył się poprawnie?

## 2. Technical signals

- API latency p50/p95/p99
- error rate
- DB connection saturation
- slow queries
- background job lag
- outbox pending age
- storage failures
- auth failures
- health/readiness

## 3. Integration signals

Per integration:
- last_success_at
- sync lag
- records received
- records rejected
- duplicate rate
- conflict count
- credential status
- reconciliation gap

## 4. Business process signals

Examples:
- arrivals today without assigned unit
- checkout completed but no Turnover after SLA
- Turnover not READY before next arrival
- confirmed Payment not reconciled after threshold
- POSTED EconomicEvent with data quality alert
- Settlement aging
- critical Incident unresolved
- ResourceBooking preparation task missing

## 5. Correlation

Każdy request/job/event powinien propagować:
- request_id
- correlation_id
- causation_id
- organization_id
- property_id where applicable

Nie logujemy danych osobowych ponad potrzebę diagnostyczną.

## 6. Logs

Structured JSON logs.
Minimal fields:
timestamp, level, service, environment, request_id, actor_type/id redacted where needed, organization_id, event/action, result, error_code.

## 7. Metrics and alerts

P0 alerts:
- tenant isolation violation attempt
- financial posting invariant failure
- critical integration outage affecting current arrivals
- outbox oldest pending above SLA
- backup/restore validation failure

P1:
- rising data quality unresolved count
- turnover SLA breach
- reconciliation lag

## 8. Business health dashboard

System Health ≠ Business Health.
Command Center może pokazać uproszczony status:
- DATA HEALTH
- OPERATIONS HEALTH
- INTEGRATION HEALTH
- FINANCIAL DATA HEALTH

## 9. SLO candidates

Nie zamrażamy wartości przed pomiarem, ale przygotowujemy metryki dla:
- API availability
- sync freshness
- automation completion latency
- arrival-critical workflow reliability

## 10. Audit vs logs

AuditEvent jest trwałym śladem biznesowym/security.
Log techniczny służy diagnostyce i ma krótszą retencję.
Nie używamy logów aplikacji jako jedynego audytu.