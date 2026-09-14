# OSG — Tenant Isolation Contract v0.1

Status: kandydat do freeze
Data: 2026-09-14

## 1. Cel

Zapobiec przypadkowemu lub celowemu połączeniu danych dwóch Organization w modelu wieloobiektowym/multi-tenant.

## 2. Zasada nadrzędna

Każda encja tenant-owned posiada `organization_id`.
Każda krytyczna relacja musi zachowywać zgodność Organization po obu stronach.

## 3. Enforcement layers

1. API authorization — request scope zawiera organization/property context.
2. Domain service — use case sprawdza ownership.
3. Database — composite FK / trigger / RLS tam, gdzie ma to uzasadnienie.
4. Tests — cross-tenant test vectors są obowiązkowe w CI.

## 4. Composite identity strategy

Dla krytycznych tabel preferowane jest wymuszenie spójności przez relacje zawierające `organization_id`, np. logicznie:

`reservation(organization_id, id)` → `reservation_item(organization_id, reservation_id)`.

Nie wszystkie tabele muszą używać composite PK, ale krytyczne FK muszą uniemożliwiać cross-tenant link.

## 5. RLS

Row Level Security jest dodatkową barierą, nie jedyną ochroną.
Polityka bazowa:
- sesja posiada bieżący `app.organization_id`,
- SELECT/INSERT/UPDATE/DELETE są ograniczone do tego Organization,
- service roles mają jawnie wydzielony zakres.

## 6. Integrations

Każda Integration należy do dokładnie jednej Organization, chyba że istnieje jawny platform-level connector.
ExternalReference nie może mapować rekordu Organization A do encji Organization B.

## 7. AI

AI dziedziczy organization scope użytkownika. Semantic API nie wykonuje zapytań bez jawnego tenant context.

## 8. Audit

Próba cross-tenant access generuje security audit event. Powtarzające się próby mogą generować alert.

## 9. Invariants

TI-001 — cross-tenant FK forbidden.
TI-002 — role assignment scope nie rozszerza się automatycznie na inne Organization.
TI-003 — export domyślnie pozostaje w tenant scope.
TI-004 — background job musi posiadać organization_id.
TI-005 — event envelope dla tenant-owned agregatu musi posiadać organization_id.
TI-006 — cache key musi zawierać tenant scope, jeśli wynik zależy od Organization.

## 10. Freeze requirement

Schema v1.0 nie może zostać uznany za FINAL bez wykonywalnego testu, że cross-tenant Reservation→Unit i EconomicEvent→Allocation są odrzucane na poziomie backend/database.