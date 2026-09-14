-- OSG pre-v1 Unit lifecycle correction
-- Temporary operational unavailability belongs to AvailabilityBlock.

alter table unit
  drop constraint if exists unit_lifecycle_status_check;

alter table unit
  add constraint unit_lifecycle_status_check
  check (lifecycle_status in ('PLANNED','ACTIVE','RETIRED'));

-- Migration note for any DEV data created under older proof schema:
-- OUT_OF_SERVICE rows must be translated into:
--   lifecycle_status='ACTIVE'
--   + time-bounded AvailabilityBlock explaining operational unavailability.
-- Production migrations must not silently discard reason/time history.
