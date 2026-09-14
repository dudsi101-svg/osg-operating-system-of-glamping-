-- OSG Scenario 07 v0.96 — prepayment before stay, cancellation, full refund
-- Synthetic reference data. Requires master seed + v0.95 schema.

begin;

insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000001401','00000000-0000-7000-8000-000000000001','PERSON','Gość Testowy D',true);

insert into guest_profile (id,organization_id,party_id,preferred_language,crm_status)
values ('00000000-0000-7000-8000-000000001402','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001401','pl','ACTIVE');

insert into reservation (id,organization_id,property_id,channel_id,primary_guest_id,reference_code,commercial_status,booked_at,currency)
values ('00000000-0000-7000-8000-000000001410','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','00000000-0000-7000-8000-000000001402','RES-REFUND-001','CONFIRMED','2026-09-10T12:00:00+02','PLN');

insert into reservation_item (id,organization_id,reservation_id,unit_type_id,assigned_unit_id,arrival_date,departure_date,adults,status)
values ('00000000-0000-7000-8000-000000001411','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001410','00000000-0000-7000-8000-000000000102','00000000-0000-7000-8000-000000000202','2026-10-20','2026-10-22',2,'ACTIVE');

insert into commercial_policy_snapshot (id,organization_id,reservation_id,reservation_item_id,version_no,currency,quoted_total,cancellation_policy,pricing_breakdown,deposit_terms,effective_at)
values ('00000000-0000-7000-8000-000000001412','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001410','00000000-0000-7000-8000-000000001411',1,'PLN',1000,'{"full_refund_until":"2026-10-10T23:59:59+02:00"}','{"accommodation":1000,"nights":2}','{"prepayment":1000}','2026-09-10T12:00:00+02');

insert into folio (id,organization_id,reservation_id,currency,status,opened_at)
values ('00000000-0000-7000-8000-000000001420','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001410','PLN','OPEN','2026-09-10T12:00:00+02');

-- Accommodation is commercially expected but not recognized as revenue yet.
insert into charge (id,organization_id,folio_id,charge_type,description,quantity,unit_price,gross_amount,status)
values ('00000000-0000-7000-8000-000000001421','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001420','ACCOMMODATION','Boho — 2 noce',2,500,1000,'POSTED');

-- Full prepayment arrives before the stay.
insert into payment (id,organization_id,folio_id,payer_party_id,method,provider,amount,currency,status,paid_at,external_reference)
values ('00000000-0000-7000-8000-000000001422','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001420','00000000-0000-7000-8000-000000001401','BANK_TRANSFER','REFERENCE',1000,'PLN','CONFIRMED','2026-09-10T12:05:00+02','PREPAY-TEST-001');

insert into payment_allocation (id,organization_id,payment_id,charge_id,amount)
values ('00000000-0000-7000-8000-000000001423','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001422','00000000-0000-7000-8000-000000001421',1000);
select osg_assert_payment_not_overallocated('00000000-0000-7000-8000-000000001422');

insert into cash_movement (id,organization_id,to_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000001424','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000601',1000,'PLN','2026-09-10T12:05:00+02','BANK-PREPAY-TEST-001','VERIFIED');

-- Reservation is cancelled while full-refund policy is still valid.
update reservation set commercial_status='CANCELLED',updated_at='2026-10-01T10:00:00+02' where id='00000000-0000-7000-8000-000000001410';
update reservation_item set status='CANCELLED' where id='00000000-0000-7000-8000-000000001411';

insert into refund (id,organization_id,payment_id,amount,currency,status,refunded_at,external_reference,reason)
values ('00000000-0000-7000-8000-000000001425','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001422',1000,'PLN','CONFIRMED','2026-10-01T10:10:00+02','REFUND-TEST-001','Cancellation within full-refund window');

update payment set status='REFUNDED' where id='00000000-0000-7000-8000-000000001422';

insert into cash_movement (id,organization_id,from_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000001426','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000601',1000,'PLN','2026-10-01T10:10:00+02','BANK-REFUND-TEST-001','VERIFIED');

-- Because the stay never happened and no accommodation revenue was recognized,
-- the cash refund is NOT modeled as a second operating cost/revenue reversal here.
-- It closes the prepayment liability/commerce flow.

insert into reconciliation_link (id,organization_id,cash_movement_id,payment_id,match_status,matched_amount,confidence,rationale)
values ('00000000-0000-7000-8000-000000001427','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001424','00000000-0000-7000-8000-000000001422','MATCHED',1000,'VERIFIED','Prepayment received');

insert into reconciliation_link (id,organization_id,cash_movement_id,refund_id,match_status,matched_amount,confidence,rationale)
values ('00000000-0000-7000-8000-000000001428','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001426','00000000-0000-7000-8000-000000001425','MATCHED',1000,'VERIFIED','Full refund paid');

commit;

-- Expected:
-- Cash in = 1000, cash out = 1000.
-- Recognized accommodation revenue = 0.
-- No Stay exists.
-- Refund preserves original Payment history.
-- Current cancellation policy changes must not affect this snapshot.
