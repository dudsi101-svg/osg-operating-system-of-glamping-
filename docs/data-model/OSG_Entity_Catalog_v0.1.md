# OSG — Entity Catalog v0.1

Status: pre-freeze catalog
Data: 2026-09-14

## Legenda mutowalności

- CONFIG — konfiguracyjna, wersjonowana/archiwizowana
- OPERATIONAL — zmienna podczas workflow
- FACT — historyczny fakt, po finalizacji immutable/corrective
- DERIVED — projekcja, nie source of truth
- APPEND — append-only

| Domena | Encja | Typ | Owner | Uwagi |
|---|---|---|---|---|
| Tenancy | Organization | CONFIG | OSG | tenant boundary |
| Identity | Party | CONFIG | OSG | person/company/platform |
| Identity | UserAccount | CONFIG | Auth/OSG | login identity |
| Identity | Role | CONFIG | OSG | permission bundle |
| Identity | Permission | CONFIG | OSG | stable permission code |
| Identity | RoleAssignment | CONFIG | OSG | scoped role |
| Property | Property | CONFIG | OSG | physical hospitality property |
| Property | Zone | CONFIG | OSG | spatial grouping |
| Property | UnitType | CONFIG | OSG | accommodation category |
| Property | Unit | CONFIG | OSG | physical unit |
| Property | Resource | CONFIG | OSG | limited bookable/usable resource |
| Property | Asset | CONFIG | OSG | maintainable asset |
| Property | AvailabilityBlock | OPERATIONAL/FACT | OSG | time-bound non-sellability |
| Property | AvailabilityConflict | OPERATIONAL | OSG | block vs commercial commitment |
| Guest | GuestProfile | CONFIG | OSG | canonical CRM profile |
| Commerce | Channel | CONFIG | OSG | sales channel |
| Commerce | Reservation | OPERATIONAL/FACT | PMS/OSG by field | commercial commitment |
| Commerce | ReservationItem | OPERATIONAL/FACT | PMS/OSG by field | stay product line |
| Stay | Stay | OPERATIONAL/FACT | OSG | actual execution |
| Stay | StaySegment | FACT | OSG | actual unit occupancy segment |
| Stay | StayGuest | FACT | OSG | participation |
| Commerce | Folio | OPERATIONAL | OSG | hospitality account |
| Commerce | Charge | FACT after POSTED | OSG | amount owed |
| Commerce | Payment | FACT after CONFIRMED | provider/OSG | commercial payment fact |
| Commerce | PaymentAllocation | FACT | OSG | payment → charge application |
| Commerce | Refund | FACT | OSG/provider | linked reverse payment flow |
| Commerce | CancellationPolicy | CONFIG/versioned | OSG | terms snapshot source |
| Experience | Service | CONFIG | OSG | sellable service |
| Experience | Package | CONFIG/versioned | OSG | composition |
| Experience | PackageComponent | CONFIG/versioned | OSG | decomposable component |
| Experience | ServiceBooking | OPERATIONAL/FACT | OSG | booked service |
| Experience | ResourceReservation | OPERATIONAL/FACT | OSG | resource slot |
| Experience | ServiceExecution | FACT | OSG | actual execution |
| Operations | Turnover | OPERATIONAL/FACT | OSG | unit preparation process |
| Operations | Task | OPERATIONAL | OSG | unit of work |
| Operations | TaskTemplate | CONFIG/versioned | OSG | process template |
| Operations | WorkLog | FACT | OSG | performed labor |
| Operations | Incident | OPERATIONAL/FACT | OSG | adverse occurrence |
| Operations | WorkOrder | OPERATIONAL/FACT | OSG | external/internal maintenance order |
| Inventory | InventoryItem | CONFIG | OSG | optional R1-light |
| Inventory | InventoryLocation | CONFIG | OSG | optional |
| Inventory | StockMovement | FACT | OSG | inventory movement |
| Financial | FinancialDocument | FACT after VERIFIED/POSTED | document/accounting | source evidence |
| Financial | FinancialDocumentLine | FACT | document/accounting | line evidence |
| Financial | MoneyAccount | CONFIG | OSG | bank/cash/clearing/private logical account |
| Financial | CashMovement | FACT | bank/OSG | actual movement |
| Financial | EconomicEvent | FACT after POSTED | OSG | economic meaning |
| Financial | Allocation | FACT after parent POSTED | OSG | economic attribution |
| Financial | AllocationRule | CONFIG/versioned | OSG | shared cost logic |
| Financial | CostCenter | CONFIG | OSG | managerial grouping |
| Financial | InvestmentProject | OPERATIONAL/FACT | OSG | CAPEX context |
| Financial | SettlementEntry | FACT | OSG | party receivable/payable |
| Financial | SettlementApplication | FACT | OSG | settlement clearing |
| Financial | ReconciliationLink | FACT/OPERATIONAL | OSG | links independent truths |
| Financial | AccountingPeriod | CONFIG/FACT | OSG | OPEN/SOFT/HARD close |
| Revenue | RatePlan | CONFIG/versioned | PMS/OSG | pricing policy |
| Revenue | Rate | CONFIG/time-series | PMS/OSG | rate value |
| Revenue | CommissionRule | CONFIG/versioned | OSG | expected commission |
| System | DomainEvent | APPEND | OSG | business event |
| System | AuditEvent | APPEND | OSG | change history |
| System | AutomationRule | CONFIG/versioned | OSG | trigger-condition-action |
| System | AutomationExecution | APPEND | OSG | execution record |
| Integration | Integration | CONFIG | OSG | provider connection |
| Integration | ExternalRecord | APPEND | external | raw/source snapshot |
| Integration | ExternalReference | CONFIG/FACT | OSG | identity mapping |
| Integration | SyncRun | APPEND | OSG | integration observability |
| Quality | DataQualityIssue | OPERATIONAL/FACT | OSG | detected quality issue |
| Files | FileObject | FACT | OSG/storage | metadata only |
| Files | AttachmentLink | CONFIG/FACT | OSG | typed association |
| Messaging | Conversation | OPERATIONAL | OSG | communication context |
| Messaging | Message | FACT | provider/OSG | immutable sent/received content snapshot |
| Messaging | MessageTemplate | CONFIG/versioned | OSG | reusable communication |
| Privacy | Consent | FACT | OSG | versioned consent event |
| Analytics | MetricDefinition | CONFIG/versioned | OSG | semantic definition |
| Analytics | MetricResult | DERIVED/cache | OSG | recomputable |

## Krytyczne rozróżnienia

- Reservation != Stay
- ServiceBooking != ServiceExecution
- Charge != Payment != CashMovement != EconomicEvent
- Resource != Asset
- UnitType != Unit
- Task != Incident != WorkOrder
- FinancialDocument != EconomicEvent
- AccountingPeriod close != cash date

## Kandydaci do odłożenia poza R1

Inventory pełne, Conversation omnichannel, zaawansowane RatePlan, Package advanced, MetricResult persistence.

## Kryterium Schema Freeze

Każda encja R1 musi mieć:
- purpose,
- owner,
- lifecycle,
- primary relationships,
- mutation policy,
- permission class,
- source-of-truth policy.