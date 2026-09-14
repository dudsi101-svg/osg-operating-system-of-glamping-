# AGENTS.md — OSG

Ten dokument obowiązuje agentów AI i automaty pracujące w repozytorium OSG.

## Misja

Budować OSG — Operating System of Glamping — bez poświęcania poprawności domenowej, Financial Truth, audytowalności i izolacji tenantów dla szybkości implementacji.

## Aktualna faza

PRE-FREEZE / EXECUTABLE PROOF.

`Schema v1.0 FINAL` jeszcze nie obowiązuje. Kandydat v0.95 jest stabilną bazą implementacyjną, ale P0 proof suite musi zostać wykonany przed finalnym freeze.

Proof SQL i dokumenty nie są produkcyjnymi migracjami, dopóki nie zostaną jawnie promowane.

## Przeczytaj przed pracą

1. `docs/PROJECT_INDEX.md`
2. `docs/agents/OSG_Agent_Operating_Model_v1.md`
3. `docs/readiness/OSG_Schema_Freeze_Assessment_v0.95.md`
4. dokumenty domeny zadania
5. odpowiednie ADR

## Zasada nadrzędna

READ MANY / WRITE ONE.

Wiele agentów może równolegle analizować, testować i recenzować. Jeden write-owner na dany artefakt/obszar w danym momencie.

## Priorytety

1. bezpieczeństwo i integralność danych
2. spójność domeny
3. odwracalność decyzji
4. audytowalność
5. prostota operacyjna
6. wydajność
7. wygoda implementacji

## Ownership

Nie zmieniaj cudzej domeny tylko dlatego, że jest to wygodne implementacyjnie. Preferuj kontrakt API/event/domain boundary. Zmiana cross-domain wymaga review domen dotkniętych zmianą.

## Zakazy

- nie łącz FinancialDocument, Charge, Payment, CashMovement, EconomicEvent i Allocation w jeden koncept
- nie traktuj dashboardu ani projekcji jako źródła prawdy
- nie nadpisuj POSTED financial facts; używaj reversal/correction
- nie używaj generic `entity_type/entity_id` dla krytycznych relacji, jeśli możliwy jest jawny FK
- nie wprowadzaj cross-tenant references bez jawnego kontraktu/ADR
- nie rozpoczynaj produkcyjnych migracji przed Schema Freeze GO
- nie koduj Michał/Kuba/Forest/Boho itd. w OSG Core
- nie zapisuj reguł biznesowych wyłącznie w frontendzie
- nie omijaj idempotencji dla integracji i automatyzacji
- nie dawaj AI uprzywilejowanego bypassu permissions/approval/audit

## Financial Truth

`FinancialDocument != CashMovement != EconomicEvent != Allocation`.

Cash movement nie jest automatycznie kosztem/przychodem.
Dokument księgowy nie przesądza ekonomicznej klasyfikacji.
Posted facts są immutable poza kontrolowanym reversal/correction workflow.

## Stay / Property

Reservation = zobowiązanie handlowe.
Stay = wykonanie.
Relokacja Unit używa StaySegment; nie przepisuje historii.
Physical capacity != sellable capacity.
Unit, Resource i Asset są odrębnymi bytami.

## Tenant isolation

Każda tenant-owned operacja posiada Organization scope.
Cross-tenant link jest domyślnie zabroniony.
Background jobs, cache keys, events i integrations muszą zachować tenant context.

## Events / Automation

Cross-domain workflows preferują Domain Events.
Business change + event publication używają transactional outbox lub równoważnego mechanizmu.
Automation effects muszą być idempotentne i audytowalne.

## AI

AI korzysta z Semantic/API Layer i podlega tym samym permissions, validations, approvals i auditowi co użytkownik.
AI nie ma unrestricted write do DB ani high-risk autonomous approval.

## Branch naming

`agent/<domain>/<task>`

Przykłady:
- `agent/finance/posting-proof`
- `agent/property/stay-overlap-proof`

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

## Testy P0

Każda zmiana dotykająca P0 invariant aktualizuje wykonywalny proof.

Źródła:
- `tests/specs/OSG_P0_Executable_Test_Vectors_v0.1.yaml`
- `tests/specs/OSG_P0_Proof_Execution_Plan_v0.1.md`
- `tests/sql/p0_invariants_v0.1.sql`

## Migracje

Stosuj `database/MIGRATIONS.md`.
Nie przepisuj historii migracji, która została zastosowana w środowisku współdzielonym/produkcyjnym.
Breaking schema change po freeze wymaga migration + ADR.

## Definition of Done

Zmiana jest gotowa, gdy:
- invariants pozostają prawdziwe,
- tenant scope jest testowany,
- stabilne error codes są określone,
- audit/event side effects są określone,
- wpływ cross-domain opisany,
- dokumentacja/contract zostały zaktualizowane, jeśli zmieniła się semantyka,
- testy/spec testów istnieją,
- affected domains zostały zrecenzowane,
- ADR istnieje dla decyzji L3,
- reviewer może odtworzyć decyzję z repo bez kontekstu rozmowy.

Pełny model pracy agentów: `docs/agents/OSG_Agent_Operating_Model_v1.md`.