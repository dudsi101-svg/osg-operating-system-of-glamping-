# OSG — Deposits, Cancellations & Refunds v0.1

Status: decyzja modelowa robocza
Data: 2026-09-14

## Problem

Payment nie jest automatycznie revenue. Zaliczka może wpłynąć przed wykonaniem pobytu, rezerwacja może zostać anulowana, a część środków zwrócona lub zatrzymana.

## Decyzja

OSG rozdziela:
- Payment — otrzymana/obsłużona płatność handlowa,
- CashMovement — faktyczny przepływ,
- Charge — należność wobec gościa,
- Revenue EconomicEvent — rozpoznany przychód,
- Refund — osobny zwrotny przepływ/fakt,
- CancellationCharge — należność wynikająca z polityki anulacji.

Nie wprowadzamy jednej encji `Deposit` jako pieniędzy. Deposit/Prepayment jest rolą/klasyfikacją Payment przed rozpoznaniem przychodu.

## Payment purpose

Payment może posiadać purpose:
- PREPAYMENT
- SETTLEMENT
- SECURITY_DEPOSIT
- OTHER

Security deposit nie jest revenue i wymaga osobnego zwrotu/rozliczenia.

## Revenue recognition v0.1

Accommodation revenue jest rozpoznawane zgodnie z wykonaniem pobytu/polityką recognition, nie tylko momentem otrzymania pieniędzy.

Minimalny model R1:
- przyszły pobyt + zapłata → cash/payment, ale revenue jeszcze nie musi być recognized,
- completed stay → accommodation revenue recognized,
- cancellation/no-show → revenue tylko według obowiązującej policy snapshot.

## CancellationPolicy

Reservation zachowuje snapshot wersji polityki obowiązującej przy zawarciu.

Policy może określać:
- free cancellation deadline,
- percentage/amount retained,
- no-show treatment,
- refund timing,
- exceptions/manual override.

## Cancellation flow

Reservation.Cancelled
→ policy evaluated
→ unused accommodation charges reversed/adjusted
→ CancellationCharge created if policy requires retained fee
→ RefundDue calculated
→ Refund initiated/recorded
→ CashMovement reconciled

## Refund

Refund nie modyfikuje historycznego Payment inplace.

Payment 2000 pozostaje faktem historycznym.
Refund 1200 jest nowym faktem powiązanym z Payment/Folio.
Net cash effect może wynosić 800, ale historia pokazuje oba ruchy.

## No-show

No-show nie tworzy fikcyjnego completed Stay.
Policy może rozpoznać cancellation/no-show revenue niezależnie od Stay execution.

## Security deposit

Security deposit:
- nie wchodzi do revenue,
- nie zwiększa Folio revenue balance tak jak Charge za usługę,
- posiada outstanding liability/hold state,
- może zostać zwrócony albo częściowo zastosowany do DamageCharge zgodnie z workflow.

## Invariants

1. PREPAYMENT != recognized revenue.
2. Refund <= refundable/payment available amount.
3. CancellationCharge musi wskazywać policy version/source decision.
4. Security deposit nie jest revenue bez jawnego zastosowania do prawidłowego Charge.
5. Cancellation/no-show nie zmienia historycznych Payment/CashMovement.
6. Manual policy override posiada actor, reason i audit.

## Wniosek

GAP-002 i GAP-003 mają rozwiązanie modelowe. Konkretne parametry polityk są konfiguracją property/channel i nie blokują rdzenia schematu.