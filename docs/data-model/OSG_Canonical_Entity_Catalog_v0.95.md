# OSG — Canonical Entity Catalog v0.95

Status: PRE-FREEZE CANONICAL CANDIDATE
Data: 2026-09-14

## 1. Cel

Ten katalog określa kanoniczne encje OSG przed Schema v1.0. Nazwy tabel mogą później zostać technicznie dopracowane, ale znaczenie biznesowe encji nie powinno zmieniać się bez jawnej decyzji architektonicznej.

Każda encja otrzymuje:
- domenę,
- znaczenie,
- źródło prawdy,
- mutowalność,
- główne relacje.

---

# A. TENANCY / IDENTITY

## Organization
Korzeń tenant isolation i konfiguracji klienta OSG.
Source of truth: OSG.
Mutability: mutable master data; never hard-delete after business data exists.
Relations: 1:N Property, Party, UserAccount, Integration.

## Party
Rzeczywisty uczestnik biznesowy: osoba, firma, platforma, urząd.
Source: OSG/verified external source.
Mutability: master data with history where legally needed.
Relations: GuestProfile, UserAccount, payer/bearer, contractor, issuer/recipient.

## UserAccount
Tożsamość logująca się do OSG.
Source: identity/auth system.
Mutability: security-controlled.
Relations: Party optional, RoleAssignments, AuditEvents.

## Role
Zbiór uprawnień.
Source: OSG configuration.
Mutability: versioned/configurable.

## Permission
Atomowe uprawnienie do action/resource.
Source: OSG Core.
Mutability: controlled product config.

## RoleAssignment
Przypisanie Role do UserAccount w scope Organization/Property.
Source: OSG.
Mutability: audited security fact.

## ApprovalPolicy
Wersjonowana reguła wymagająca akceptacji ryzykownej zmiany.
Source: OSG config.
Mutability: versioned.

## ApprovalRequest
Prośba o akceptację konkretnej zmiany.
Source: OSG workflow.
Mutability: state machine.

## ApprovalDecision
Decyzja approvera.
Source: OSG.
Mutability: append/corrective; no silent edit.

---

# B. PROPERTY / DIGITAL TWIN

## Property
Konkretny obiekt hospitality.
Source: OSG.
Mutability: master data.
Relations: Zones, Units, Resources, Assets, Channels, CostCenters.

## Zone
Hierarchiczny kontekst przestrzenny/logiczny Property.
Source: OSG.
Mutability: master data.

## UnitType
Kategoria jednostki noclegowej.
Source: OSG/PMS mapping.
Mutability: master data/versioned commercial properties.

## Unit
Fizyczna jednostka noclegowa.
Source: OSG.
Mutability: lifecycle master entity.

## AvailabilityBlock
Okres, w którym Unit/Resource nie jest sprzedawalny/dostępny.
Source: OSG/Incident/Integration.
Mutability: stateful temporal fact; history preserved.

## Resource
Ograniczony zasób używany przez Service lub operacje.
Examples: sauna, jacuzzi, sala, łódka.
Source: OSG.
Mutability: lifecycle master entity.

## ResourceReservation
Czasowe wykorzystanie Resource.
Source: OSG/service/integration.
Mutability: state machine; concurrency guarded.

## Asset
Element majątku wymagający historii technicznej.
Source: OSG.
Mutability: lifecycle master entity.

## MaintenancePlan
Reguła cyklicznego serwisu/inspekcji Asset/Resource.
Source: OSG config.
Mutability: versioned.

## CostCenter
Logiczny wymiar kosztu wspólnego/overhead.
Source: OSG.
Mutability: master data.

## InvestmentProject
Kontekst CAPEX i inwestycji.
Source: OSG.
Mutability: lifecycle entity.

---

# C. GUEST / RESERVATION / STAY

## GuestProfile
CRM-owa reprezentacja osoby będącej gościem.
Source: OSG after merge/provenance rules.
Mutability: personal master data with privacy lifecycle.

## Reservation
Zobowiązanie handlowe.
Source: PMS/channel/OSG according to source-of-truth matrix.
Mutability: stateful commitment; critical changes audited.

## ReservationItem
Pozycja noclegowa rezerwacji.
Source: Reservation source.
Mutability: commercial state; snapshot relevant fields.
Relations: UnitType, assigned Unit optional, Stay.

## Stay
Rzeczywiste wykonanie pobytu.
Source: OSG operations.
Mutability: state machine.

## StaySegment
Rzeczywisty fragment Stay w konkretnej Unit i czasie.
Source: OSG.
Mutability: historical execution fact; no history rewrite.

## StayGuest
Relacja GuestProfile/osoby do konkretnego Stay.
Source: OSG/guest form.
Mutability: operational/personal relation.

## CommercialPolicySnapshot
Snapshot zasad sprzedaży obowiązujących konkretną Reservation/ReservationItem.
Contains: cancellation policy, pricing conditions, taxes/fees references, package/rate terms.
Source: sales source/OSG.
Mutability: immutable snapshot.

---

# D. COMMERCE / FOLIO

## Folio
Rachunek hospitality przypisany do Reservation/Stay.
Source: OSG.
Mutability: state machine OPEN/CLOSED; balance derived.

## Charge
Naliczenie za nocleg/usługę/opłatę/rabat/korektę.
Source: OSG/PMS mapped.
Mutability: posted charge corrected by reversal/correction.

## Payment
Fakt płatności/rozliczenia gościa na poziomie commerce.
Source: payment provider/OTA/manual verified.
Mutability: state machine; refund separate fact.

## PaymentAllocation
Przypisanie Payment do Charge.
Source: OSG reconciliation/commerce.
Mutability: controlled allocation fact.

## Refund
Jawny fakt zwrotu związany z Payment/Folio.
Source: provider/OSG workflow.
Mutability: immutable/corrective history.

---

# E. EXPERIENCE

## Service
To, co sprzedajemy poza/nad noclegiem.
Source: OSG.
Mutability: master catalog.

## ServiceBooking
Konkretnie zamówiona usługa.
Source: guest/operator/integration.
Mutability: state machine.

## ServiceExecution
Faktyczne wykonanie ServiceBooking.
Source: OSG operations.
Mutability: execution fact.

## Package
Kompozycja oferty handlowej.
Source: OSG.
Mutability: versioned catalog.

## PackageComponent
Składnik Package mapowany do noclegu/usługi/opłaty.
Source: OSG.
Mutability: versioned with Package.

---

# F. OPERATIONS

## Turnover
Proces przygotowania Unit między pobytami.
Source: OSG automation/operator.
Mutability: state machine.

## Task
Jednostka pracy.
Source: automation/operator/template.
Mutability: state machine.

## TaskTemplate
Konfigurowalny wzorzec powtarzalnej pracy.
Source: OSG config.
Mutability: versioned.

## WorkLog
Faktycznie wykonana praca/czas.
Source: worker/operator.
Mutability: historical fact; corrections audited.

## Incident
Problem/zdarzenie niepożądane.
Source: guest/operator/system.
Mutability: state machine.

## WorkOrder
Zlecenie naprawy/serwisu wewnętrznego lub zewnętrznego.
Source: OSG.
Mutability: state machine.

## ConflictCase
Jawny konflikt operacyjny wymagający resolution, np. AvailabilityBlock vs confirmed Stay.
Source: OSG rule.
Mutability: state machine with resolution history.

---

# G. INVENTORY

## InventoryItem
Materiał eksploatacyjny.
Source: OSG.
Mutability: master data.

## InventoryLocation
Miejsce składowania.
Source: OSG.
Mutability: master data.

## StockMovement
Ruch zapasu.
Source: OSG/operator/import.
Mutability: append/corrective.

## ReorderRule
Reguła ostrzegania/uzupełnienia.
Source: OSG config.
Mutability: configurable.

---

# H. FINANCIAL TRUTH

## FinancialDocument
Dokument źródłowy/księgowy.
Source: document/accounting/OCR verified.
Mutability: controlled lifecycle; posted/corrected history.

## FinancialDocumentLine
Pozycja dokumentu umożliwiająca różną ekonomiczną klasyfikację.
Source: document/OCR verified.
Mutability: document lifecycle.

## MoneyAccount
Logiczne miejsce przepływu środków.
Examples: bank, cash, OTA clearing, owner funds, operator funds.
Source: OSG config/external account mapping.
Mutability: master/lifecycle.

## CashMovement
Rzeczywisty ruch środków.
Source: bank/provider/manual verified.
Mutability: append/corrective; no economic meaning implied.

## EconomicEvent
Ekonomiczne znaczenie zdarzenia.
Source: OSG rules/human-approved mapping.
Mutability: DRAFT until POSTED; then immutable except reversal/correction.

## Allocation
Przypisanie EconomicEvent do ekonomicznych wymiarów OSG.
Source: OSG/system/manual approved.
Mutability: posting lifecycle; immutable after finalization except correction.

## AllocationRule
Wersjonowana reguła rozdziału SHARED costs/revenue.
Source: OSG config.
Mutability: versioned.

## ReconciliationLink
Powiązanie niezależnych faktów: document/cash/payment/economic.
Source: OSG/manual/system suggestion.
Mutability: controlled relation with match status.

## SettlementEntry
Należność pomiędzy Parties wynikająca z payer vs economic bearer lub innego jawnego źródła.
Source: OSG Financial Truth.
Mutability: append/corrective.

## SettlementApplication
Rozliczenie SettlementEntry płatnością/kompensatą.
Source: OSG reconciliation.
Mutability: controlled allocation fact.

## FinancialPeriod
Okres finansowy OSG: OPEN/SOFT_CLOSED/HARD_CLOSED.
Source: OSG.
Mutability: controlled state machine.

---

# I. REVENUE

## Channel
Kanał sprzedaży.
Source: OSG mapping.
Mutability: master data.

## CommissionRule
Wersjonowana reguła oczekiwanej prowizji kanału.
Source: contract/config.
Mutability: temporal versioned.

## RatePlan
Warunki handlowe ceny.
Source: PMS/OSG mapping.
Mutability: versioned.

## Rate
Cena dla UnitType/date/plan/channel context.
Source: PMS/revenue layer.
Mutability: temporal commercial fact.

## RateSnapshot
Cena/warunki zapisane w momencie sprzedaży/publikacji.
Source: sales event.
Mutability: immutable snapshot.

## PricingRule
Deterministyczna reguła rekomendacji ceny.
Source: OSG config.
Mutability: versioned.

## PricingSuggestion
Rekomendacja, nie opublikowana cena.
Source: rules/AI.
Mutability: recommendation lifecycle.

---

# J. COMMUNICATION

## Conversation
Kontener komunikacji Guest/Reservation/Stay.
Source: OSG/integration.
Mutability: lifecycle.

## Message
Pojedyncza wiadomość inbound/outbound.
Source: email/SMS/portal/provider.
Mutability: historical communication fact.

## MessageTemplate
Wersjonowany szablon wiadomości.
Source: OSG config.
Mutability: versioned.

## CommunicationConsent
Jawna zgoda/preference z source/timestamp/version.
Source: guest/OSG.
Mutability: append/history.

## Notification
Systemowe powiadomienie do user/role.
Source: OSG rules.
Mutability: delivery/read state.

---

# K. INTEGRATIONS / FILES

## Integration
Konfiguracja adaptera zewnętrznego.
Source: OSG config.
Mutability: lifecycle/security-controlled.

## ExternalRecord
Surowy/safe snapshot danych odebranych ze źródła.
Source: external system.
Mutability: immutable ingestion evidence.

## ExternalReference
Mapowanie external ID ↔ OSG entity.
Source: integration mapping.
Mutability: controlled; uniqueness enforced.

## IntegrationProcessingRecord
Idempotency/processing state external event/record.
Source: OSG integration layer.
Mutability: processing state machine.

## FileObject
Metadane pliku w object storage.
Source: OSG storage.
Mutability: lifecycle; binary outside DB.

## AttachmentLink
Powiązanie FileObject z konkretną domeną/typed context.
Source: OSG.
Mutability: controlled link.

## Extraction
Wynik OCR/AI extraction przed walidacją.
Source: OCR/AI.
Mutability: immutable extraction result/version.

---

# L. SYSTEM / HISTORY / AUTOMATION

## AuditEvent
Kto/co/kiedy zmienił.
Source: system.
Mutability: append-only.

## DomainEvent
Co wydarzyło się w biznesie.
Source: domain transaction.
Mutability: append-only/versioned contract.

## OutboxEvent
Techniczna gwarancja dostarczenia DomainEvent.
Source: same transaction as domain change.
Mutability: delivery state only; payload/event identity stable.

## AutomationRule
Trigger + conditions + actions.
Source: OSG config.
Mutability: versioned.

## AutomationExecution
Historia wykonania automatyzacji.
Source: automation runtime.
Mutability: execution state/history.

## DataQualityIssue
Jawna niespójność/brak/ryzyko danych.
Source: validation/monitoring/user.
Mutability: issue lifecycle.

## Recommendation
Sugestia AI/rule engine przed wykonaniem akcji.
Source: Intelligence layer.
Mutability: recommendation lifecycle.

---

# M. ENCJE POCHODNE / PROJEKCJE — NIE ŹRÓDŁA PRAWDY

Przykłady, które mogą istnieć jako materialized view/cache/projection, ale nie są niezależnymi faktami:
- UnitCurrentState
- FolioBalance
- SettlementBalance
- StockLevel
- Occupancy metric result
- Unit profitability
- Command Center cards
- Business/Data Health score
- Current readiness board

Ich źródła muszą być odtwarzalne z faktów domenowych.

---

# N. PRE-FREEZE RULE

Dodanie nowej encji do Core przed v1.0 wymaga odpowiedzi:
1. Jakiego realnego faktu biznesowego nie da się poprawnie odwzorować istniejącymi encjami?
2. Czy nowy byt jest faktem, konfiguracją czy projekcją?
3. Kto jest jego source of truth?
4. Czy potrzebuje własnego lifecycle/invariant?
5. Czy może być tylko polem/relacją istniejącej encji?

Po `Schema v1.0 FINAL` nowa core entity wymagająca breaking change wymaga ADR + migration plan.