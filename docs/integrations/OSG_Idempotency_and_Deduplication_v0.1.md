# OSG — Idempotency & Deduplication Contract v0.1

Status: kandydat do freeze
Data: 2026-09-14

## 1. Cel

Zapewnić, że ponowne dostarczenie tego samego zdarzenia, retry HTTP, webhook duplicate lub ponowne wykonanie automatyzacji nie tworzy wielokrotnych skutków biznesowych.

## 2. Warstwy idempotencji

### Inbound integration
Klucz preferowany:
`integration_id + external_event_id`

Fallback:
`integration_id + external_type + external_id + source_version`

Ostateczny fallback:
stabilny payload fingerprint dla źródła, które nie oferuje event/version id.

### Commands/API
Dla wybranych write commands klient może dostarczyć `Idempotency-Key`.
Backend przechowuje wynik pierwszego poprawnego wykonania w określonym oknie.

### Automations
Klucz:
`automation_rule_id + trigger_event_id + action_key`

### Financial posting
Klucz biznesowy może dodatkowo obejmować command_id/correlation_id, ale nie zastępuje invariantów finansowych.

## 3. States

RECEIVED
PROCESSING
SUCCEEDED
FAILED_RETRYABLE
FAILED_FINAL
DUPLICATE

## 4. Duplicate semantics

Duplicate nie jest błędem biznesowym.
Powinien zwracać deterministyczny wynik wskazujący istniejący efekt, jeśli jest dostępny.

## 5. Concurrency

Idempotency musi działać również przy równoczesnym dostarczeniu dwóch identycznych requestów.
Wymagane: unique constraint/transactional claim, nie tylko sprawdzenie `SELECT then INSERT` bez locka.

## 6. Side effects

Email/SMS/payment/provider calls muszą mieć własny action key lub provider idempotency key, jeśli dostawca je wspiera.

## 7. Event publication

DomainEvent nie może zostać opublikowany wielokrotnie w sposób generujący podwójny efekt downstream.
Jeśli zastosowany zostanie outbox pattern, `outbox_event_id` jest stabilny dla transakcji biznesowej.

## 8. Replay

System powinien umożliwiać bezpieczny replay zdarzeń technicznych. Replay nie może omijać idempotency guardów.

## 9. Observability

Metryki:
- duplicate_rate
- retry_rate
- failed_final_count
- processing_lag
- idempotency_conflict_count

## 10. P0 tests

IDEMP-001 — 5 identycznych PMS deliveries → 1 domain effect.
IDEMP-002 — 2 równoległe identical POST commands → 1 aggregate mutation.
IDEMP-003 — automation retry po timeout → 1 Turnover.
IDEMP-004 — duplicate financial posting command → brak drugiego POSTED eventu.
IDEMP-005 — replay integration batch → brak nowych duplikatów Reservation.