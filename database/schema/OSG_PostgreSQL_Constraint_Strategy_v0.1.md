# OSG — PostgreSQL Constraint Strategy v0.1

Status: proof-of-model design
Data: 2026-09-14

## Cel

Określić, które invariants powinny być wymuszane przez PostgreSQL, które przez serwis domenowy, a które przez oba poziomy.

## 1. StaySegment overlap

Rekomendacja: PostgreSQL range + EXCLUDE constraint dla aktywnych segmentów Unit.

Kandydat:
- tstzrange(start_at, end_at, '[)')
- exclusion on unit_id WITH = and range WITH &&
- partial predicate dla aktywnych/non-cancelled segmentów

Dodatkowo backend zwraca przyjazny błąd domenowy UNIT_OCCUPANCY_CONFLICT.

## 2. Resource capacity

Prosty EXCLUDE działa tylko dla capacity=1. Dla capacity >1 potrzebna jest transakcyjna walidacja sumy overlapping `capacity_used` z lockingiem/advisory lock per resource/time bucket lub wyspecjalizowany model inventory.

R1 rekomendacja:
- capacity=1: exclusion constraint,
- capacity>1: serializowany command service + retry on concurrency conflict,
- test równoległych bookingów obowiązkowy.

## 3. Cross-tenant references

Sam pojedynczy FK do `unit(id)` nie gwarantuje zgodności organization_id.

Preferowany model fizyczny:
- każda tenant-owned tabela ma organization_id,
- referenced table ma UNIQUE(organization_id, id),
- FK child (organization_id, foreign_id) → parent(organization_id, id),
- RLS jako druga warstwa ochrony.

To jest ważniejsze niż poleganie wyłącznie na kodzie aplikacji.

## 4. EconomicEvent allocation equality

Nie da się bezpiecznie wymusić zwykłym CHECK obejmującym wiele wierszy.

Rekomendacja:
- DRAFT może być niepełny,
- `post` command w jednej transakcji blokuje event + allocations,
- sprawdza sumę,
- ustawia POSTED,
- trigger/guard zabrania późniejszej zwykłej modyfikacji POSTED facts.

Możliwy deferred constraint trigger jako dodatkowa ochrona.

## 5. PaymentAllocation sum

Analogicznie:
- transakcyjny allocate command,
- row lock Payment,
- suma istniejących allocations + new <= confirmed amount,
- DB trigger może stanowić defense-in-depth.

## 6. Posted immutability

PostgreSQL trigger blokuje UPDATE/DELETE dla POSTED economic_event/charge wymagających reversal workflow, poza kontrolowaną service role/funkcją korekty.

Preferowane: aplikacja nigdy nie wykonuje bezpośredniego UPDATE POSTED.

## 7. ExternalReference idempotency

UNIQUE(integration_id, external_type, external_id)

Inbound events dodatkowo:
UNIQUE(integration_id, external_event_id) tam, gdzie dostawca oferuje stabilny event id.

## 8. Monetary types

R1 PLN, ale używamy numeric(14,2) + currency char(3).
Nie używamy float/double dla pieniędzy.

W przyszłości money minor units mogą zostać rozważone, ale numeric jest wystarczający dla obecnego zakresu.

## 9. Soft/archive

Nie stosujemy ON DELETE CASCADE dla krytycznych faktów historycznych.
Master data może być archived.
Financial/Stay/Audit records preferują RESTRICT i lifecycle statuses.

## 10. RLS

RLS rekomendowane jako defense-in-depth dla tenant isolation, ale backend/API nadal wykonuje permissions. RLS nie zastępuje domenowego authorization.

## 11. Transaction boundaries

ACID wymagane dla:
- check-in / unit assignment conflict check,
- posting EconomicEvent,
- payment allocation,
- settlement application,
- resource booking conflict check,
- period close/reopen.

## Wniosek

GAP-012, GAP-013, GAP-014 i GAP-015 mają wykonalną strategię techniczną. Muszą zostać potwierdzone eksperymentalnymi testami PostgreSQL przed Schema Freeze.