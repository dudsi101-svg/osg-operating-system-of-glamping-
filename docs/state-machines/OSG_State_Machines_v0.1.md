# OSG — State Machines v0.1

Status: roboczy zaawansowany
Data: 2026-09-14

## Reservation
INQUIRY → HELD → CONFIRMED → CANCELLED
CONFIRMED → NO_SHOW

Zakazane:
- CANCELLED → CONFIRMED bez jawnego REOPEN/NEW RESERVATION flow
- NO_SHOW → CHECKED_IN

## Stay
EXPECTED → CHECKED_IN → CHECKED_OUT
EXPECTED → CANCELLED

CHECKED_OUT jest terminalny dla wykonania pobytu.

## Turnover
PENDING → IN_PROGRESS → READY
PENDING/IN_PROGRESS → BLOCKED
BLOCKED → IN_PROGRESS

READY wymaga spełnienia kryteriów checklisty, jeśli template tego wymaga.

## Unit Readiness
DIRTY → CLEANING → INSPECTION → READY
Dowolny stan → BLOCKED
BLOCKED → CLEANING/INSPECTION/READY tylko przez jawny unblock flow.

## Task
OPEN → IN_PROGRESS → DONE
OPEN/IN_PROGRESS → CANCELLED
OPEN/IN_PROGRESS → BLOCKED
BLOCKED → OPEN/IN_PROGRESS

## Incident
OPEN → TRIAGED → IN_REPAIR → RESOLVED → CLOSED
OPEN/TRIAGED/IN_REPAIR → ESCALATED
ESCALATED → IN_REPAIR/RESOLVED

## ServiceBooking
REQUESTED → CONFIRMED → IN_PROGRESS → COMPLETED
REQUESTED/CONFIRMED → CANCELLED
CONFIRMED → NO_SHOW

## Charge
PENDING → POSTED → REVERSED
PENDING → VOID

## Payment
PENDING → CONFIRMED
PENDING → FAILED
CONFIRMED → PARTIALLY_REFUNDED → REFUNDED
CONFIRMED → REFUNDED

## EconomicEvent
DRAFT → REVIEWED → POSTED → REVERSED
DRAFT/REVIEWED → CANCELLED

POSTED immutable.

## FinancialDocument
IMPORTED/DRAFT → VERIFIED → POSTED
POSTED → CORRECTED

## SettlementEntry
OPEN → PARTIALLY_SETTLED → SETTLED
OPEN/PARTIALLY_SETTLED → DISPUTED
DISPUTED → OPEN/SETTLED

## Integration
DISCONNECTED → CONNECTING → ACTIVE
ACTIVE → DEGRADED → ACTIVE
ACTIVE/DEGRADED → DISABLED

## General rules
1. Każda zmiana stanu emituje DomainEvent.
2. Zakazane przejścia kończą się błędem domenowym, nie cichą korektą.
3. Reopen terminalnego stanu wymaga jawnego procesu i uprawnienia.
4. Stan pochodny nie może być modyfikowany bezpośrednio, jeśli wynika z faktów źródłowych.
