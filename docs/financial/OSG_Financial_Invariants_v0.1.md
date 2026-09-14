# OSG — Financial Invariants v0.1

Status: kandydat do freeze
Data: 2026-09-14

## 1. Cel

Zdefiniować prawa Financial Truth Engine, które muszą pozostać prawdziwe niezależnie od UI, integracji i sposobu implementacji.

## 2. Conservation of amount

FIN-INV-001 — Dla POSTED EconomicEvent suma aktywnych Allocation = kwota zdarzenia w tej samej walucie, z dopuszczalną jawnie zaksięgowaną pozycją ROUNDING.

FIN-INV-002 — Allocation nie może być użyta równocześnie jako aktywna i reversed.

## 3. Immutability

FIN-INV-010 — POSTED EconomicEvent nie zmienia amount, currency, economic_date ani event_type.
FIN-INV-011 — POSTED Allocation nie zmienia amount, classification ani głównych dimensions bez reversal/correction workflow.
FIN-INV-012 — Correction wskazuje rekord korygowany i zachowuje audit trail.

## 4. Cash independence

FIN-INV-020 — CashMovement nie tworzy automatycznie EconomicEvent.
FIN-INV-021 — EconomicEvent może istnieć bez CashMovement.
FIN-INV-022 — Transfer między MoneyAccounts nie jest automatycznie OPEX/Revenue.

## 5. Settlement conservation

FIN-INV-030 — Suma SettlementApplication nie może przekraczać otwartej wartości SettlementEntry.
FIN-INV-031 — SettlementEntry wskazuje jednoznacznego debtor i creditor.
FIN-INV-032 — SettlementEntry utworzony z Allocation nie może przekroczyć ekonomicznej wartości tej Allocation należącej do różnicy payer/bearer.
FIN-INV-033 — Settlement balance jest projekcją wpisów i applications, nie ręcznie edytowalnym polem prawdy.

## 6. Period close

FIN-INV-040 — HARD_CLOSED period nie przyjmuje cichego update/delete faktów finansowych.
FIN-INV-041 — Korekta zamkniętego okresu używa controlled reopen albo current-period adjustment z referencją historyczną.
FIN-INV-042 — Period close nie może pozostawić draft/posting inconsistency dla transakcji oznaczonej jako zakończona.

## 7. Recognition

FIN-INV-050 — document_date, cash_date, economic_date i posting_date są niezależne.
FIN-INV-051 — Economic reporting używa economic_date; cash reporting używa cash occurrence date.
FIN-INV-052 — Prepayment nie staje się automatycznie recognized revenue przed spełnieniem reguły recognition.

## 8. CAPEX/OPEX

FIN-INV-060 — CAPEX/OPEX jest klasyfikowane na poziomie ekonomicznej linii/alokacji, nie tylko całego dokumentu.
FIN-INV-061 — CAPEX nie jest odejmowany w bieżącym Operating Margin jak zwykły OPEX.
FIN-INV-062 — NON_BUSINESS nie wpływa na Economic Result Property.

## 9. Explainability

FIN-INV-070 — Każdy wynik finansowy musi być rozwijalny do EconomicEvents i Allocations.
FIN-INV-071 — Każda Allocation ESTIMATED/MANUAL posiada rationale i confidence.
FIN-INV-072 — Raport nie może mieszać accounting/cash/economic/investment view bez jawnego oznaczenia.

## 10. Atomic posting contract

Posting EconomicEvent jest jedną transakcją logiczną:
1. lock event/version,
2. validate status,
3. validate period,
4. validate allocations,
5. validate tenant ownership,
6. validate approvals,
7. persist POSTED state,
8. append DomainEvent,
9. commit.

Błąd na krokach 1–8 powoduje rollback całości.

## 11. Required tests before FINAL

- balanced posting succeeds,
- unbalanced posting rejects,
- direct update of POSTED fact rejects,
- duplicate posting is idempotent/rejected deterministically,
- settlement over-application rejects,
- cross-tenant allocation rejects,
- HARD_CLOSED mutation rejects.