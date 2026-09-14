# AGENTS.md — OSG

Ten dokument obowiązuje agentów AI i automaty pracujące w repozytorium OSG.

## Zasada nadrzędna

READ MANY / WRITE ONE.

Wiele agentów może równolegle analizować i recenzować. Jeden write-owner na dany artefakt/obszar w danym momencie.

## Priorytety

1. integralność danych
2. spójność domeny
3. odwracalność decyzji
4. bezpieczeństwo i audyt
5. prostota operacyjna
6. wydajność
7. wygoda implementacji

## Zakazy

- nie zmieniaj cudzej domeny bez ownership/handoff
- nie łącz Charge, Payment, CashMovement i EconomicEvent w jeden koncept
- nie traktuj dashboardu jako źródła prawdy
- nie nadpisuj POSTED financial facts
- nie używaj generic entity_type/entity_id dla krytycznych relacji, jeśli możliwy jest jawny FK
- nie wprowadzaj cross-tenant references bez ADR
- nie rozpoczynaj produkcyjnych migracji przed Schema Freeze GO

## Wymagane przed zmianą cross-domain

- primary owner
- affected domains
- dependency impact
- event/API contract impact
- migration impact
- reviewer

## Decyzje

L1 lokalna — Domain Lead
L2 międzydomenowa — owner + affected leads
L3 architektoniczna — Chief Architect + ADR
L4 fundamentalna produktowa — Chief Architect + właściciel projektu

## Branch naming

`agent/<domain>/<task>`

## Definition of Done

Zmiana jest gotowa, gdy:
- reguły/invariants są jawne,
- wpływ cross-domain opisany,
- dokumentacja uaktualniona,
- testy/spec testów istnieją,
- reviewer może odtworzyć decyzję z repo bez kontekstu rozmowy.

Pełny model: `docs/agents/OSG_Agent_Operating_Model_v1.md`.