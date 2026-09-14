# OSG — M3 Business Rules Catalog v0.1

Status: roboczy
Data: 2026-09-14

## Cel

Zdefiniować prawa systemu OSG, których interfejs, API, automatyzacje i integracje nie mogą łamać.

## A. Reguły ogólne

BR-GEN-001 — Każda trwała encja biznesowa posiada stabilny UUID.
BR-GEN-002 — Nazwy i etykiety mogą się zmieniać bez zmiany ID.
BR-GEN-003 — Dane pochodne nie są źródłem prawdy.
BR-GEN-004 — Historia biznesowa nie może być rekonstruowana wyłącznie z aktualnego stanu.
BR-GEN-005 — Krytyczne fakty historyczne koryguje się przez korektę/odwrócenie, nie ciche nadpisanie.
BR-GEN-006 — Wszystkie czasy operacyjne są przechowywane technicznie w UTC i interpretowane w timezone Property.
BR-GEN-007 — Cross-tenant references są domyślnie zabronione.

## B. Property i availability

BR-PROP-001 — Unit należy dokładnie do jednego Property.
BR-PROP-002 — UnitType opisuje kategorię; Unit opisuje fizyczny egzemplarz.
BR-PROP-003 — Resource i Asset są odrębnymi pojęciami.
BR-PROP-004 — Niesprzedana noc nie jest automatycznie dostępna do sprzedaży.
BR-PROP-005 — Sellable capacity wynika z fizycznej pojemności pomniejszonej o obowiązujące AvailabilityBlocks i inne reguły sprzedażowe.
BR-PROP-006 — AvailabilityBlock musi mieć end > start.
BR-PROP-007 — Incident może tworzyć AvailabilityBlock tylko przez jawną regułę biznesową lub decyzję operatora.

## C. Reservations i Stay

BR-RES-001 — Reservation reprezentuje zobowiązanie handlowe, nie faktyczny pobyt.
BR-RES-002 — ReservationItem musi mieć departure_date > arrival_date.
BR-RES-003 — Stay reprezentuje wykonanie pobytu.
BR-RES-004 — Planowane i faktyczne daty nie mogą być nadpisywane wzajemnie.
BR-RES-005 — Zmiana fizycznej jednostki w trakcie pobytu wymaga StaySegment, nie nadpisania Unit.
BR-RES-006 — Dwa aktywne StaySegments nie mogą zajmować tej samej Unit w tym samym czasie.
BR-RES-007 — Payment status, commercial status i stay status są niezależnymi osiami stanu.

## D. Folio, Charges i Payments

BR-FIN-001 — Charge i Payment są odrębnymi faktami.
BR-FIN-002 — Payment i CashMovement są odrębnymi faktami.
BR-FIN-003 — Folio balance = posted Charges - applied confirmed Payments z uwzględnieniem korekt.
BR-FIN-004 — Posted Charge nie jest edytowany bez śladu; korekta wymaga reversal/corrective charge.
BR-FIN-005 — PaymentAllocation wiąże płatność z konkretnymi Charges.
BR-FIN-006 — Nadpłata musi pozostać jawna i nie może zostać automatycznie „zgubiona” w saldo 0.

## E. Financial Truth

BR-FT-001 — FinancialDocument, CashMovement, EconomicEvent i Allocation są niezależnymi warstwami prawdy.
BR-FT-002 — Dokument księgowy nie przesądza o ekonomicznej przynależności kosztu.
BR-FT-003 — CashMovement opisuje ruch pieniędzy, nie automatycznie koszt lub przychód.
BR-FT-004 — EconomicEvent opisuje ekonomiczne znaczenie zdarzenia.
BR-FT-005 — Allocation przypisuje EconomicEvent do wymiarów biznesowych.
BR-FT-006 — CAPEX/OPEX klasyfikuje się na poziomie EconomicEvent/Allocation, a nie wyłącznie całego dokumentu.
BR-FT-007 — Posted EconomicEvent musi mieć sumę Allocations równą jego kwocie z tolerancją zaokrągleń.
BR-FT-008 — Allocation może być DIRECT, SHARED, OVERHEAD lub NON_BUSINESS.
BR-FT-009 — Szacunkowa alokacja musi mieć oznaczone confidence/source rationale.
BR-FT-010 — paid_by i economic_bearer są odrębnymi wymiarami.
BR-FT-011 — Różnica paid_by vs economic_bearer może generować SettlementEntry.
BR-FT-012 — Transfer pomiędzy MoneyAccounts nie jest automatycznie kosztem.
BR-FT-013 — CAPEX nie obciąża bieżącej rentowności operacyjnej tak samo jak OPEX.
BR-FT-014 — Wskaźniki księgowe, cash flow, operating result, economic result i investment view są odrębnymi perspektywami.

## F. Services i Resources

BR-SVC-001 — Service opisuje to, co sprzedajemy; Resource opisuje ograniczony zasób potrzebny do wykonania.
BR-SVC-002 — ServiceBooking jest planem/zobowiązaniem, ServiceExecution faktem wykonania.
BR-SVC-003 — ResourceReservation musi uwzględniać buffer_before i buffer_after.
BR-SVC-004 — Sumaryczne capacity_used nie może przekroczyć Resource.capacity w tym samym effective time.
BR-SVC-005 — Pakiet rozwija się do składników możliwych do rozliczenia i analizy ekonomicznej.

## G. Operations

BR-OPS-001 — Checkout może automatycznie utworzyć Turnover zgodnie z regułą automatyzacji.
BR-OPS-002 — Turnover i Task są odrębnymi pojęciami: turnover to proces, task to jednostka pracy.
BR-OPS-003 — Incident opisuje problem; Task opisuje działanie do wykonania.
BR-OPS-004 — UnitReadiness jest niezależne od sellability.
BR-OPS-005 — WorkLog opisuje rzeczywiście wykonaną pracę i nie może być zastąpiony samym stanem Task=DONE.
BR-OPS-006 — Critical Incident może wymagać automatycznego alertu i/lub blokady sprzedaży.

## H. Integrations i provenance

BR-INT-001 — Każdy rekord zewnętrzny zachowuje source system i external identifier.
BR-INT-002 — Importy muszą być idempotentne.
BR-INT-003 — Surowy ExternalRecord powinien być możliwy do zachowania do debugowania integracji.
BR-INT-004 — Integracja nie może bezwarunkowo nadpisywać pól, których właścicielem jest OSG.
BR-INT-005 — Source of Truth musi być jawnie określone dla kluczowych pól/domen.

## I. Audit i bezpieczeństwo

BR-SEC-001 — AuditEvent odpowiada na pytanie kto/co/kiedy zmienił.
BR-SEC-002 — DomainEvent odpowiada na pytanie co wydarzyło się w biznesie.
BR-SEC-003 — Dane wrażliwe nie mogą być bez potrzeby kopiowane do audit logów.
BR-SEC-004 — Uprawnienia są egzekwowane w backendzie, nie tylko w UI.
BR-SEC-005 — AI korzysta wyłącznie z kontrolowanego API/semantic layer zgodnego z uprawnieniami użytkownika.
BR-SEC-006 — Guest/housekeeping nie otrzymują dostępu do danych finansowych bez jawnej potrzeby.

## J. Analytics i metryki

BR-MET-001 — Każda KPI posiada jednoznaczną wersjonowaną definicję.
BR-MET-002 — Metric definition wskazuje numerator, denominator, filtry, zakres czasu i source facts.
BR-MET-003 — Dashboard nie jest źródłem prawdy; jest projekcją danych domenowych.
BR-MET-004 — Opportunity cost / lost revenue musi być oznaczony jako estymacja, nie rzeczywisty koszt księgowy.
BR-MET-005 — Każda kluczowa liczba powinna być rozwijalna do faktów źródłowych („Why this number?”).

## K. Reguły do rozstrzygnięcia w kolejnej iteracji

1. Czy ReservationItem może prowadzić do więcej niż jednego Stay w przypadku split/reattempt scenariuszy.
2. Dokładna tolerancja rounding dla posted EconomicEvent allocations.
3. Kiedy CAPEX bez InvestmentProject jest dopuszczalny.
4. Reguły approval workflow dla alokacji i korekt finansowych.
5. Reguły scalania duplikatów GuestProfile.
6. Priorytet source systems przy konflikcie PMS vs OSG.
7. Retencja danych gości i dokumentów.
8. Polityka zamykania okresów finansowych.
