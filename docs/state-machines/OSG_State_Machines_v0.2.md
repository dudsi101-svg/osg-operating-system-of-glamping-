# OSG — State Machines v0.2

Status: canonical pre-v1 candidate
Date: 2026-09-15

State change is a domain command, not arbitrary CRUD update. Guards/side effects below are normative.

## 1. Reservation

`INQUIRY → HELD → CONFIRMED → CANCELLED`

Additional terminal/commercial outcome:
`CONFIRMED → NO_SHOW`

Rules:
- CONFIRMED captures/updates CommercialPolicySnapshot.
- CANCELLED after payment executes cancellation/refund commercial workflow; does not delete Reservation.
- NO_SHOW does not create fake Stay/commercial accommodation nights.
- transition obeys external-field ownership when PMS is source-of-truth.

## 2. ReservationItem

`ACTIVE → CANCELLED`

Unit assignment/change is versioned mutation while ACTIVE and must satisfy Property context + availability conflict policy.

## 3. Stay

`EXPECTED → CHECKED_IN → CHECKED_OUT`

Exceptional:
`EXPECTED → CANCELLED`

Rules:
- CHECKED_IN requires assigned/available executable accommodation context.
- CHECKED_OUT emits `Stay.CheckedOut` atomically through outbox.
- relocation while CHECKED_IN mutates StaySegments, not Stay identity.
- CHECKED_OUT is final execution truth; correction needs explicit exceptional workflow, never casual status rollback.

## 4. StaySegment

`ACTIVE → CANCELLED`

Active intervals are temporally exclusive per Unit.
Relocation closes/shortens current segment and creates destination segment transactionally according to workflow.

## 5. Folio

`OPEN → CLOSED`
`OPEN → VOID`

Controlled exceptional:
`CLOSED → OPEN` only through privileged reopen.

CLOSED guard:
- abs(balance_due) ≤ 0.01,
- no blocking pending Charge/Payment/Refund,
- authorization/version check.

VOID requires explicit reversal/refund handling; does not delete commercial history.

## 6. Charge

`PENDING → POSTED → RECOGNIZED`

No mutable REVERSED state in v1.

Correction/reversal:
`new opposite-sign Charge → reverses_charge_id=original`

POSTED/RECOGNIZED material fields are immutable.

## 7. Payment

`PENDING → CONFIRMED`
`PENDING → FAILED`
`CONFIRMED → PARTIALLY_REFUNDED → REFUNDED`
`CONFIRMED → REFUNDED`

Payment remains historical receipt fact. Refund is separate entity/fact.

## 8. Refund

`PENDING → CONFIRMED`
`PENDING → FAILED`

Confirmed cumulative Refund ≤ Payment amount and currency matches Payment.

## 9. ServiceBooking

`REQUESTED → CONFIRMED → IN_PROGRESS → COMPLETED`

Exceptional:
- REQUESTED/CONFIRMED → CANCELLED
- CONFIRMED → NO_SHOW

Resource capacity is reserved in transactional workflow before CONFIRMED acceptance when required.

## 10. ResourceReservation

`HELD → CONFIRMED → IN_PROGRESS → COMPLETED`

Exceptional:
- HELD → EXPIRED
- HELD/CONFIRMED → CANCELLED

Capacity-consuming states:
HELD (until expires), CONFIRMED, IN_PROGRESS.

## 11. Turnover

`PENDING → IN_PROGRESS → READY`

Exceptional:
`PENDING/IN_PROGRESS → BLOCKED → IN_PROGRESS/READY`
`PENDING → CANCELLED`

READY requires configured mandatory work/inspection conditions.

## 12. Task

`OPEN → IN_PROGRESS → DONE`

Exceptional:
`OPEN/IN_PROGRESS → BLOCKED`
`OPEN/IN_PROGRESS/BLOCKED → CANCELLED`
`BLOCKED → OPEN/IN_PROGRESS`

If Task type requires WorkLog/checklist, DONE guard validates evidence.

## 13. Incident

`OPEN → TRIAGED → IN_REPAIR → RESOLVED → CLOSED`

Alternative:
`TRIAGED → RESOLVED`

Rules:
- safety/critical Incident may immediately create AvailabilityBlock/alert,
- RESOLVED may initiate inspection/unblock workflow,
- CLOSED means operational postconditions are complete, not merely repair task finished.

## 14. AvailabilityBlock

`ACTIVE → ENDED`
`ACTIVE → CANCELLED`

Block keeps original interval/reason history.
ENDING records ended_at; it does not delete block.

## 15. EconomicEvent

`DRAFT → REVIEWED → POSTED`

No in-place POSTED → REVERSED transition in normal flow.

Correction:
new EconomicEvent with:
- effect_direction REVERSAL/NORMAL,
- reverses_event_id / relates_to_financial_period where relevant.

POST guard requires:
- full allocation,
- correct Property dimensions,
- reporting currency,
- matching non-HARD-CLOSED FinancialPeriod,
- approvals where policy requires.

## 16. FinancialPeriod

`OPEN → SOFT_CLOSED → HARD_CLOSED`
`OPEN → HARD_CLOSED` allowed by policy.

Exceptional reopen:
`SOFT_CLOSED/HARD_CLOSED → OPEN` only controlled privileged workflow + audit/approval.

HARD_CLOSED prevents in-place mutation of events recognized in that period.

## 17. SettlementEntry

Derived operational states:
- OPEN
- PARTIALLY_SETTLED
- SETTLED
- REVERSED (source correction workflow)

Balance status is derived from SettlementApplications, not manually set as amount remaining.

## 18. FinancialDocument

`DRAFT → VERIFIED → POSTED`

Correction uses source correction document/link policy; document classification does not own Economic Truth.

## 19. IntegrationProcessingRecord

`RECEIVED → PROCESSING → SUCCEEDED`

Failures:
- PROCESSING → FAILED_RETRYABLE → PROCESSING
- PROCESSING → FAILED_FINAL
- duplicate claim → DUPLICATE/safe replay behavior

## 20. AutomationExecution

`PENDING → RUNNING → SUCCEEDED`

Failures:
- RUNNING → FAILED_RETRYABLE → RUNNING
- RUNNING → FAILED_FINAL
- PENDING/RUNNING → SKIPPED when business precondition no longer applies

## 21. GuestMatchCandidate

`OPEN → CONFIRMED_MATCH`
`OPEN → REJECTED`
`OPEN → EXPIRED`

CONFIRMED_MATCH may drive separate GuestMergeEvent/Alias workflow. Candidate state itself does not rewrite GuestProfiles.

## 22. Recommendation / Intelligence

`GENERATED → REVIEWED → ACCEPTED/REJECTED`
`ACCEPTED → EXECUTED`
`GENERATED/REVIEWED → EXPIRED`

A2/A3/A4 actions still execute normal domain command/approval flows; Recommendation acceptance does not bypass permissions.

## 23. CommandIdempotency

`IN_PROGRESS → SUCCEEDED`
`IN_PROGRESS → FAILED_RETRYABLE → IN_PROGRESS`
`IN_PROGRESS → FAILED_FINAL`

Same key + same request after SUCCEEDED replays outcome.
Same key + different request hash is conflict.

## Global transition rule

A transition rejected by a state machine is a domain conflict/invariant error. Agents/UI may not solve it by direct table mutation.
