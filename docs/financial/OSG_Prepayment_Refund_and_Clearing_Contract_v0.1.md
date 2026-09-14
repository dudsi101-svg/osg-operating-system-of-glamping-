# OSG — Prepayment, Refund & Clearing Contract v0.1

Status: kandydat do freeze
Data: 2026-09-14

## 1. Cel

Rozdzielić należność, zaliczkę, płatność, payout OTA, refund i moment rozpoznania przychodu.

## 2. Prepayment

Payment może być CONFIRMED przed wykonaniem pobytu.
Nie oznacza to automatycznie Recognized Revenue.

Prepayment posiada relację do Folio/Reservation i może zostać zaalokowany do Charges, ale revenue recognition podlega osobnej regule ekonomicznej.

## 3. Recognition

Accommodation revenue jest rozpoznawany według polityki wykonania pobytu/charge recognition, nie wyłącznie według daty wpływu środków.

Cancellation/no-show mogą tworzyć retained fee jako osobny Charge/EconomicEvent zgodnie z polityką anulacji.

## 4. Refund

Refund nie nadpisuje starego Payment.
Powstaje:
- refund transaction/fact,
- odpowiednia korekta Payment/Folio,
- EconomicEvent REFUND albo reversal revenue zgodnie z ekonomiczną przyczyną.

## 5. OTA clearing

OTA może pobrać od gościa pełną kwotę i wypłacić netto.
Model:
- guest commercial amount / Charges,
- OTA clearing/payment context,
- OTA commission EconomicEvent,
- payout CashMovement netto,
- ReconciliationLink spina fakty.

Przykład:
Guest charge 2000
OTA commission 300
Payout 1700

Revenue ≠ payout.

## 6. MoneyAccounts

Rekomendowane typy logiczne:
BANK
CASH
PAYMENT_PROVIDER_CLEARING
OTA_CLEARING
OWNER_FUNDS
OPERATOR_FUNDS
INTERNAL_CLEARING

Clearing accounts umożliwiają uzgodnienie opóźnionych payoutów bez fałszowania revenue.

## 7. Charge recognition statuses

PENDING
POSTED
RECOGNIZED
REVERSED

Dokładna implementacja może rozdzielić posting i recognition, ale semantyka musi pozostać jawna.

## 8. Cancellation

Cancellation policy jest snapshotowana przy sprzedaży.
Przy anulacji system wylicza:
- refundable amount,
- retained amount,
- cancellation fee,
- required refund,
- resulting economic treatment.

## 9. Invariants

PCR-001 — confirmed prepayment nie oznacza automatycznie recognized revenue.
PCR-002 — refund nie usuwa historycznej płatności.
PCR-003 — OTA payout netto nie zastępuje gross revenue.
PCR-004 — commission jest osobnym EconomicEvent.
PCR-005 — clearing balance jest uzgadnialny do CashMovement.
PCR-006 — cancellation economics wynika z snapshotowanej polityki, nie aktualnej konfiguracji.

## 10. Tests before FINAL

- full prepayment before stay,
- partial prepayment,
- cancellation with full refund,
- cancellation with retained fee,
- OTA net payout,
- payout containing multiple reservations,
- refund after period close.