-- OSG pre-v1 overnight attribution anchor
-- PRE-FREEZE / DEV candidate.

alter table property_stay_policy
  add column overnight_anchor_time time not null default time '03:00';

comment on column property_stay_policy.overnight_anchor_time is
  'Local time on D+1 used to attribute commercial accommodation night D to the Unit/StaySegment that hosted the overnight service.';

-- The anchor is versioned with PropertyStayPolicy so historical relocation attribution
-- remains reproducible after operating-policy changes.
