-- OSG PostgreSQL constraints proof v0.1
-- Non-production proof-of-model.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 1. Prevent overlapping active stay segments on the same unit.
ALTER TABLE stay_segments
ADD CONSTRAINT stay_segments_no_overlap
EXCLUDE USING gist (
  unit_id WITH =,
  tstzrange(start_at, end_at, '[)') WITH &&
)
WHERE (status IN ('EXPECTED','CHECKED_IN'));

-- 2. Availability block range validity.
ALTER TABLE availability_blocks
ADD CONSTRAINT availability_blocks_valid_range
CHECK (end_at > start_at);

-- 3. Reservation item date validity.
ALTER TABLE reservation_items
ADD CONSTRAINT reservation_items_valid_dates
CHECK (departure_date > arrival_date);

-- 4. Resource reservation range validity.
ALTER TABLE resource_reservations
ADD CONSTRAINT resource_reservations_valid_range
CHECK (effective_end_at > effective_start_at);

-- Capacity >1 cannot be enforced safely by a simple exclusion constraint.
-- It requires transactional validation/serialization at write time.

-- 5. Economic event values.
ALTER TABLE economic_events
ADD CONSTRAINT economic_events_nonzero_amount
CHECK (amount <> 0);

ALTER TABLE allocations
ADD CONSTRAINT allocations_nonzero_amount
CHECK (amount <> 0);

-- Full allocation is enforced by posting transaction, not row CHECK,
-- because the invariant depends on a SUM across child rows.

-- 6. Payment allocations.
ALTER TABLE payment_allocations
ADD CONSTRAINT payment_allocations_positive_amount
CHECK (amount > 0);

-- Aggregate ceilings are enforced transactionally in service layer/database function.

-- 7. External reference idempotency.
CREATE UNIQUE INDEX IF NOT EXISTS uq_external_reference
ON external_references(integration_id, external_type, external_id);

-- 8. Human-readable codes are unique per organization where applicable.
CREATE UNIQUE INDEX IF NOT EXISTS uq_reservation_code_org
ON reservations(organization_id, reference_code)
WHERE archived_at IS NULL;

-- 9. Settlement parties cannot be equal.
ALTER TABLE settlement_entries
ADD CONSTRAINT settlement_distinct_parties
CHECK (creditor_party_id <> debtor_party_id);

-- 10. Posted facts immutable: implemented by trigger/function in proof v0.2.
-- 11. Cross-tenant integrity: implemented by composite FK / tenant validation strategy.
-- 12. Financial posting: one serialized transaction validates sum(allocations) = event amount.
