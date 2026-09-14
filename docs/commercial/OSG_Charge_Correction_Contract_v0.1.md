# OSG — Charge Correction & Reversal Contract v0.1

Status: pre-freeze contract
Date: 2026-09-15

## 1. Problem

Having both:
- `Charge.status = REVERSED`, and
- a separate reversing Charge

creates ambiguous balance semantics and can double-reverse an obligation.

## 2. Decision

Release 1 Charge statuses:
- PENDING
- POSTED
- RECOGNIZED

There is no mutable `REVERSED` terminal state for an original posted Charge.

Correction/reversal is represented by a **new Charge**.

## 3. Reversing Charge

A reversing Charge:
- has `reverses_charge_id` pointing to original Charge,
- belongs to the same Folio,
- has opposite monetary sign to the original Charge,
- may be full or partial,
- remains separately auditable,
- cannot cumulatively reverse more than the absolute original amount without explicit new adjustment semantics.

Example:
original accommodation `+1000`
full reversal `-1000 → reverses original`
net Folio Charges = 0.

## 4. Posted Charge immutability

Once Charge is POSTED or RECOGNIZED, material fields are immutable:
- folio_id
- charge_type
- quantity
- unit_price
- gross/net/tax amounts
- reverses_charge_id

Description may also be treated immutable in v1 for audit simplicity.

Correction creates a new Charge instead of editing history.

## 5. Recognition

Charge commercial lifecycle and EconomicEvent recognition remain separate concepts.

A Charge can exist/post before economic revenue is recognized.
Economic recognition/reversal is represented through EconomicEvent + Allocation.

## 6. Discounts

A Discount may be a negative standalone Charge without `reverses_charge_id` if it represents original pricing rather than a correction of a specific prior Charge.

## 7. Folio balance

Only POSTED/RECOGNIZED Charges enter final commercial balance. PENDING is excluded.

Original + reversing Charges naturally net without status mutation.
