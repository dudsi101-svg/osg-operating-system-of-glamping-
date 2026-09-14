-- OSG Data Quality — Commercial Accommodation Nights v0.1

create or replace view osg_dq_unresolved_commercial_night_attribution as
select
  cn.organization_id,
  cn.property_id,
  cn.stay_id,
  cn.reservation_item_id,
  cn.night_date,
  cn.anchor_at,
  cn.finality,
  'HIGH'::text as severity,
  'COMMERCIAL_NIGHT_UNIT_UNRESOLVED'::text as issue_type
from property p
cross join lateral osg_commercial_accommodation_nights(
  p.id,
  greatest(current_date-interval '90 days',date '2000-01-01')::date,
  current_date
) cn
where cn.property_id=p.id
  and cn.attribution_status='UNRESOLVED';

-- Historical batch scanner should use an explicit configured horizon rather than
-- relying on this convenience 90-day view for long-term audits.

create or replace view osg_dq_commercial_night_non_sellable_conflict as
select
  cn.organization_id,
  cn.property_id,
  cn.stay_id,
  cn.night_date,
  cn.unit_id,
  unf.sellable_capacity,
  'HIGH'::text as severity,
  'COMMERCIAL_NIGHT_ON_NON_SELLABLE_UNIT'::text as issue_type
from property p
cross join lateral osg_commercial_accommodation_nights(
  p.id,
  greatest(current_date-interval '90 days',date '2000-01-01')::date,
  current_date
) cn
join lateral osg_unit_night_facts(p.id,cn.night_date,cn.night_date) unf
  on unf.unit_id=cn.unit_id and unf.local_night_date=cn.night_date
where cn.property_id=p.id
  and cn.attribution_status='RESOLVED'
  and unf.sellable_capacity=false;

-- This condition does not automatically invalidate the commercial night.
-- The effective commercial capacity logic retains delivered nights in denominator,
-- while Operations/Data Quality investigate why the Unit was blocked.
