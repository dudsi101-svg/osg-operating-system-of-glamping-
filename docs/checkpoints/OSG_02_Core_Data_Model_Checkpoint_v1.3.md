# OSG Core Data Model — checkpoint v1.3

**Data:** 2026-09-14  
**Status:** zaakceptowany checkpoint koncepcyjny  
**Zakres:** M1 — rdzeń modelu danych; bez schematu SQL i bez kodu aplikacji

## 1. Cel modelu

OSG ma opisywać glamping jako spójny graf biznesowy: od konfiguracji obiektu, przez sprzedaż i rzeczywiste wykonanie pobytu, po operacje oraz prawdę finansową. Model nie jest wyłącznie PMS-em ani księgą przychodów i kosztów.

Główne pytanie rdzenia:

> Co skonfigurowaliśmy, co uzgodniliśmy, co faktycznie się wydarzyło i jaki był tego skutek ekonomiczny?

## 2. Cztery rodzaje prawdy

| Rodzaj | Znaczenie | Przykład |
|---|---|---|
| Configured Truth | konfiguracja systemu | Forest ma maksymalnie 6 miejsc |
| Committed Truth | uzgodnione zobowiązanie | rezerwacja Forest dla 4 osób |
| Observed Truth | faktyczne wykonanie | przyjechały 3 osoby |
| Economic Truth | wynik ekonomiczny | pobyt wygenerował określoną marżę |

Dane pochodne, takie jak occupancy, ADR, RevPAR czy marża, są projekcjami i nie zastępują faktów źródłowych.

## 3. Granica danych i wspólny standard encji

Organization jest korzeniem izolacji danych. Każdy trwały rekord biznesowy otrzymuje co najmniej:

- UUIDv7 jako stabilny identyfikator,
- organization_id,
- znaczniki utworzenia i aktualizacji,
- autora utworzenia i aktualizacji,
- row_version do kontroli konfliktów,
- archived_at zamiast fizycznego usuwania historii,
- ograniczone metadata wyłącznie do rozszerzeń.

Czytelne kody, np. RES-2026-001248, służą ludziom, ale nie zastępują kluczy relacyjnych.

## 4. Domeny rdzenia

1. Organization & Identity
2. Property Graph
3. Guest & Commerce
4. Stay
5. Experience
6. Operations
7. Assets & Maintenance
8. Financial Truth
9. Integration, Audit & Intelligence

Są to granice znaczeniowe modelu, a nie pozycje przyszłego menu.

## 5. Katalog głównych encji

### Organization & Identity

Organization, Party, UserAccount, RoleAssignment

Party reprezentuje osobę, firmę, platformę lub innego uczestnika biznesu. Party nie jest kontem użytkownika.

### Property Graph

Property, Zone, UnitType, Unit, AvailabilityBlock, Resource, Asset

- UnitType opisuje kategorię, a Unit fizyczną jednostkę.
- Resource jest rezerwowalnym lub ograniczonym zasobem.
- Asset jest składnikiem majątku wymagającym historii technicznej.
- Dostępność sprzedażowa i gotowość operacyjna są osobnymi osiami.

### Guest, Commerce & Stay

GuestProfile, Reservation, ReservationItem, Stay, StaySegment, StayGuest, Folio, Charge, Payment, PaymentAllocation

- Reservation opisuje zobowiązanie handlowe.
- Stay opisuje rzeczywisty pobyt.
- StaySegment zachowuje historię zmiany jednostki w trakcie pobytu.
- Folio jest rachunkiem hospitality, nie dokumentem księgowym.
- Saldo folio jest wyliczane z naliczeń i zaalokowanych płatności.

### Experience

Service, ServiceBooking, ResourceReservation, ServiceExecution, Package, PackageComponent

Sprzedaż usługi, rezerwacja zasobu i faktyczne wykonanie są odrębnymi faktami. Pakiet rozwija się do normalnych składników biznesowych, aby zachować widoczność kosztu i przychodu.

### Operations & Maintenance

Turnover, UnitReadiness, Task, TaskTemplate, WorkLog, Incident, WorkOrder

- Turnover opisuje przygotowanie jednostki między pobytami.
- Task mówi, co należy zrobić; WorkLog — co wykonano.
- Incident opisuje problem, a WorkOrder zlecenie jego obsługi.
- Incydent może utworzyć AvailabilityBlock, jeśli reguła biznesowa tego wymaga.

### Financial Truth

FinancialDocument, FinancialDocumentLine, MoneyAccount, CashMovement, EconomicEvent, Allocation, AllocationRule, Reconciliation, SettlementEntry, InvestmentProject, CostCenter

Model oddziela dokument, przepływ gotówki, sens ekonomiczny i alokację. Pozwala równolegle budować widoki: dokumentowy, cash, operacyjny, ekonomiczny i inwestycyjny.

### System, provenance i automatyzacja

ExternalReference, IntegrationEvent, DomainEvent, AuditEvent, AutomationRule, FileObject, DataQualityIssue

AuditEvent odpowiada na pytanie „kto zmienił dane?”, a DomainEvent — „co wydarzyło się w biznesie?”. Integracje muszą być idempotentne i zachowywać pochodzenie danych.

## 6. Kluczowe relacje

~~~text
Organization
  └─ Property
      ├─ Zone
      ├─ UnitType ─ Unit ─ StaySegment ─ Stay
      ├─ Resource ─ ResourceReservation ─ ServiceBooking
      └─ Asset ─ Incident ─ WorkOrder

Guest/Party ─ Reservation ─ ReservationItem ─ Stay
Reservation/Stay ─ Folio ─ Charge ─ PaymentAllocation ─ Payment

FinancialDocument ─ FinancialDocumentLine ─ EconomicEvent ─ Allocation
MoneyAccount ─ CashMovement ─ Reconciliation
Allocation + paid_by/economic_bearer ─ SettlementEntry
~~~

## 7. Financial Truth — zasady v1.3

### Charge ≠ Payment ≠ CashMovement

- Charge: za co powstała należność.
- Payment: płatność przypisana do gościa lub folio.
- CashMovement: faktyczny przepływ środków między kontami.

Przykład OTA:

~~~text
Charge: nocleg +2 000 PLN
Payment: rozliczenie gościa/OTA +2 000 PLN
EconomicEvent: prowizja OTA -300 PLN
CashMovement: wpływ bankowy +1 700 PLN
~~~

### Dokument ≠ zdarzenie ekonomiczne

Faktura potwierdza dokument. EconomicEvent opisuje sens ekonomiczny, a Allocation przypisuje kwotę do wymiarów takich jak Property, Unit, Stay, Resource, Asset, Service, Channel, InvestmentProject, CostCenter i Party.

### Paid by ≠ economic bearer

paid_by_party_id mówi, kto zapłacił. economic_bearer_party_id mówi, kto powinien ponieść koszt. Różnica może generować SettlementEntry.

### Posted facts are immutable

Zaksięgowanego faktu nie nadpisujemy bez śladu. Korekta tworzy odwrócenie i poprawny nowy zapis.

### Poziomy wyniku

~~~text
Revenue
→ Contribution Margin
→ Operating Margin
→ Economic Operating Result
→ CAPEX View
→ Cash View
~~~

CAPEX pozostaje oddzielony od wyniku operacyjnego.

## 8. Osobne osie stanu

Nie tworzymy sklejonych statusów. Przykładowo:

- Reservation.commercial_status: INQUIRY / HELD / CONFIRMED / CANCELLED / NO_SHOW
- Payment.status: PENDING / CONFIRMED / FAILED / REFUNDED
- Stay.status: EXPECTED / CHECKED_IN / CHECKED_OUT
- UnitReadiness: DIRTY / CLEANING / INSPECTION / READY / BLOCKED
- Incident.status: OPEN / TRIAGED / IN_REPAIR / RESOLVED / CLOSED
- EconomicEvent.status: DRAFT / POSTED / REVERSED

## 9. Kandydaci na twarde reguły integralności

- Rekord nie może wskazywać danych innej Organization.
- ReservationItem.departure_date musi być późniejsze niż arrival_date.
- Segmenty jednego pobytu nie mogą się nakładać.
- Jedna jednostka nie może mieć dwóch aktywnych pobytów w tym samym czasie.
- Blokada dostępności i rezerwacja zasobu muszą mieć poprawny przedział czasu.
- Rezerwacja zasobu nie może przekraczać jego pojemności.
- Suma PaymentAllocation nie może przekraczać dostępnej kwoty płatności.
- Suma alokacji zdarzenia ekonomicznego musi być możliwa do uzgodnienia z jego kwotą.
- Fakty historyczne i finansowe nie są fizycznie usuwane.
- Ręczna lub szacunkowa alokacja musi mieć metodę, powód, autora i poziom pewności.

## 10. Jakość danych i pewność

Poziomy pewności: VERIFIED, SYSTEM_DERIVED, ESTIMATED, MANUAL, UNKNOWN.

DataQualityIssue rejestruje m.in. rezerwację bez kanału, fakturę bez alokacji, płatność bez przepływu, przepływ bez uzgodnienia, CAPEX bez projektu inwestycyjnego oraz incydent bez zamknięcia.

## 11. Decyzje zamknięte w tym checkpointcie

- Model wieloobiektowy od początku przez Organization i Property.
- PostgreSQL jako docelowa relacyjna baza danych.
- Jedno monorepo jako centralne źródło prawdy.
- API jako właściciel logiki biznesowej.
- Brak pełnego event sourcingu; zdarzenia domenowe uzupełniają model stanu.
- Oddzielenie płatności od ruchu gotówki.
- Oddzielenie planu, zobowiązania i wykonania.
- Korekty finansowe przez reversal, nie ciche nadpisanie.

## 12. Następne etapy

1. M2 — pełna mapa relacji i kardynalności.
2. M3 — katalog reguł biznesowych i właścicieli reguł.
3. M4 — katalog zdarzeń domenowych i automatyzacji.
4. M5 — doprecyzowanie Financial Truth, reconciliation i settlement.
5. Dopiero po akceptacji fundamentów: logiczny schemat PostgreSQL i kod aplikacji.

## 13. Poza zakresem

Ten checkpoint nie stanowi implementacji, migracji bazy, API ani interfejsu użytkownika. Nie zamyka również wszystkich typów statusów, reguł podatkowych, polityk retencji ani szczegółów integracji z PMS, bankiem i OTA.
