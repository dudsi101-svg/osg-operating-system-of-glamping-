# OSG — Owner / Finance Cockpit v0.1

Status: product contract
Data: 2026-09-14

## 1. Cel

Ekran właścicielski ma odpowiadać na pytania zarządcze, a nie powielać księgowość.

## 2. Główne pytania

- Ile naprawdę zarobiliśmy?
- Ile pieniędzy faktycznie mamy/straciliśmy?
- Co było CAPEX, a co bieżącym OPEX?
- Które jednostki generują wartość?
- Jakie koszty są niepewne lub nierozliczone?
- Kto komu jest winien pieniądze?
- Jakie decyzje wymagają mojej akceptacji?

## 3. Top-level perspectives

### Economic
Revenue, Contribution Margin, Economic Operating Result.

### Cash
Cash inflows/outflows, cash balance movement, unreconciled movements.

### Investment
CAPEX by project/unit/resource, budget vs actual.

### Accounting reference
Documents/posting status/import/export indicators — bez udawania pełnego systemu księgowego.

## 4. Required widgets

- Economic Result current month
- Cash Movement current month
- CAPEX current month/YTD
- Unit Operating Margin ranking
- OTA Cost
- Settlement balances
- Unreconciled cash/documents
- Estimated/manual allocation exposure
- Approval queue
- Data confidence

## 5. Drill-down

Każdy widget wspiera:
summary → category/unit/channel → allocation/economic event → source document/cash movement.

## 6. Settlement view

Nie wyświetlamy tylko `Michał saldo / Kuba saldo` jako ręcznej wartości.
Widok pokazuje:
- open entries,
- source expense/event,
- payer,
- economic bearer,
- repayments/applications,
- aging.

## 7. Financial Truth comparison

Jeden okres może pokazać obok siebie:
Accounting document costs
Cash outflows
OPEX economic cost
CAPEX
Economic Operating Result

System jawnie wyjaśnia, dlaczego liczby się różnią.

## 8. Alerts

- large estimated allocation
- settlement overdue
- CAPEX above budget
- unreconciled bank movement
- material margin drop
- data confidence drop
- unusual cost/unit increase

AI/anomaly alerts są późniejszą warstwą; podstawowe reguły mogą działać deterministycznie.

## 9. Permissions

OWNER/FINANCE pełny dostęp według scope.
OPERATOR może mieć wybrane ekonomiczne KPI potrzebne do zarządzania, ale nie musi widzieć pełnych danych właścicielskich/podatkowych.

## 10. Principle

Cockpit nie pokazuje jednej liczby `Profit`, jeśli jej znaczenie jest niejednoznaczne. Każdy wynik ma nazwę perspektywy i możliwość `Why this number?`.