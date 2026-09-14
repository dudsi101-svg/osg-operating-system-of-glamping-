-- Glamping Nad Stawem — PropertyStayPolicy fixture v0.98
-- Synthetic/configuration fixture for pre-freeze validation.
-- Times are reference assumptions pending operational discovery confirmation.

insert into property_stay_policy (
  id, organization_id, property_id, version_no, valid_from, valid_to,
  default_checkin_time, default_checkout_time, readiness_buffer, overnight_anchor_time, active
) values (
  '00000000-0000-7000-8000-000000000711',
  '00000000-0000-7000-8000-000000000001',
  '00000000-0000-7000-8000-000000000010',
  1,
  '2024-01-01',
  null,
  time '15:00',
  time '11:00',
  interval '30 minutes',
  time '03:00',
  true
);

-- IMPORTANT:
-- 15:00 / 11:00 / 03:00 are reference fixtures, not asserted production facts.
-- Discovery must confirm the actual operational policy before PROD migration.
