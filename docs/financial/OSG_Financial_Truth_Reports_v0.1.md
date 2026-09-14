# OSG — Financial Truth Reports v0.1

Status: roboczy zaawansowany
Data: 2026-09-14

## 1. Zasada

OSG nie prezentuje jednej liczby "zysku" bez nazwania perspektywy.
Każdy raport pokazuje source facts, okres i poziom pewności.

## 2. Accounting View

Pokazuje dokumenty i klasyfikację księgową dostępną w OSG/importowaną z księgowości.
Nie jest to Economic Truth.

Minimalne sekcje:
- dokumenty sprzedażowe
- dokumenty kosztowe
- podatki/status księgowy, jeśli źródło je dostarcza
- niezaksięgowane dokumenty

## 3. Cash View

Formula:
opening cash + cash inflows - cash outflows = closing cash

Rozdziela:
- operating inflows/outflows
- owner contributions/withdrawals
- transfers
- tax payments
- CAPEX payments
- settlement payments

Transfer między własnymi MoneyAccounts nie zwiększa ani nie zmniejsza cash netto organizacji.

## 4. Operating View

Revenue recognized
- direct variable OPEX
- shared OPEX
- overhead
= Operating Result

Wyłącza CAPEX z bieżącego wyniku operacyjnego.

## 5. Economic View

Uwzględnia ekonomiczną alokację niezależnie od formalnego dokumentu i płatnika.

Przykład:
Invoice total: 8 000 PLN
Economic allocation to GNS: 1 600 PLN
NON_BUSINESS: 6 400 PLN

Economic View obciąża GNS kwotą 1 600 PLN.

## 6. Investment View

- InvestmentProject
- committed CAPEX
- paid CAPEX
- economic CAPEX
- target Unit/Resource/Asset
- budget variance
- completion state

CAPEX jest raportowany osobno od Operating Result.

## 7. Owner/Operator Settlement View

Dla każdej Party:
- opening settlement balance
- expenses paid for business
- business amounts paid on behalf of party
- repayments
- manual adjustments with approval
- closing balance

Saldo wynika z SettlementEntry + applications.

## 8. Stay Economics

Per Stay:
- accommodation revenue
- service/add-on revenue
- discounts/refunds
- OTA commission
- payment fees
- direct cleaning
- direct consumables
- direct experience cost
- other direct variable cost
= Stay Contribution Margin

## 9. Unit Economics

Per Unit / period:
- allocated accommodation revenue
- allocated service revenue
- direct variable cost
- contribution margin
- shared OPEX allocation
- maintenance OPEX
- unit operating margin
- CAPEX shown separately

## 10. Channel Economics

Per Channel:
- bookings
- recognized revenue
- commission
- payment/transaction fees
- cancellation/refund impact
- contribution after channel costs
- direct booking comparison

## 11. Data Confidence Panel

Każdy raport pokazuje:
- % VERIFIED
- % SYSTEM_DERIVED
- % ESTIMATED
- % MANUAL
- % UNKNOWN

Przykład komunikatu:
"Economic Result: 29 250 PLN; 91% wartości opiera się na verified/system-derived allocations, 9% na estimates/manual allocations."

## 12. Why this number?

Każda wartość agregowana ma drill-down:
metric/report line
→ allocation
→ economic event
→ charge/document/cash/source

## 13. Period semantics

Raport zawsze wskazuje:
- report period
- timezone
- recognition basis
- closed/open period state
- metric/report version

## 14. Prohibited presentations

- Accounting profit labelled as economic profit
- Bank inflow labelled as revenue without reconciliation
- CAPEX mixed into operating cost without separate disclosure
- estimated lost revenue labelled as actual loss
- manually estimated allocations shown without confidence marker
