-- OSG Scenario 06 v0.95 — incident in Forest causes relocation to Ostoja
-- Synthetic test data. Requires master seed + schema v0.95.

begin;

insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000001301','00000000-0000-7000-8000-000000000001','PERSON','Gość Testowy C',true);

insert into guest_profile (id,organization_id,party_id,preferred_language,crm_status)
values ('00000000-0000-7000-8000-000000001302','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001301','pl','ACTIVE');

insert into reservation (id,organization_id,property_id,channel_id,primary_guest_id,reference_code,commercial_status,booked_at,currency)
values ('00000000-0000-7000-8000-000000001310','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','00000000-0000-7000-8000-000000001302','RES-RELOC-001','CONFIRMED','2026-09-15T12:00:00+02','PLN');

insert into reservation_item (id,organization_id,reservation_id,unit_type_id,assigned_unit_id,arrival_date,departure_date,adults,status)
values ('00000000-0000-7000-8000-000000001311','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001310','00000000-0000-7000-8000-000000000101','00000000-0000-7000-8000-000000000201','2026-10-02','2026-10-05',2,'ACTIVE');

insert into stay (id,organization_id,reservation_item_id,primary_guest_id,status,actual_checkin_at,actual_checkout_at,guest_count_actual)
values ('00000000-0000-7000-8000-000000001312','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001311','00000000-0000-7000-8000-000000001302','CHECKED_OUT','2026-10-02T15:00:00+02','2026-10-05T10:30:00+02',2);

-- Actual stay starts in Forest.
insert into stay_segment (id,organization_id,stay_id,unit_id,start_at,end_at,status,reason)
values ('00000000-0000-7000-8000-000000001313','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001312','00000000-0000-7000-8000-000000000201','2026-10-02T15:00:00+02','2026-10-03T12:00:00+02','ACTIVE','Original assigned unit');

-- Reference HVAC/heating asset in Forest.
insert into asset (id,organization_id,property_id,unit_id,name,asset_type,lifecycle_status,installed_at)
values ('00000000-0000-7000-8000-000000001320','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000201','Forest climate system','HVAC','FAILED','2024-01-01');

insert into incident (id,organization_id,property_id,unit_id,asset_id,severity,status,title,description,guest_impact,safety_related,reported_at,resolved_at)
values ('00000000-0000-7000-8000-000000001321','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000201','00000000-0000-7000-8000-000000001320','HIGH','RESOLVED','Forest heating failure','Heating failed during occupied stay',true,false,'2026-10-03T10:00:00+02','2026-10-04T14:00:00+02');

-- Forest becomes non-sellable. Existing stay is NOT silently deleted/cancelled.
insert into availability_block (id,organization_id,property_id,unit_id,start_at,end_at,reason_type,reason_text,source_incident_id,status,created_at,ended_at)
values ('00000000-0000-7000-8000-000000001322','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000201','2026-10-03T10:00:00+02','2026-10-06T15:00:00+02','MAINTENANCE','Heating failure','00000000-0000-7000-8000-000000001321','ENDED','2026-10-03T10:05:00+02','2026-10-04T15:00:00+02');

insert into conflict_case (id,organization_id,property_id,availability_block_id,reservation_item_id,stay_id,severity,reason,status,resolution_type,resolved_at)
values ('00000000-0000-7000-8000-000000001323','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000001322','00000000-0000-7000-8000-000000001311','00000000-0000-7000-8000-000000001312','HIGH','Availability block overlaps active stay','RESOLVED','SPLIT_STAY','2026-10-03T12:00:00+02');

-- Same Stay continues in Ostoja. ReservationItem remains historical commercial booking for Forest.
insert into stay_segment (id,organization_id,stay_id,unit_id,start_at,end_at,status,reason)
values ('00000000-0000-7000-8000-000000001314','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001312','00000000-0000-7000-8000-000000000204','2026-10-03T12:00:00+02','2026-10-05T10:30:00+02','ACTIVE','Relocation due to Forest incident');

-- Repair task preserves operational history.
insert into task (id,organization_id,property_id,incident_id,task_type,title,priority,status,due_at,started_at,completed_at)
values ('00000000-0000-7000-8000-000000001324','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000001321','MAINTENANCE','Repair Forest heating','HIGH','DONE','2026-10-04T18:00:00+02','2026-10-03T13:00:00+02','2026-10-04T14:00:00+02');

commit;

-- Expected:
-- Reservation says Forest was booked.
-- Stay history says Forest then Ostoja.
-- Incident/block remains linked to Forest.
-- Historical occupancy can attribute actual occupied time to both units.
-- No update rewrites Forest into Ostoja on the original reservation.
