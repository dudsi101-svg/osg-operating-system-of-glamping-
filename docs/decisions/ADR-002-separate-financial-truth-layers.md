# ADR-002 — Separate Financial Truth Layers

Status: Accepted
Date: 2026-09-14

## Context
Pierwotny prototyp opierał się na szerokim pojęciu Transaction i procentowym udziale glampingu. To nie wystarcza do wiarygodnego rozdzielenia dokumentów księgowych, faktycznych przepływów pieniędzy, ekonomicznego znaczenia zdarzeń i alokacji.

## Decision
OSG rozdziela co najmniej cztery niezależne warstwy:

1. FinancialDocument / FinancialDocumentLine — co wynika z dokumentu źródłowego.
2. CashMovement — co faktycznie przepłynęło pomiędzy MoneyAccounts.
3. EconomicEvent — co wydarzyło się ekonomicznie.
4. Allocation — do czego ekonomicznie przypisujemy zdarzenie.

Dodatkowo istnieją Reconciliation i Settlement.

## Consequences
OSG może jednocześnie pokazywać accounting view, cash view, operating view, economic view i investment view bez mieszania ich w jedną liczbę.

Posted facts są korygowane przez reversal/corrective entries zamiast cichego nadpisania.

## Rejected alternatives
- jedna tabela Transaction jako źródło wszystkiego,
- procent realnego udziału jako jedyny model alokacji,
- utożsamianie payment z cash movement,
- utożsamianie faktury z ekonomicznym kosztem.
