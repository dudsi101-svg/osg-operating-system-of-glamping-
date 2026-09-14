# OSG — Folio Close & Balance Contract v0.1

Status: pre-freeze contract
Date: 2026-09-15

## 1. Purpose

Folio represents the commercial account of a Reservation/Stay. It is not cash truth and not economic profit.

Canonical balance:

`balance_due = net_charges - (gross_confirmed_payments - confirmed_refunds)`

where reversing Charges remain visible as historical commercial adjustments.

## 2. Status semantics

### OPEN
Commercial account may still receive Charges, Payments, Refunds or corrections.

### CLOSED
Commercial account is settled.

Default invariant:
`abs(balance_due) <= 0.01` in Folio currency.

An unpaid receivable does not become CLOSED merely because the Stay ended. It remains OPEN until settled/corrected/write-off workflow creates the appropriate commercial/economic evidence.

### VOID
Folio was invalidated through explicit workflow. VOID does not mean deleting history.
Associated Charges/Payments remain auditable and must be reversed/refunded as required.

## 3. Currency

Release 1 Folio is single-currency:
- `Payment.currency = Folio.currency`
- `Refund.currency = Payment.currency`
- Charge amounts on a Folio are interpreted in Folio.currency

FX payment scenarios require explicit future conversion model and are out of v1 scope.

## 4. Close command

`CloseFolio` workflow:
1. lock Folio,
2. verify status OPEN,
3. compute canonical Folio balance,
4. reject if outside tolerance,
5. validate no pending commercial workflow that policy marks blocking,
6. set CLOSED + closed_at + version,
7. emit `Folio.Closed` through outbox.

Stable error:
`FOLIO_BALANCE_NOT_ZERO`.

## 5. Refund behavior

Payment is historical receipt evidence and is not erased when refunded.
Refund is a separate fact.

For a full-refund cancellation:
- original Charge remains,
- reversing Charge removes commercial obligation,
- original Payment remains historical,
- Refund offsets net collected cash/commercial settlement,
- final Folio balance becomes zero.

## 6. Write-off

A debt write-off must not be implemented by manually setting Folio balance to zero.
It requires an explicit reversing/adjustment Charge and, where economically relevant, an EconomicEvent/Allocation.

## 7. Explainability

Folio balance drill-down:
Folio → Charges/reversals → Payments → Refunds → PaymentAllocations → Cash/Reconciliation where available.
