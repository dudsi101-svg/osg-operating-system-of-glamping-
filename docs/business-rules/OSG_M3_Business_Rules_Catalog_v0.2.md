# OSG — M3 Business Rules Catalog v0.2

Status: roboczy zaawansowany
Data: 2026-09-14

## A. System invariants

BR-SYS-001 — Każda trwała encja posiada UUIDv7.
BR-SYS-002 — Organization jest granicą izolacji tenantów.
BR-SYS-003 — Cross-tenant reference jest zabroniona bez jawnego kontraktu.
BR-SYS-004 — Derived state nie jest źródłem prawdy.
BR-SYS-005 — Krytyczne fakty historyczne są immutable po finalizacji i korygowane przez reversal/correction.
BR-SYS-006 — Każda zmiana krytyczna posiada actor/source/time.
BR-SYS-007 — Operacyjne timestampy są przechowywane w UTC, prezentowane w timezone Property.

## B. Source of Truth

BR-SOT-001 — Dla każdego kluczowego pola istnieje jeden aktualny owner system.
BR-SOT-002 — Integracja nie może nadpisać pola owned-by-OSG bez polityki konfliktu.
BR-SOT-003 — Zewnętrzny rekord zachowuje external id i provenance.
BR-SOT-004 — Import jest idempotentny.
BR-SOT-005 — Manual override musi pozostawić audit trail.

## C. Property

BR-PROP-001 — Unit należy do dokładnie jednego Property.
BR-PROP-002 — UnitType nie reprezentuje fizycznego egzemplarza.
BR-PROP-003 — Unit, Resource i Asset mają odrębne lifecycle.
BR-PROP-004 — Physical capacity i sellable capacity są odrębnymi miarami.
BR-PROP-005 — AvailabilityBlock posiada powód, zakres i source.
BR-PROP-006 — Block z Incident może zostać zakończony dopiero po spełnieniu reguły odblokowania.
BR-PROP-007 — UnitReadiness nie jest równoznaczne z sellability.

## D. Reservation / Stay

BR-STAY-001 — Reservation = commitment, Stay = execution.
BR-STAY-002 — Reservation dates nie są nadpisywane przez actual dates.
BR-STAY-003 — Unit change w trakcie pobytu tworzy StaySegment.
BR-STAY-004 — Aktywne StaySegments nie mogą nakładać się dla tej samej Unit.
BR-STAY-005 — Kolejny Stay z jednego ReservationItem wymaga explicit reason.
BR-STAY-006 — Guest count planned i actual są osobne.
BR-STAY-007 — Commercial/payment/stay/readiness statuses są niezależnymi osiami.
BR-STAY-008 — No-show nie tworzy fikcyjnego completed Stay.

## E. Folio / Payment

BR-COM-001 — Charge != Payment != CashMovement.
BR-COM-002 — Folio balance jest projekcją.
BR-COM-003 — PaymentAllocation nie może przekroczyć available Payment.
BR-COM-004 — Nadpłata pozostaje jawna.
BR-COM-005 — Refund jest osobnym faktem, nie zmianą starej płatności.
BR-COM-006 — Posted Charge jest immutable poza reversal/correction.
BR-COM-007 — Closed Folio może zostać ponownie otwarte tylko przez uprawniony workflow.

## F. Financial Truth

BR-FT-001 — FinancialDocument, CashMovement, EconomicEvent i Allocation są niezależne.
BR-FT-002 — Accounting treatment nie determinuje economic allocation.
BR-FT-003 — Cash transfer między kontami nie tworzy kosztu/przychodu bez EconomicEvent.
BR-FT-004 — Posted EconomicEvent musi być w pełni zaalokowany.
BR-FT-005 — Tolerancja rounding: maksymalnie mniejsza z 0,01 waluty bazowej albo systemowej tolerancji walutowej; różnica wymaga rounding allocation.
BR-FT-006 — CAPEX/OPEX może różnić się pomiędzy liniami tego samego dokumentu.
BR-FT-007 — CAPEX > ustalonego progu wymaga InvestmentProject; poniżej progu może użyć CAPEX_SMALL_ASSET z uzasadnieniem.
BR-FT-008 — Allocation ma allocation_type i confidence.
BR-FT-009 — ESTIMATED/MANUAL allocation wymaga rationale.
BR-FT-010 — paid_by i economic_bearer są osobne.
BR-FT-011 — SettlementEntry może powstać tylko z jawnego źródła ekonomicznego.
BR-FT-012 — Settlement balance jest projekcją.
BR-FT-013 — Korekta zamkniętego okresu wymaga adjustment w bieżącym okresie lub controlled reopen.
BR-FT-014 — Economic result i cash result nigdy nie są prezentowane jako ta sama metryka.

## G. Services

BR-SVC-001 — Service opisuje ofertę, Resource opisuje ograniczenie wykonawcze.
BR-SVC-002 — ServiceBooking != ServiceExecution.
BR-SVC-003 — Resource effective window obejmuje bufory.
BR-SVC-004 — Capacity nie może zostać przekroczone.
BR-SVC-005 — Pakiet musi dekomponować się do mierzalnych składników.
BR-SVC-006 — Cancelled/no-show service nie może automatycznie zostać uznany za wykonany kosztowo lub przychodowo.

## H. Operations

BR-OPS-001 — Turnover jest procesem, Task jednostką pracy.
BR-OPS-002 — Task DONE bez wymaganego WorkLog nie oznacza pełnego wykonania, jeśli task type wymaga ewidencji pracy.
BR-OPS-003 — Incident severity może uruchamiać obowiązkowe actions.
BR-OPS-004 — Critical safety incident ma pierwszeństwo nad commercial availability.
BR-OPS-005 — Auto-unblock po Incident jest dozwolony tylko gdy rule explicitly pozwala.
BR-OPS-006 — SLA i escalation są danymi konfiguracyjnymi, nie zakodowanymi wyjątkami.

## I. Guest / Privacy

BR-PRV-001 — Minimum necessary data.
BR-PRV-002 — Marketing consent jest niezależna od realizacji pobytu.
BR-PRV-003 — Guest merge wymaga udokumentowanej podstawy dopasowania.
BR-PRV-004 — Merge nie usuwa provenance rekordów źródłowych.
BR-PRV-005 — Sensitive notes wymagają ograniczonego dostępu i retention policy.

## J. Permissions

BR-SEC-001 — Backend egzekwuje permissions.
BR-SEC-002 — RoleAssignment ma scope.
BR-SEC-003 — Field-level restrictions stosuje się dla danych finansowych, osobowych i bezpieczeństwa.
BR-SEC-004 — AI dziedziczy uprawnienia użytkownika.
BR-SEC-005 — Żaden agent/AI nie ma domyślnego prawa bezpośredniego zapisu do krytycznych faktów finansowych bez workflow.

## K. Agent Governance

BR-AI-001 — READ MANY / WRITE ONE.
BR-AI-002 — Każdy artefakt posiada jednego write owner w danym momencie.
BR-AI-003 — Cross-domain change wymaga review affected domains.
BR-AI-004 — Agent nie uznaje własnego review za niezależną akceptację.
BR-AI-005 — Zmiana L3 wymaga ADR.
BR-AI-006 — Checkpoint nie powstaje przy otwartym konflikcie P0/P1.
BR-AI-007 — Agent nie modyfikuje cudzej domeny, jeżeli problem można rozwiązać kontraktem.

## L. Open items przed Schema Freeze

- finalna polityka zamykania okresów
- progi approval finansowego
- polityka retencji danych
- Guest merge thresholds
- exact source precedence dla pierwszego PMS
- threshold CAPEX_SMALL_ASSET
