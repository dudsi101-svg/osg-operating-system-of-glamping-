# OSG — Outbox & Event Delivery Contract v0.1

Status: kandydat implementacyjny
Data: 2026-09-14

## 1. Cel

Zapewnić, że krytyczny zapis biznesowy i odpowiadający mu DomainEvent nie rozjadą się przy awarii pomiędzy commit bazy a publikacją zdarzenia.

## 2. Transactional outbox

W tej samej transakcji co zmiana agregatu zapisywany jest rekord OutboxEvent.
Po commicie background publisher dostarcza event dalej.

## 3. OutboxEvent

- id
- organization_id
- event_id
- event_type
- aggregate_type/id
- payload
- created_at
- available_at
- published_at nullable
- attempts
- last_error
- status

## 4. Invariants

OUT-001 — business change i outbox row commitują się razem.
OUT-002 — event_id jest stabilny podczas retry.
OUT-003 — publisher jest at-least-once; consumers muszą być idempotentni.
OUT-004 — failed publication nie cofa już committed business fact.
OUT-005 — poison event po limicie prób trafia do dead-letter/failed queue i alertu.

## 5. Ordering

Global ordering nie jest wymagany.
Dla eventów jednego aggregate zalecany jest aggregate_version i monotonic sequence.
Consumer może odrzucić/stash event starszy niż już przetworzona wersja, jeśli kontrakt wymaga kolejności.

## 6. Delivery states

PENDING
PUBLISHING
PUBLISHED
FAILED_RETRYABLE
FAILED_FINAL

## 7. Retry

Exponential backoff + jitter.
Retry nie generuje nowego event_id.

## 8. Observability

Metryki:
- outbox_pending_count
- oldest_pending_age
- publish_failure_rate
- dead_letter_count
- event_delivery_latency

## 9. Initial recommendation

Release 1 nie potrzebuje zewnętrznego brokera wiadomości, jeśli PostgreSQL outbox + background worker wystarcza dla skali obiektu. Architektura kontraktu nie blokuje późniejszego przejścia na broker.