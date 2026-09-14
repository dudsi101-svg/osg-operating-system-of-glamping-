# OSG — Domain Invariant Test Catalog v0.1

Status: spec testów przed implementacją
Data: 2026-09-14

## Cel

Zdefiniować testy, które przyszły backend musi przechodzić niezależnie od UI i frameworka.

## Tenancy

TNT-001 — rekord Organization A nie może referować Unit Organization B.
TNT-002 — User scoped do Property A nie odczytuje danych Property B bez odpowiedniej roli.
TNT-003 — ExternalReference uniqueness jest lokalna dla Integration, ale nie pozwala na duplikat tego samego external id/type.

## Reservation / Stay

STY-001 — departure_date <= arrival_date jest odrzucone.
STY-002 — dwa StaySegments tej samej Unit z nakładającym się aktywnym zakresem są odrzucone.
STY-003 — zmiana Unit w trakcie Stay tworzy nowy segment, nie nadpisuje starego.
STY-004 — no-show nie tworzy completed Stay.
STY-005 — rzeczywiste daty pobytu nie nadpisują planowanych dat ReservationItem.
STY-006 — ReservationItem tego samego Property nie może wskazywać Unit innego Property.

## Resource / Services

SVC-001 — effective_end <= effective_start jest odrzucone.
SVC-002 — łączna capacity_used w konflikcie czasowym nie może przekroczyć Resource.capacity.
SVC-003 — buffer_before/buffer_after wpływają na konflikt effective window.
SVC-004 — ServiceBooking requiring resource nie przechodzi do CONFIRMED bez valid ResourceReservation, chyba że jawna polityka dopuszcza deferred assignment.
SVC-005 — cancellation nie tworzy ServiceExecution=COMPLETED.

## Folio / Payments

PAY-001 — PaymentAllocation amount <= available confirmed Payment.
PAY-002 — suma PaymentAllocations nie przekracza Payment amount.
PAY-003 — reversed Charge nie pozostaje jako należność w balance.
PAY-004 — overpayment pozostaje jawne.
PAY-005 — refund tworzy osobny fakt, nie zmniejsza historycznej płatności w miejscu.
PAY-006 — closed Folio nie przyjmuje zwykłych zmian bez reopen workflow.

## Financial Truth

FIN-001 — POSTED EconomicEvent musi mieć allocations sum = amount.
FIN-002 — posted EconomicEvent nie jest aktualizowany inplace.
FIN-003 — correction tworzy reversal/adjustment trail.
FIN-004 — CashMovement transfer nie tworzy automatycznie OPEX.
FIN-005 — FinancialDocument total nie wymusza jednej CAPEX/OPEX classification.
FIN-006 — MANUAL/ESTIMATED allocation bez rationale jest odrzucone.
FIN-007 — SettlementEntry creditor != debtor.
FIN-008 — Settlement application nie może rozliczyć więcej niż outstanding settlement.
FIN-009 — HARD_CLOSED period blokuje ordinary posting backdated do okresu.
FIN-010 — Accounting View i Economic View dają niezależne wyniki na scenariuszu mixed/private expense.

## Availability / Operations

OPS-001 — Incident HIGH może utworzyć AvailabilityBlock zgodnie z rule.
OPS-002 — zakończenie Incident nie musi automatycznie odblokować Unit bez spełnienia unlock rule.
OPS-003 — Turnover.Ready wymaga zakończenia mandatory tasks.
OPS-004 — UnitReadiness=DIRTY nie oznacza automatycznie non-sellable future inventory.
OPS-005 — expired high-priority Task generuje escalation event tylko raz per escalation stage.

## Integrations

INT-001 — ten sam external event pięć razy powoduje jeden efekt domenowy.
INT-002 — stale external update nie nadpisuje nowszego owned field bez conflict policy.
INT-003 — OSG-owned allocation nie jest nadpisana przez accounting import.
INT-004 — invalid payload trafia do rejected/data-quality path, nie tworzy częściowego biznesowego faktu.
INT-005 — retry techniczny jest idempotentny.

## Audit / Permissions

SEC-001 — unauthorized role nie może wykonać protected backend action mimo bezpośredniego requestu API.
SEC-002 — high-risk approval nie może być self-approved, jeśli obowiązuje separation of duties.
SEC-003 — posted financial change posiada AuditEvent.
SEC-004 — AI action jest ograniczona permission scope użytkownika.
SEC-005 — sensitive fields nie są kopiowane do standardowego audit payloadu.

## Metrics

MET-001 — blocked non-sellable night nie wchodzi do denominator OSG_OCCUPANCY_V1.
MET-002 — physical occupancy i sellable occupancy różnią się poprawnie przy AvailabilityBlock.
MET-003 — Booking payout net of commission: ADR liczy revenue, nie bank payout.
MET-004 — CAPEX nie obniża Unit Operating Margin jako OPEX.
MET-005 — estimated lost revenue nie pojawia się jako recognized revenue/cost.
MET-006 — KPI drill-down sumuje się do wartości headline z tolerancją rounding.

## Release gate

P0: TNT, STY overlap, PAY sums, FIN posting, permission enforcement, integration idempotency.
P1: availability, settlements, resource capacity, period close, explainability.
P2: advanced metrics and convenience workflows.
