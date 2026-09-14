-- OSG Guest semantic layer v0.1
-- Requires guest identity resolution schema.

create or replace view osg_guest_profile_canonical_map as
select
  gp.organization_id,
  gp.id as source_guest_profile_id,
  osg_canonical_guest_profile(gp.organization_id,gp.id) as canonical_guest_profile_id
from guest_profile gp;

-- Completed Stay facts resolved to canonical primary guest.
create or replace view osg_completed_stay_guest_fact as
select
  s.organization_id,
  r.property_id,
  s.id as stay_id,
  s.actual_checkout_at,
  gpmap.canonical_guest_profile_id
from stay s
join reservation_item ri
  on ri.organization_id=s.organization_id and ri.id=s.reservation_item_id
join reservation r
  on r.organization_id=ri.organization_id and r.id=ri.reservation_id
join osg_guest_profile_canonical_map gpmap
  on gpmap.organization_id=s.organization_id
 and gpmap.source_guest_profile_id=s.primary_guest_id
where s.status='CHECKED_OUT'
  and s.actual_checkout_at is not null
  and s.primary_guest_id is not null;

create or replace function osg_repeat_guest_rate(
  p_property_id uuid,
  p_from_date date,
  p_to_date date
)
returns table (
  property_id uuid,
  eligible_completed_stays bigint,
  returning_guest_stays bigint,
  repeat_guest_rate numeric
)
language sql
stable
as $$
with property_ctx as (
  select timezone from property where id=p_property_id
), target_stays as (
  select f.*
  from osg_completed_stay_guest_fact f
  cross join property_ctx p
  where f.property_id=p_property_id
    and (f.actual_checkout_at at time zone p.timezone)::date between p_from_date and p_to_date
), classified as (
  select
    ts.*,
    exists (
      select 1
      from osg_completed_stay_guest_fact prev
      where prev.organization_id=ts.organization_id
        and prev.canonical_guest_profile_id=ts.canonical_guest_profile_id
        and prev.actual_checkout_at < ts.actual_checkout_at
        and prev.stay_id <> ts.stay_id
    ) as is_returning
  from target_stays ts
)
select
  p_property_id,
  count(*),
  count(*) filter (where is_returning),
  count(*) filter (where is_returning)::numeric / nullif(count(*),0)
from classified;
$$;

-- Repeat Guest is identity-sensitive. If profile resolution quality is low,
-- metric explainability should disclose unresolved/match-candidate counts.
