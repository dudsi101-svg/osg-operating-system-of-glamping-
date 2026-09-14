# OSG — Logical ERD v0.1

Status: proof-of-model
Data: 2026-09-14

## Cel

Logiczny model relacyjny OSG przed zamrożeniem fizycznego schematu PostgreSQL. Diagram pokazuje główne agregaty i relacje; nie jest jeszcze pełnym DDL.

```mermaid
erDiagram
    ORGANIZATION ||--o{ PROPERTY : owns
    ORGANIZATION ||--o{ PARTY : contains
    ORGANIZATION ||--o{ USER_ACCOUNT : authorizes

    PROPERTY ||--o{ ZONE : contains
    PROPERTY ||--o{ UNIT_TYPE : defines
    PROPERTY ||--o{ UNIT : contains
    PROPERTY ||--o{ RESOURCE : contains
    PROPERTY ||--o{ ASSET : contains
    PROPERTY ||--o{ CHANNEL : configures

    UNIT_TYPE ||--o{ UNIT : classifies
    ZONE ||--o{ ZONE : parent_of
    ZONE ||--o{ UNIT : locates
    ZONE ||--o{ RESOURCE : locates
    ZONE ||--o{ ASSET : locates

    UNIT ||--o{ AVAILABILITY_BLOCK : blocks
    UNIT ||--o{ STAY_SEGMENT : occupied_by
    RESOURCE ||--o{ RESOURCE_RESERVATION : reserved_by

    PARTY ||--o| GUEST_PROFILE : extends
    GUEST_PROFILE ||--o{ RESERVATION : books
    RESERVATION ||--|{ RESERVATION_ITEM : contains
    RESERVATION ||--o{ FOLIO : billed_by
    RESERVATION_ITEM ||--o{ STAY : executes
    STAY ||--|{ STAY_SEGMENT : consists_of
    STAY ||--o{ STAY_GUEST : includes
    GUEST_PROFILE ||--o{ STAY_GUEST : participates

    FOLIO ||--o{ CHARGE : contains
    FOLIO ||--o{ PAYMENT : receives
    PAYMENT ||--o{ PAYMENT_ALLOCATION : allocates
    CHARGE ||--o{ PAYMENT_ALLOCATION : covered_by

    SERVICE ||--o{ SERVICE_BOOKING : booked_as
    SERVICE_BOOKING ||--o{ RESOURCE_RESERVATION : requires
    SERVICE_BOOKING ||--o{ SERVICE_EXECUTION : executed_as
    SERVICE_BOOKING ||--o{ CHARGE : charges

    STAY ||--o{ TURNOVER : triggers
    TURNOVER ||--o{ TASK : generates
    TASK ||--o{ WORK_LOG : records
    INCIDENT ||--o{ TASK : creates
    INCIDENT ||--o{ WORK_ORDER : escalates_to
    INCIDENT ||--o{ AVAILABILITY_BLOCK : may_create

    FINANCIAL_DOCUMENT ||--|{ FINANCIAL_DOCUMENT_LINE : contains
    FINANCIAL_DOCUMENT_LINE ||--o{ ECONOMIC_EVENT : supports
    CHARGE ||--o{ ECONOMIC_EVENT : recognizes
    ECONOMIC_EVENT ||--|{ ALLOCATION : decomposes

    MONEY_ACCOUNT ||--o{ CASH_MOVEMENT : source
    MONEY_ACCOUNT ||--o{ CASH_MOVEMENT : destination
    CASH_MOVEMENT ||--o{ RECONCILIATION_LINK : matched_by
    FINANCIAL_DOCUMENT ||--o{ RECONCILIATION_LINK : matched_by
    ECONOMIC_EVENT ||--o{ RECONCILIATION_LINK : matched_by

    INVESTMENT_PROJECT ||--o{ ALLOCATION : groups_capex
    COST_CENTER ||--o{ ALLOCATION : groups_opex

    PARTY ||--o{ SETTLEMENT_ENTRY : creditor
    PARTY ||--o{ SETTLEMENT_ENTRY : debtor
    ECONOMIC_EVENT ||--o{ SETTLEMENT_ENTRY : originates

    USER_ACCOUNT ||--o{ ROLE_ASSIGNMENT : receives
    ROLE ||--o{ ROLE_ASSIGNMENT : grants
    ROLE ||--o{ ROLE_PERMISSION : includes
    PERMISSION ||--o{ ROLE_PERMISSION : assigned

    INTEGRATION ||--o{ EXTERNAL_RECORD : receives
    INTEGRATION ||--o{ EXTERNAL_REFERENCE : maps

    FILE_OBJECT ||--o{ ATTACHMENT_LINK : attached
```

## Agregaty

- Organization
- Property
- Reservation
- Stay
- Folio
- ServiceBooking
- Turnover
- Incident
- EconomicEvent
- Settlement

## Reguły granic agregatów

1. Zmiany wewnątrz agregatu preferują transakcję ACID.
2. Reakcje pomiędzy agregatami preferują Domain Events i idempotentne automatyzacje.
3. Nie tworzymy globalnych transakcji obejmujących cały system.
4. Krytyczne invariants finansowe są egzekwowane przed POSTED.
5. Availability i occupancy posiadają ochronę przed konfliktami czasowymi.

## Relacje wymagające szczególnej implementacji PostgreSQL

- brak nakładających się aktywnych StaySegments dla Unit,
- brak przekroczenia capacity ResourceReservation,
- cross-tenant FK prohibition,
- suma Allocations = EconomicEvent.amount,
- PaymentAllocation <= dostępna wartość Payment,
- uniqueness ExternalReference.

## Wnioski

Model jest wystarczająco spójny do stworzenia pierwszego fizycznego schema draft. Największe ryzyka pozostają w temporal constraints, finansowym posting workflow i integracji danych z zewnętrznym PMS.