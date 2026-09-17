-- OSG P0 StaySegment temporal integrity proof — pre-v1
-- Covers Issue #1 / Suite A1-A3 from OSG_P0_Proof_Execution_Plan_v0.1.md.
-- Requires clean schema + Glamping Nad Stawem master seed.
-- Runs in one transaction and rolls back all synthetic fixtures.

begin;

-- Synthetic reservations/stays isolated from reference scenarios.
insert into reservation (
  id,organization_id,property_id,channel_id,reference_code,commercial_status,booked_at,currency
) values
('00000000-0000-7000-8000-000000009100','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','P0-STAY-A','CONFIRMED','2026-11-01T10:00:00+01','PLN'),
('00000000-0000-7000-8000-000000009110','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','P0-STAY-B','CONFIRMED','2026-11-01T10:05:00+01','PLN'),
('00000000-0000-7000-8000-000000009120','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','P0-STAY-C','CONFIRMED','2026-11-01T10:10:00+01','PLN');

insert into reservation_item (
  id,organization_id,reservation_id,unit_type_id,assigned_unit_id,arrival_date,departure_date,adults,children,infants,pets,status
) values
('00000000-0000-7000-8000-000000009101','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009100','00000000-0000-7000-8000-000000000101','00000000-0000-7000-8000-000000000201','2026-11-20','2026-11-23',2,0,0,0,'ACTIVE'),
('00000000-0000-7000-8000-000000009111','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009110','00000000-0000-7000-8000-000000000101','00000000-0000-7000-8000-000000000201','2026-11-22','2026-11-24',2,0,0,0,'ACTIVE'),
('00000000-0000-7000-8000-000000009121','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009120','00000000-0000-7000-8000-000000000101','00000000-0000-7000-8000-000000000201','2026-11-22','2026-11-24',2,0,0,0,'ACTIVE');

insert into stay (id,organization_id,reservation_item_id,status) values
('00000000-0000-7000-8000-000000009102','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009101','EXPECTED'),
('00000000-0000-7000-8000-000000009112','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009111','EXPECTED'),
('00000000-0000-7000-8000-000000009122','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009121','EXPECTED');

-- Baseline active occupancy of Forest: [2026-11-20 15:00, 2026-11-23 11:00).
insert into stay_segment (
  id,organization_id,stay_id,unit_id,start_at,end_at,status,reason
) values (
'00000000-0000-7000-8000-000000009103','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009102','00000000-0000-7000-8000-000000000201',
'2026-11-20T15:00:00+01','2026-11-23T11:00:00+01','ACTIVE','P0 baseline occupancy');

-- P0-STAY-001: overlapping ACTIVE segment must be rejected by the canonical exclusion constraint.
do $$
declare
  v_constraint text;
begin
  begin
    insert into stay_segment (
      id,organization_id,stay_id,unit_id,start_at,end_at,status,reason
    ) values (
      '00000000-0000-7000-8000-000000009113','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009112','00000000-0000-7000-8000-000000000201',
      '2026-11-22T15:00:00+01','2026-11-24T11:00:00+01','ACTIVE','P0 overlap must fail');

    raise exception 'OSG_TEST_FAILED expected STAY_SEGMENT_OVERLAP';
  exception
    when exclusion_violation then
      get stacked diagnostics v_constraint = CONSTRAINT_NAME;
      if v_constraint <> 'ex_stay_segment_no_overlap' then
        raise exception 'OSG_TEST_FAILED unexpected exclusion constraint: %', v_constraint;
      end if;
      raise notice 'OSG_ERROR_CODE=STAY_SEGMENT_OVERLAP sqlstate=23P01 constraint=%', v_constraint;
  end;
end $$;

-- P0-STAY-002: adjacent [start,end) boundary is valid.
insert into stay_segment (
  id,organization_id,stay_id,unit_id,start_at,end_at,status,reason
) values (
'00000000-0000-7000-8000-000000009114','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009112','00000000-0000-7000-8000-000000000201',
'2026-11-23T11:00:00+01','2026-11-24T11:00:00+01','ACTIVE','P0 adjacent interval must pass');

-- Remove the adjacent proof row before testing overlap semantics for CANCELLED.
delete from stay_segment where id='00000000-0000-7000-8000-000000009114';

-- P0-STAY-003: cancelled/non-active segment may overlap without blocking inventory.
insert into stay_segment (
  id,organization_id,stay_id,unit_id,start_at,end_at,status,reason
) values (
'00000000-0000-7000-8000-000000009123','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009122','00000000-0000-7000-8000-000000000201',
'2026-11-22T15:00:00+01','2026-11-24T11:00:00+01','CANCELLED','P0 cancelled overlap must pass');

-- Sanity assertions.
do $$
declare
  v_active integer;
  v_cancelled integer;
begin
  select count(*) into v_active
  from stay_segment
  where organization_id='00000000-0000-7000-8000-000000000001'
    and unit_id='00000000-0000-7000-8000-000000000201'
    and id in (
      '00000000-0000-7000-8000-000000009103',
      '00000000-0000-7000-8000-000000009113',
      '00000000-0000-7000-8000-000000009114'
    )
    and status='ACTIVE';

  select count(*) into v_cancelled
  from stay_segment
  where id='00000000-0000-7000-8000-000000009123'
    and status='CANCELLED';

  if v_active <> 1 then
    raise exception 'OSG_TEST_FAILED expected exactly one retained ACTIVE baseline segment, got %', v_active;
  end if;

  if v_cancelled <> 1 then
    raise exception 'OSG_TEST_FAILED cancelled overlap row was not accepted';
  end if;
end $$;

rollback;

-- Expected:
-- 1. overlap ACTIVE -> rejected by ex_stay_segment_no_overlap / SQLSTATE 23P01
-- 2. adjacent [start,end) -> accepted
-- 3. overlapping CANCELLED -> accepted
-- API/domain error mapping contract: ex_stay_segment_no_overlap -> STAY_SEGMENT_OVERLAP.
