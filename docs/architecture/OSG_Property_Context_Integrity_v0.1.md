# OSG — Property Context Integrity v0.1

Status: pre-freeze P0 contract
Date: 2026-09-15

## 1. Problem

`organization_id` prevents cross-tenant references, but it does not prevent references between different Properties inside one Organization.

Example invalid state:
- Reservation belongs to Property A,
- ReservationItem.assigned_unit_id points to Unit from Property B,
- both records belong to the same Organization,
- tenant FK alone would accept the link.

OSG must protect both tenant and property context.

## 2. Rule

Any relationship with a single-property business meaning must resolve to the same `property_id` across all participating property-scoped entities.

## 3. Required invariants

### Reservation
ReservationItem.UnitType.property_id = Reservation.property_id
ReservationItem.assigned Unit.property_id = Reservation.property_id

### Stay
Stay inherits ReservationItem → Reservation property.
Every active StaySegment.Unit.property_id must equal Stay property.

### ServiceBooking
Service.property_id = ServiceBooking.property_id.
Referenced Reservation/Stay must belong to the same Property.
ResourceReservation.Resource.property_id must equal ServiceBooking property when linked.

### Operations
Turnover.Unit.property_id = Turnover.property_id.
previous_stay / next_stay belong to same Property.
Incident Unit/Resource/Asset belong to Incident.property_id.
WorkOrder Asset/Incident property context must match WorkOrder.property_id.

### Finance
EconomicEvent.property_id is nullable only for explicitly organization-level facts.
For property-owned EconomicEvent:
- Allocation.property_id must match event property for business allocations,
- linked Unit/Stay/Resource/Asset/Service/Channel/InvestmentProject/CostCenter must resolve to Allocation.property_id,
- NON_BUSINESS may intentionally omit Property but cannot falsely point to another Property.

### Folio/Commerce
Folio Reservation defines Property.
Stay attached to Folio must belong to the same Reservation/Property.

## 4. Enforcement strategy

Do not denormalize property_id into every child table solely to create FKs unless query/performance needs justify it.

Use layered enforcement:
1. domain service validates context before mutation,
2. DB guard functions protect high-risk relationships,
3. Financial POST validation checks full Allocation dimension context,
4. integration mapping validates before domain command,
5. DataQuality scan detects legacy/import anomalies.

For high-volume/simple cases where property_id is already present on both tables, prefer composite DB FK/index.

## 5. Failure code

Stable domain error:
`PROPERTY_CONTEXT_MISMATCH`

Details may identify entity types/IDs but must respect permission/privacy rules.

## 6. Multi-property consequence

This contract allows one Organization to manage many Properties without accidentally blending:
- availability,
- stays,
- resources,
- economics,
- operations.

Cross-property transfers/shared organization overhead must use an explicit organization-level or inter-property model, never accidental foreign-key mixing.
