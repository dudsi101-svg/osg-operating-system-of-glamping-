# OSG — Pre-Build Architecture Checkpoint v0.1

Data: 2026-09-14
Status: CHECKPOINT READY — pre-build architecture

## 1. Stan projektu

OSG przeszedł z poziomu koncepcji modułów do formalnego modelu domenowego i proof-of-model relacyjnego.

Aktualny status:
DISCOVERY → DOMAIN MODEL → RELATIONSHIP MODEL → BUSINESS RULES → EVENTS → FINANCIAL TRUTH → SECURITY → METRICS → INTEGRATIONS → PRE-BUILD PROOF

Produkcja aplikacji nadal nie rozpoczęta.

## 2. Utrwalone decyzje

- relacyjny core, docelowo PostgreSQL,
- API-first,
- multi-property-ready od początku,
- Organization jako tenant boundary,
- Reservation != Stay,
- Resource != Asset,
- Charge != Payment != CashMovement != EconomicEvent,
- CAPEX/OPEX na poziomie ekonomicznej klasyfikacji/alokacji,
- posted financial facts korygowane przez reversal/correction,
- AuditEvent != DomainEvent,
- derived data nie jest source of truth,
- AI przez permission-aware semantic/API layer,
- READ MANY / WRITE ONE dla agentów.

## 3. Główne domeny

- Identity & Organization
- Property Digital Twin
- Reservation & Stay
- Commerce & Folio
- Experience
- Operations
- Maintenance
- Financial Truth
- Revenue & Analytics
- Integrations
- Security & Privacy
- Data Quality

## 4. Kluczowe artefakty

- Core Data Model checkpoint v1.3
- M2 Relationship Map v0.2
- M3 Business Rules v0.2
- M4 Domain Events v0.1
- M5 Financial Truth v0.1
- M6 Permissions & Security v0.1
- M7 Metric Dictionary v0.1
- M8 Integration Contracts v0.1
- M9 Data Lifecycle & Privacy v0.1
- M10 Application Boundary v0.1
- M11 Schema Freeze Gate v0.1
- M12 Build Readiness Review v0.1
- Logical ERD v0.1
- PostgreSQL logical schema v0.1
- Reference Dataset v0.1
- Domain Invariant Test Catalog v0.1
- API Contracts v0.1
- Information Architecture v0.1
- Source of Truth Matrix v0.1
- Data Quality Catalog v0.1
- Agent Operating Model v1
- Implementation Waves v0.1

## 5. P0 architecture status

Koncepcyjnie rozwiązane:
- prepayments/deposits/refunds,
- cancellation/no-show semantics,
- AvailabilityBlock vs existing reservation conflict,
- StaySegment overlap strategy,
- Resource capacity concurrency strategy,
- cross-tenant physical constraint strategy,
- EconomicEvent allocation equality strategy.

Pozostają testy techniczne PostgreSQL/API, nie brak modelu biznesowego.

## 6. First Release Boundary

R1 ma przeprowadzić pełny cykl:
Reservation → Stay → Operations → Service → Folio → Payment → Cash → EconomicEvent → Allocation → Settlement → Analytics.

Nie obejmuje pełnego channel managera, księgowości podatkowej, dynamic pricing automation ani native mobile.

## 7. Glamping Nad Stawem

Pierwsza implementacja pozostaje konfiguracją OSG Core.
Unit examples:
Forest, Boho, Loft, Ostoja, Aura.

Reference Dataset jest syntetyczny i nie zawiera prawdziwych danych gości.

## 8. Najważniejsze otwarte P1

- realny source/PMS reservation flow,
- approval thresholds,
- VAT/tax managerial view,
- retention periods,
- period-close operational policy,
- legal entity mapping właściciel/operator,
- first bank import path.

Nie blokują dalszego technicznego proof-of-model, ale blokują odpowiednie moduły produkcyjne.

## 9. Następny kierunek

Bez używania Work mode można dalej przygotować:
- PostgreSQL constraint proof scripts,
- seed/reference SQL,
- OpenAPI skeleton,
- state machine specs,
- event schemas,
- migration conventions,
- CI/test strategy,
- repository coding conventions,
- frontend route/component contracts,
- reporting query specs.

## 10. Build decision

GO:
- technical proof-of-model,
- test specifications,
- schema experiments,
- API contracts,
- synthetic fixtures.

NO-GO:
- live production financial ingestion,
- production migrations,
- replacement of PMS,
- autonomous high-risk AI actions,
- final UI release.

Ten checkpoint jest kanonicznym stanem projektu przed wejściem w techniczny proof-of-model.