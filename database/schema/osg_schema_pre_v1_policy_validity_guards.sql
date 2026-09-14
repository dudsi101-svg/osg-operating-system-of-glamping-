-- OSG pre-v1 versioned policy validity guards
-- PRE-FREEZE / DEV candidate.

-- PropertyStayPolicy: exactly one active policy may cover a Property date.
alter table property_stay_policy
  add constraint ex_property_stay_policy_no_overlap
  exclude using gist (
    organization_id with =,
    property_id with =,
    daterange(valid_from,coalesce(valid_to+1,'infinity'::date),'[)') with &&
  ) where (active=true);

-- Basic lifecycle consistency.
alter table property_stay_policy
  add constraint chk_property_stay_policy_dates
  check (valid_to is null or valid_to >= valid_from);

-- NOTE:
-- A future policy revision must end/supersede the prior active range rather than
-- overlap it. Historical records remain reproducible by date/version.
