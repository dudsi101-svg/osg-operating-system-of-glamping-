-- OSG Scenario 12 v0.96 — Turnover not ready before next arrival
-- Synthetic test data. Requires master seed + v0.95 core/extensions.

begin;

-- Operator role for role-targeted notification.
insert into role (id,organization_id,code,name,active)
values ('00000000-0000-7000-8000-000000001901','00000000-0000-7000-8000-000000000001','OPERATOR','Operator',true);

-- Synthetic next-arrival guest/reservation in Boho.
insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000001902','00000000-0000-7000-8000-000000000001','PERSON','Gość Next Arrival Test',true);

insert into guest_profile (id,organization_id,party_id,preferred_language,crm_status)
values ('00000000-0000-7000-8000-000000001903','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001902','pl','ACTIVE');

insert into reservation (id,organization_id,property_id,channel_id,primary_guest_id,reference_code,commercial_status,booked_at,currency)
values ('00000000-0000-7000-8000-000000001904','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','00000000-0000-7000-8000-000000001903','RES-NEXT-001','CONFIRMED','2026-10-01T10:00:00+02','PLN');

insert into reservation_item (id,organization_id,reservation_id,unit_type_id,assigned_unit_id,arrival_date,departure_date,adults,status)
values ('00000000-0000-7000-8000-000000001905','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001904','00000000-0000-7000-8000-000000000102','00000000-0000-7000-8000-000000000202','2026-10-18','2026-10-20',2,'ACTIVE');

insert into stay (id,organization_id,reservation_item_id,primary_guest_id,status,guest_count_actual)
values ('00000000-0000-7000-8000-000000001906','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001905','00000000-0000-7000-8000-000000001903','EXPECTED',null);

-- At 14:05 the unit is still PENDING, deadline READY is 14:30, arrival expected ~15:00.
insert into turnover (id,organization_id,property_id,unit_id,next_stay_id,available_from,ready_deadline,status,priority)
values ('00000000-0000-7000-8000-000000001910','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000202','00000000-0000-7000-8000-000000001906','2026-10-18T11:00:00+02','2026-10-18T14:30:00+02','PENDING','HIGH');

insert into task (id,organization_id,property_id,turnover_id,task_type,title,priority,status,due_at)
values ('00000000-0000-7000-8000-000000001911','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000001910','HOUSEKEEPING','Prepare Boho for next arrival','HIGH','OPEN','2026-10-18T14:00:00+02');

-- Scheduler heartbeat is modeled as a DomainEvent so the time-based automation
-- remains observable/versionable like other automation triggers.
insert into domain_event (id,organization_id,property_id,event_type,event_version,aggregate_type,aggregate_id,occurred_at,actor_type,payload)
values ('00000000-0000-7000-8000-000000001920','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','Scheduler.Tick',1,'Property','00000000-0000-7000-8000-000000000010','2026-10-18T14:05:00+02','SYSTEM','{"purpose":"operational-risk-scan"}');

insert into automation_rule (id,organization_id,property_id,code,version_no,trigger_event_type,conditions,actions,active)
values (
'00000000-0000-7000-8000-000000001921','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','TURNOVER_AT_RISK',1,'Scheduler.Tick',
'{"turnover_status_not":"READY","minutes_to_ready_deadline_lte":30,"next_stay_exists":true}',
'{"notify_role":"OPERATOR","severity":"ACTION_REQUIRED"}',true);

insert into automation_execution (id,organization_id,automation_rule_id,trigger_event_id,action_key,status,started_at,completed_at,retry_count,result)
values ('00000000-0000-7000-8000-000000001922','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001921','00000000-0000-7000-8000-000000001920','notify-turnover:00000000-0000-7000-8000-000000001910','SUCCEEDED','2026-10-18T14:05:01+02','2026-10-18T14:05:01+02',0,'{"turnover_id":"00000000-0000-7000-8000-000000001910"}');

insert into notification (id,organization_id,property_id,target_role_id,severity,category,title,body,subject_type,subject_id,deduplication_key,created_at)
values (
'00000000-0000-7000-8000-000000001923','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000001901','ACTION_REQUIRED','TURNOVER_RISK','Boho zagrożone przed przyjazdem','Turnover nadal PENDING; READY deadline za 25 minut.','Turnover','00000000-0000-7000-8000-000000001910','turnover-risk:00000000-0000-7000-8000-000000001910:2026-10-18T14:05', '2026-10-18T14:05:01+02');

commit;

-- Expected:
-- Operations Center places Boho in AT-RISK state derived from Turnover/next Stay/deadline.
-- Notification is an effect, not the source of truth.
-- Duplicate scheduler/retry must not create duplicate action because AutomationExecution
-- and Notification both have deduplication keys/uniqueness guards.
