# OSG — Implementation Waves v0.1

Status: plan techniczny przed budową
Data: 2026-09-14

## W0 — Foundation Proof

Zakres:
- PostgreSQL schema proof
- tenant constraints proof
- event/audit skeleton
- test fixtures
- no production data

Exit criteria:
- P0 schema invariants przechodzą testy
- reference dataset ładuje się bez ręcznych obejść

## W1 — Identity + Property

Zakres:
- Organization
- User/Role/Permission
- Property/Unit/Resource/Asset
- AvailabilityBlock

Exit criteria:
- role-scoped access
- cross-tenant tests
- property digital twin basic

## W2 — Reservation + Stay

Zakres:
- Reservation/ReservationItem
- Stay/StaySegment
- arrivals/departures
- AvailabilityConflict

Exit criteria:
- relocation scenario passes
- overlap protection works

## W3 — Operations

Zakres:
- Turnover
- Task
- Incident
- WorkOrder
- readiness

Exit criteria:
- checkout → turnover workflow
- critical incident → block/escalation

## W4 — Commerce

Zakres:
- Folio
- Charge
- Payment
- PaymentAllocation
- prepayment/refund/cancellation policy

Exit criteria:
- direct stay
- prepayment
- cancellation refund
- overpayment

## W5 — Financial Truth

Zakres:
- FinancialDocument
- MoneyAccount
- CashMovement
- EconomicEvent
- Allocation
- Settlement
- Reconciliation
- Period close

Exit criteria:
- mixed/private expense
- OTA payout net commission
- CAPEX/OPEX mixed invoice
- operator paid expense settlement

## W6 — Experiences

Zakres:
- Service
- ServiceBooking
- ResourceReservation
- ServiceExecution

Exit criteria:
- sauna upsell flow end-to-end
- resource conflict protection

## W7 — Analytics

Zakres:
- occupancy
- ADR
- RevPAR/TRevPAR
- Stay CM
- Unit Operating Margin
- confidence/explainability

Exit criteria:
- KPI reconciles to source facts
- Why this number works

## W8 — Integrations

Zakres:
- first real PMS/source
- bank import
- payment provider as needed
- observability/conflict queue

Exit criteria:
- idempotent sync
- no duplicated business effects

## W9 — Production Hardening

Zakres:
- backups/restore drill
- monitoring
- MFA
- rate limiting
- secrets
- performance
- security review

## W10 — PWA Release

Zakres:
- Command Center
- operator mobile workflows
- finance desktop workflows
- staged rollout Glamping Nad Stawem

## Zasada

Każda fala może rozpocząć się tylko, gdy jej zależności mają zaakceptowane kontrakty. UI nie wyprzedza fundamentu domenowego.