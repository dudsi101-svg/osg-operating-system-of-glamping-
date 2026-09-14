-- OSG Scenario 08 v0.96 — same PMS reservation event delivered repeatedly
-- Synthetic test data. Requires v0.95 core/extensions/supporting + master seed.

begin;

insert into integration (id,organization_id,property_id,provider,integration_type,status,sync_mode,credentials_reference)
values ('00000000-0000-7000-8000-000000001501','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','Reference PMS','RESERVATION_SOURCE','ACTIVE','WEBHOOK_PRIMARY','secret://reference/pms');

-- First delivery claims the external event.
insert into integration_processing_record (id,organization_id,integration_id,external_event_id,action_key,status,attempts,first_seen_at,last_attempt_at)
values ('00000000-0000-7000-8000-000000001502','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001501','evt-res-001','upsert_reservation','PROCESSING',1,'2026-09-14T14:00:00+02','2026-09-14T14:00:00+02');

insert into external_record (id,organization_id,integration_id,external_type,external_id,source_version,received_at,payload_hash,payload,processing_status)
values ('00000000-0000-7000-8000-000000001503','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001501','reservation','PMS-RES-001','v1','2026-09-14T14:00:00+02','hash-ref-001','{"status":"confirmed","arrival":"2026-11-01","departure":"2026-11-03","unit_type":"FOREST"}','MAPPED');

-- Synthetic guest and resulting domain reservation.
insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000001504','00000000-0000-7000-8000-000000000001','PERSON','Gość PMS Test',true);

insert into guest_profile (id,organization_id,party_id,preferred_language,crm_status)
values ('00000000-0000-7000-8000-000000001505','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001504','pl','ACTIVE');

insert into reservation (id,organization_id,property_id,channel_id,primary_guest_id,reference_code,commercial_status,booked_at,currency,source_created_at,source_updated_at)
values ('00000000-0000-7000-8000-000000001510','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','00000000-0000-7000-8000-000000001505','PMS-RES-001','CONFIRMED','2026-09-14T14:00:00+02','PLN','2026-09-14T14:00:00+02','2026-09-14T14:00:00+02');

insert into reservation_item (id,organization_id,reservation_id,unit_type_id,assigned_unit_id,arrival_date,departure_date,adults,status)
values ('00000000-0000-7000-8000-000000001511','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001510','00000000-0000-7000-8000-000000000101','00000000-0000-7000-8000-000000000201','2026-11-01','2026-11-03',2,'ACTIVE');

insert into external_reference (id,organization_id,integration_id,external_type,external_id,osg_entity_type,osg_entity_id)
values ('00000000-0000-7000-8000-000000001512','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001501','reservation','PMS-RES-001','Reservation','00000000-0000-7000-8000-000000001510');

update integration_processing_record
set status='SUCCEEDED', result_reference='Reservation:00000000-0000-7000-8000-000000001510', attempts=1
where id='00000000-0000-7000-8000-000000001502';

-- Simulate four repeated deliveries. The unique idempotency claim prevents new
-- processing rows/effects. ON CONFLICT models the claimant behavior.
do $$
declare
  i integer;
  inserted_count integer;
begin
  for i in 1..4 loop
    insert into integration_processing_record (
      id, organization_id, integration_id, external_event_id, action_key, status, attempts, first_seen_at, last_attempt_at
    ) values (
      ('00000000-0000-7000-8000-00000000152' || i::text)::uuid,
      '00000000-0000-7000-8000-000000000001',
      '00000000-0000-7000-8000-000000001501',
      'evt-res-001','upsert_reservation','RECEIVED',1,now(),now()
    ) on conflict (integration_id, external_event_id, action_key) do nothing;
  end loop;

  select count(*) into inserted_count
  from integration_processing_record
  where integration_id='00000000-0000-7000-8000-000000001501'
    and external_event_id='evt-res-001'
    and action_key='upsert_reservation';

  if inserted_count <> 1 then
    raise exception 'OSG_IDEMPOTENCY_PROOF_FAILED count=%', inserted_count;
  end if;
end $$;

-- Domain effect count must also remain one.
do $$
declare
  c integer;
begin
  select count(*) into c from reservation where reference_code='PMS-RES-001';
  if c <> 1 then
    raise exception 'OSG_DUPLICATE_RESERVATION_EFFECT count=%', c;
  end if;
end $$;

commit;

-- Expected:
-- 5 deliveries total, 1 integration-processing claim, 1 Reservation,
-- 1 ExternalReference, no duplicate ReservationItem/Charge/Payment effects.
