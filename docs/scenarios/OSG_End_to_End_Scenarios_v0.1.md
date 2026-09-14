# OSG — End-to-End Scenario Walkthroughs v0.1

Status: roboczy walidacyjny
Data: 2026-09-14

## Cel

Sprawdzić, czy model OSG potrafi odwzorować rzeczywiste sytuacje bez skrótów semantycznych i bez mieszania domen.

## Scenario 01 — Direct stay, full payment, no extras

1. Reservation.Created
2. ReservationItem created for Forest
3. Folio opened
4. Accommodation Charge posted
5. Payment confirmed
6. PaymentAllocation applied
7. CashMovement imported/reconciled
8. Stay checked in
9. Stay checked out
10. Turnover created
11. Stay revenue recognized
12. Stay Contribution Margin calculated

Expected invariants:
- Charge != Payment != CashMovement
- Folio balance = 0
- Stay exists independently of Reservation
- Turnover starts after checkout

## Scenario 02 — Booking.com payout net of commission

Guest price: 2000 PLN
OTA commission: 300 PLN
Bank payout: 1700 PLN

Required facts:
- Charge revenue 2000
- Payment/OTA settlement context 2000
- EconomicEvent OTA_COMMISSION 300
- CashMovement +1700
- reconciliation connects payout and settlement
- Stay margin subtracts 300 commission

No model may pretend bank inflow 1700 = total revenue.

## Scenario 03 — Kuba pays operating expense personally

Kuba pays 430 PLN for cleaning supplies.

Facts:
- FinancialDocument or receipt
- CashMovement may be represented through KUBA_PRIVATE_EXPENSES account
- EconomicEvent OPEX 430
- Allocation Property=GNS, CostCenter=Housekeeping
- paid_by=Kuba
- economic_bearer=Glamping
- SettlementEntry Glamping → Kuba 430

Repayment later:
- bank CashMovement
- SettlementApplication
- settlement balance returns to zero

## Scenario 04 — Mixed/private company expense

Invoice: 8000 PLN vehicle-related
Economic allocation:
- 1600 PLN OPEX GNS
- 6400 PLN NON_BUSINESS

System must show:
Accounting document total: 8000
Economic GNS cost: 1600
Non-business: 6400

## Scenario 05 — CAPEX and OPEX on one invoice

Invoice:
- 5000 construction material for new unit
- 800 pool chemicals
- 700 tools

Possible allocations:
- 5000 CAPEX → InvestmentProject
- 800 OPEX → wellness/property
- tools classified according to actual business rule

Whole invoice cannot carry one CAPEX/OPEX label.

## Scenario 06 — Forest unavailable because of failure

Incident.Reported: heating failure
severity HIGH
Automation creates AvailabilityBlock
Forest removed from sellable capacity
Maintenance Task/WorkOrder created
Repair cost allocated to Forest/Asset
Incident resolved
Inspection passed
AvailabilityBlock ended

Metrics:
Occupancy denominator excludes legitimate blocked nights.
Lost revenue is estimation only.

## Scenario 07 — Unit change during stay

Guest books Forest.
Actual stay:
- Day 1 Forest
- Days 2-3 Ostoja due to incident

One Stay
Two StaySegments
No overwrite of original history.
Revenue/cost attribution may split according to defined rule.
Incident linked to relocation.

## Scenario 08 — Sauna upsell

Guest in Forest purchases Sauna 90 min.

- ServiceBooking created
- ResourceReservation created including buffers
- Charge posted to Folio
- preparation Task created
- ServiceExecution captures actual usage
- direct service cost attributed to Stay
- resource utilization metric updated

## Scenario 09 — Guest cancels after payment

- Reservation confirmed
- Payment confirmed
- Cancellation
- cancellation policy generates retained fee/refund
- Refund is separate payment/financial fact
- no completed Stay
- commercial revenue recognition follows policy, not original booking total

## Scenario 10 — Duplicate reservation event from PMS

Same external event arrives five times.

Expected:
- one Reservation
- one ExternalRecord per policy/event or deduplicated event ledger
- idempotency key prevents duplicate domain effects
- audit/integration metrics record repeats safely

## Scenario 11 — Shared electricity allocation

Monthly electricity: 5000 PLN

AllocationRule v1:
- selected basis = occupied nights / usage meter / hybrid
- result versioned
- sum allocations = 5000
- report can reproduce historical calculation after rule changes

## Scenario 12 — Month close and late invoice

August HARD_CLOSED.
September receives invoice economically relating to August.

System must not silently mutate closed August.
Uses configured controlled reopen or September adjustment with reference to August.
Both accounting/economic implications remain explainable.

## Findings / architectural confirmations

1. Separate FinancialDocument, CashMovement, EconomicEvent and Allocation is necessary.
2. StaySegment is required.
3. AvailabilityBlock must affect sellable capacity rather than physical capacity.
4. Settlement must be derived from payer/bearer semantics.
5. ServiceBooking and ResourceReservation must remain separate.
6. Domain Events need correlation/causation IDs.
7. Period-close policy materially affects Financial Truth.
8. Integration idempotency is a core invariant, not infrastructure detail.

## New open items discovered

- exact revenue recognition policy for cancellation/no-show
- rule for splitting accommodation revenue after mid-stay relocation
- treatment of deposits/prepayments
- treatment of OTA clearing accounts
- policy for manual CashMovement representing owner/operator private funds
- rule hierarchy when AvailabilityBlock and existing Reservation overlap
- threshold/approval for automatic economic classifications
