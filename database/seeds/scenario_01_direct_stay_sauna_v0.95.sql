-- OSG Scenario 01 v0.95 — Direct Forest stay + Sauna
-- Synthetic test data. Requires master seed v0.95.

begin;

-- Synthetic guest
insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000000801','00000000-0000-7000-8000-000000000001','PERSON','Gość Testowy A',true);

insert into guest_profile (id,organization_id,party_id,preferred_language,crm_status,first_seen_at,last_seen_at)
values ('00000000-0000-7000-8000-000000000802','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000801','pl','ACTIVE','2026-09-01T10:00:00+02','2026-09-23T10:45:00+02');

-- Reservation / commercial snapshot
insert into reservation (id,organization_id,property_id,channel_id,primary_guest_id,reference_code,commercial_status,booked_at,currency)
values ('00000000-0000-7000-8000-000000000810','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','00000000-0000-7000-8000-000000000802','RES-TEST-001','CONFIRMED','2026-09-01T10:00:00+02','PLN');

insert into reservation_item (id,organization_id,reservation_id,unit_type_id,assigned_unit_id,arrival_date,departure_date,adults,children,infants,pets,status)
values ('00000000-0000-7000-8000-000000000811','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000810','00000000-0000-7000-8000-000000000101','00000000-0000-7000-8000-000000000201','2026-09-20','2026-09-23',2,0,0,0,'ACTIVE');

insert into commercial_policy_snapshot (id,organization_id,reservation_id,reservation_item_id,version_no,currency,quoted_total,cancellation_policy,pricing_breakdown,deposit_terms,effective_at)
values (
'00000000-0000-7000-8000-000000000812','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000810','00000000-0000-7000-8000-000000000811',1,'PLN',1850,
'{"type":"REFERENCE","refundable_until_days":7}',
'{"accommodation":1850,"nights":3}',
'{"required":false}',
'2026-09-01T10:00:00+02');

-- Actual Stay
insert into stay (id,organization_id,reservation_item_id,primary_guest_id,status,actual_checkin_at,actual_checkout_at,guest_count_actual)
values ('00000000-0000-7000-8000-000000000813','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000811','00000000-0000-7000-8000-000000000802','CHECKED_OUT','2026-09-20T15:20:00+02','2026-09-23T10:45:00+02',2);

insert into stay_segment (id,organization_id,stay_id,unit_id,start_at,end_at,status,reason)
values ('00000000-0000-7000-8000-000000000814','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000813','00000000-0000-7000-8000-000000000201','2026-09-20T15:20:00+02','2026-09-23T10:45:00+02','ACTIVE','Normal stay');

-- Folio / accommodation charge
insert into folio (id,organization_id,reservation_id,stay_id,currency,status,opened_at,closed_at)
values ('00000000-0000-7000-8000-000000000820','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000810','00000000-0000-7000-8000-000000000813','PLN','CLOSED','2026-09-01T10:00:00+02','2026-09-23T10:50:00+02');

insert into charge (id,organization_id,folio_id,charge_type,description,quantity,unit_price,gross_amount,recognized_at,status) values
('00000000-0000-7000-8000-000000000821','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000820','ACCOMMODATION','Forest — 3 noce',3,616.6667,1850,'2026-09-23T10:45:00+02','RECOGNIZED');

-- Sauna upsell
insert into service_booking (id,organization_id,property_id,service_id,stay_id,reservation_id,guest_profile_id,requested_start_at,requested_end_at,status)
values ('00000000-0000-7000-8000-000000000830','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000401','00000000-0000-7000-8000-000000000813','00000000-0000-7000-8000-000000000810','00000000-0000-7000-8000-000000000802','2026-09-21T18:00:00+02','2026-09-21T19:30:00+02','COMPLETED');

insert into resource_reservation (id,organization_id,resource_id,service_booking_id,start_at,end_at,effective_start_at,effective_end_at,capacity_used,exclusive_booking,status)
values ('00000000-0000-7000-8000-000000000831','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000301','00000000-0000-7000-8000-000000000830','2026-09-21T18:00:00+02','2026-09-21T19:30:00+02','2026-09-21T17:30:00+02','2026-09-21T19:45:00+02',2,true,'COMPLETED');

insert into service_execution (id,organization_id,service_booking_id,actual_start_at,actual_end_at,status)
values ('00000000-0000-7000-8000-000000000832','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000830','2026-09-21T18:05:00+02','2026-09-21T19:32:00+02','COMPLETED');

insert into charge (id,organization_id,folio_id,charge_type,description,quantity,unit_price,gross_amount,recognized_at,status)
values ('00000000-0000-7000-8000-000000000822','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000820','SERVICE','Sauna 90 min',1,120,120,'2026-09-21T19:32:00+02','RECOGNIZED');

-- Guest pays total 1970 PLN directly.
insert into payment (id,organization_id,folio_id,payer_party_id,method,provider,amount,currency,status,paid_at,external_reference)
values ('00000000-0000-7000-8000-000000000823','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000820','00000000-0000-7000-8000-000000000801','BANK_TRANSFER','REFERENCE',1970,'PLN','CONFIRMED','2026-09-19T12:00:00+02','PAY-TEST-001');

insert into payment_allocation (id,organization_id,payment_id,charge_id,amount) values
('00000000-0000-7000-8000-000000000824','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000823','00000000-0000-7000-8000-000000000821',1850),
('00000000-0000-7000-8000-000000000825','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000823','00000000-0000-7000-8000-000000000822',120);

select osg_assert_payment_not_overallocated('00000000-0000-7000-8000-000000000823');

insert into cash_movement (id,organization_id,to_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000000826','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000601',1970,'PLN','2026-09-19T12:00:00+02','BANK-TEST-001','VERIFIED');

-- Economic revenue facts
insert into economic_event (id,organization_id,property_id,event_type,economic_date,amount,currency,source_charge_id,status) values
('00000000-0000-7000-8000-000000000850','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','REVENUE','2026-09-23',1850,'PLN','00000000-0000-7000-8000-000000000821','DRAFT'),
('00000000-0000-7000-8000-000000000851','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','REVENUE','2026-09-21',120,'PLN','00000000-0000-7000-8000-000000000822','DRAFT');

insert into allocation (id,organization_id,economic_event_id,amount,property_id,unit_id,stay_id,allocation_type,classification,confidence,allocation_method,rationale) values
('00000000-0000-7000-8000-000000000852','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000850',1850,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000201','00000000-0000-7000-8000-000000000813','DIRECT','REVENUE','VERIFIED','SOURCE_CHARGE','Accommodation charge'),
('00000000-0000-7000-8000-000000000853','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000851',120,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000201','00000000-0000-7000-8000-000000000813','DIRECT','REVENUE','VERIFIED','SOURCE_CHARGE','Sauna upsell');

update economic_event set status='POSTED',posted_at=now() where id in ('00000000-0000-7000-8000-000000000850','00000000-0000-7000-8000-000000000851');
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000000850');
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000000851');

-- Checkout creates completed reference turnover.
insert into turnover (id,organization_id,property_id,unit_id,previous_stay_id,available_from,ready_deadline,status,priority,completed_at)
values ('00000000-0000-7000-8000-000000000840','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000201','00000000-0000-7000-8000-000000000813','2026-09-23T10:45:00+02','2026-09-23T14:30:00+02','READY','NORMAL','2026-09-23T13:10:00+02');

commit;
