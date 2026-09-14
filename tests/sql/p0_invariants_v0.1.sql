-- OSG P0 invariant proof scaffold v0.1
-- NON-PRODUCTION. Adapt table/enum names to the first DEV migration.
-- Intended to be converted to pgTAP/pytest integration tests.

BEGIN;

-- -----------------------------------------------------------------
-- P0-STAY-001: overlapping active stay segments must fail.
-- Expected enforcement: exclusion constraint on unit_id + tstzrange.
-- -----------------------------------------------------------------
-- INSERT INTO stay_segments (... unit_id, start_at, end_at, status)
-- VALUES (..., :'forest_id', '2026-09-20 13:00+00', '2026-09-23 09:00+00', 'ACTIVE');
--
-- SAVEPOINT before_overlap;
-- INSERT INTO stay_segments (... unit_id, start_at, end_at, status)
-- VALUES (..., :'forest_id', '2026-09-22 13:00+00', '2026-09-24 09:00+00', 'ACTIVE');
-- EXPECT: exclusion_violation / OSG mapped error STAY_SEGMENT_OVERLAP.
-- ROLLBACK TO SAVEPOINT before_overlap;

-- Adjacent range [start,end) must succeed.
-- INSERT second segment starting exactly at previous end.

-- -----------------------------------------------------------------
-- P0-RESOURCE-001: exclusive resource concurrency.
-- -----------------------------------------------------------------
-- Transaction A and B must execute in parallel in integration test.
-- A: reserve Sauna effective range 17:30-19:45.
-- B: reserve overlapping range.
-- EXPECT: exactly one committed reservation when booking_mode=EXCLUSIVE.

-- -----------------------------------------------------------------
-- P0-FIN-001/002: atomic posting and full allocation.
-- -----------------------------------------------------------------
-- Create EconomicEvent amount 8000 DRAFT.
-- Create allocations 1600 + 6400.
-- CALL post_economic_event(event_id, expected_version, actor_id);
-- EXPECT status POSTED.
--
-- Create second event amount 8000 with allocations 1600 + 6300.
-- CALL post_economic_event(...);
-- EXPECT OSG error ALLOCATION_NOT_BALANCED and full rollback.

-- -----------------------------------------------------------------
-- P0-FIN-003: posted event immutable.
-- -----------------------------------------------------------------
-- UPDATE economic_events SET amount = 9000 WHERE id = :'posted_event_id';
-- EXPECT reject from permission/trigger/domain path.
-- Production policy should prevent direct application writes to immutable fields.

-- -----------------------------------------------------------------
-- P0-SETTLEMENT-001: settlement conservation.
-- -----------------------------------------------------------------
-- Settlement 430.
-- Apply 200, then 230 => open_balance 0.
-- Attempt extra 1 => reject SETTLEMENT_OVER_APPLIED.

-- -----------------------------------------------------------------
-- P0-TENANT-001: cross-tenant reference.
-- -----------------------------------------------------------------
-- ORG_A reservation + ORG_B unit assignment.
-- EXPECT composite-FK/domain/RLS rejection.

-- -----------------------------------------------------------------
-- P0-IDEMP-001: duplicate external event.
-- -----------------------------------------------------------------
-- INSERT integration_event claim for (integration_id, external_event_id).
-- Repeat same claim concurrently.
-- EXPECT unique winner; duplicate points to original processing record.

ROLLBACK;

-- Concurrency proofs cannot be reliably demonstrated in one SQL transaction file.
-- CI implementation should use pytest + two DB connections for:
-- * resource concurrent booking
-- * duplicate command claim
-- * optimistic version conflict
