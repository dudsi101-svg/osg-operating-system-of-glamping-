-- OSG Scenario 02 v0.95 — Booking.com gross revenue / commission / net payout
-- Synthetic test data. Requires master seed + schema v0.95.

begin;

insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000000901','00000000-0000-7000-8000-000000000001','PERSON','Gość Testowy B',true);

insert into guest_profile (id,organization_id,party_id,preferred_language,crm_status)
values ('00000000-0000-7000-8000-000000000902','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000901','pl','ACTIVE');

insert into reservation (id,organization_id,property_id,channel_id,primary_guest_id,reference_code,commercial_status,booked_at,currency,source_created_at)
values ('00000000-0000-7000-8000-000000000910','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000352','00000000-0000-7000-8000-000000000902','RES-OTA-001','CONFIRMED','2026-09-05T20:00:00+02','PLN','2026-09-05T20:00:00+02');

insert into reservation_item (id,organization_id,reservation_id,unit_type_id,assigned_unit_id,arrival_date,departure_date,adults,status)
values ('00000000-0000-7000-8000-000000000911','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000910','00000000-0000-7000-8000-000000000105','00000000-0000-7000-8000-000000000205','2026-09-25','2026-09-28',2,'ACTIVE');

insert into commercial_policy_snapshot (id,organization_id,reservation_id,reservation_item_id,version_no,currency,quoted_total,cancellation_policy,pricing_breakdown,deposit_terms,source_reference,effective_at)
values ('00000000-0000-7000-8000-000000000912','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000910','00000000-0000-7000-8000-000000000911',1,'PLN',2000,'{"type":"OTA_REFERENCE"}','{"accommodation":2000,"nights":3,"expected_commission":300}','{"provider_collects":true}','BOOKING-REF-001','2026-09-05T20:00:00+02');

insert into stay (id,organization_id,reservation_item_id,primary_guest_id,status,actual_checkin_at,actual_checkout_at,guest_count_actual)
values ('00000000-0000-7000-8000-000000000913','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000911','00000000-0000-7000-8000-000000000902','CHECKED_OUT','2026-09-25T16:00:00+02','2026-09-28T10:30:00+02',2);

insert into stay_segment (id,organization_id,stay_id,unit_id,start_at,end_at,status,reason)
values ('00000000-0000-7000-8000-000000000914','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000913','00000000-0000-7000-8000-000000000205','2026-09-25T16:00:00+02','2026-09-28T10:30:00+02','ACTIVE','OTA stay');

insert into folio (id,organization_id,reservation_id,stay_id,currency,status,opened_at,closed_at)
values ('00000000-0000-7000-8000-000000000920','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000910','00000000-0000-7000-8000-000000000913','PLN','CLOSED','2026-09-05T20:00:00+02','2026-09-28T10:35:00+02');

insert into charge (id,organization_id,folio_id,charge_type,description,quantity,unit_price,gross_amount,recognized_at,status)
values ('00000000-0000-7000-8000-000000000921','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000920','ACCOMMODATION','Aura — Booking.com — 3 noce',3,666.6667,2000,'2026-09-28T10:30:00+02','RECOGNIZED');

-- Guest/OTA commerce payment is gross 2000, not bank payout 1700.
insert into payment (id,organization_id,folio_id,payer_party_id,method,provider,amount,currency,status,paid_at,external_reference)
values ('00000000-0000-7000-8000-000000000922','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000920','00000000-0000-7000-8000-000000000023','OTA_COLLECT','BOOKING',2000,'PLN','CONFIRMED','2026-09-05T20:00:00+02','BOOKING-PAY-001');

insert into payment_allocation (id,organization_id,payment_id,charge_id,amount)
values ('00000000-0000-7000-8000-000000000923','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000922','00000000-0000-7000-8000-000000000921',2000);
select osg_assert_payment_not_overallocated('00000000-0000-7000-8000-000000000922');

-- Provider statement modeled through logical OTA clearing.
insert into cash_movement (id,organization_id,to_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000000926','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000603',2000,'PLN','2026-09-05T20:00:00+02','BOOKING-CLEAR-IN-001','VERIFIED');

insert into cash_movement (id,organization_id,from_money_account_id,to_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000000927','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000603','00000000-0000-7000-8000-000000000601',1700,'PLN','2026-09-29T12:00:00+02','BOOKING-PAYOUT-001','VERIFIED');

insert into cash_movement (id,organization_id,from_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000000928','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000603',300,'PLN','2026-09-29T12:00:00+02','BOOKING-COMMISSION-WITHHELD-001','VERIFIED');

-- Economic revenue 2000 and OTA cost 300 are independent facts.
insert into economic_event (id,organization_id,property_id,event_type,economic_date,amount,currency,source_charge_id,status) values
('00000000-0000-7000-8000-000000000930','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','REVENUE','2026-09-28',2000,'PLN','00000000-0000-7000-8000-000000000921','DRAFT'),
('00000000-0000-7000-8000-000000000931','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','OTA_COMMISSION','2026-09-28',300,'PLN',null,'DRAFT');

insert into allocation (id,organization_id,economic_event_id,amount,property_id,unit_id,stay_id,channel_id,economic_bearer_party_id,allocation_type,classification,confidence,allocation_method,rationale) values
('00000000-0000-7000-8000-000000000932','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000930',2000,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000205','00000000-0000-7000-8000-000000000913','00000000-0000-7000-8000-000000000352',null,'DIRECT','REVENUE','VERIFIED','SOURCE_CHARGE','Gross accommodation revenue'),
('00000000-0000-7000-8000-000000000933','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000931',300,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000205','00000000-0000-7000-8000-000000000913','00000000-0000-7000-8000-000000000352',null,'DIRECT','OPEX','VERIFIED','OTA_STATEMENT','Booking commission');

update economic_event set status='POSTED',posted_at=now() where id in ('00000000-0000-7000-8000-000000000930','00000000-0000-7000-8000-000000000931');
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000000930');
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000000931');

-- Reconciliation evidence.
insert into reconciliation_link (id,organization_id,cash_movement_id,payment_id,match_status,matched_amount,confidence,rationale)
values ('00000000-0000-7000-8000-000000000940','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000926','00000000-0000-7000-8000-000000000922','MATCHED',2000,'VERIFIED','OTA gross collection matches commerce payment');

insert into reconciliation_link (id,organization_id,cash_movement_id,economic_event_id,match_status,matched_amount,confidence,rationale)
values ('00000000-0000-7000-8000-000000000941','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000928','00000000-0000-7000-8000-000000000931','MATCHED',300,'VERIFIED','Withheld commission matches OTA commission event');

commit;

-- Expected business outputs:
-- Gross stay revenue = 2000
-- OTA cost = 300
-- Net cash payout to bank = 1700
-- Contribution before other direct costs = 1700
-- Revenue MUST NOT be reported as 1700 merely because bank received 1700.
