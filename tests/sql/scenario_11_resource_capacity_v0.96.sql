-- OSG Scenario/Test 11 v0.96 — capacity Resource exact fill and overflow
-- Requires master seed + resource_capacity_guard_v0.1.sql.
-- Single-session arithmetic proof; real P0 concurrency proof still requires two DB connections.

begin;

-- Room capacity in master seed = 20.
insert into resource_reservation (
  id,organization_id,resource_id,start_at,end_at,effective_start_at,effective_end_at,
  capacity_used,exclusive_booking,status
) values (
'00000000-0000-7000-8000-000000001801','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000305',
'2026-10-15T10:00:00+02','2026-10-15T12:00:00+02','2026-10-15T09:30:00+02','2026-10-15T12:30:00+02',18,false,'CONFIRMED');

-- Exact fill: 18 existing + 2 requested = 20 => allowed.
select osg_assert_resource_capacity(
  '00000000-0000-7000-8000-000000000305',
  '2026-10-15T09:30:00+02','2026-10-15T12:30:00+02',2,null,'2026-10-01T00:00:00+02');

insert into resource_reservation (
  id,organization_id,resource_id,start_at,end_at,effective_start_at,effective_end_at,
  capacity_used,exclusive_booking,status
) values (
'00000000-0000-7000-8000-000000001802','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000305',
'2026-10-15T10:00:00+02','2026-10-15T12:00:00+02','2026-10-15T09:30:00+02','2026-10-15T12:30:00+02',2,false,'CONFIRMED');

-- Overflow attempt: 20 already used + 1 requested. The scenario catches the expected error.
do $$
begin
  perform osg_assert_resource_capacity(
    '00000000-0000-7000-8000-000000000305',
    '2026-10-15T09:30:00+02','2026-10-15T12:30:00+02',1,null,'2026-10-01T00:00:00+02');
  raise exception 'OSG_TEST_FAILED expected RESOURCE_CAPACITY_EXCEEDED';
exception
  when others then
    if position('OSG_RESOURCE_CAPACITY_EXCEEDED' in sqlerrm) = 0 then
      raise;
    end if;
end $$;

-- Non-overlapping time must remain allowed.
select osg_assert_resource_capacity(
  '00000000-0000-7000-8000-000000000305',
  '2026-10-15T12:30:00+02','2026-10-15T14:30:00+02',20,null,'2026-10-01T00:00:00+02');

rollback;

-- Expected:
-- exact fill accepted, overflow rejected, adjacent [start,end) window accepted.
-- Separate Issue #2 still requires true concurrent two-connection proof.
