-- OSG Folio invariant test scaffold pre-v1
-- Run against clean DEV schema + semantic folio + master/period fixtures.
-- Uses transactions/savepoints so negative cases do not pollute DB.

-- Test setup IDs are synthetic and isolated.

-- ===============================================================
-- NEGATIVE 1: Payment currency != Folio currency must fail
-- Expected: OSG_FOLIO_CURRENCY_MISMATCH
-- ===============================================================
begin;
insert into reservation (
  id,organization_id,property_id,channel_id,reference_code,commercial_status,booked_at,currency
) values (
'00000000-0000-7000-8000-000000009001','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','TEST-FOLIO-1','CONFIRMED',now(),'PLN');
insert into folio (id,organization_id,reservation_id,currency,status)
values ('00000000-0000-7000-8000-000000009002','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009001','PLN','OPEN');

savepoint before_bad_payment;
-- Must fail:
-- insert into payment (id,organization_id,folio_id,method,amount,currency,status)
-- values ('00000000-0000-7000-8000-000000009003','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009002','CARD',100,'EUR','CONFIRMED');
rollback to savepoint before_bad_payment;
rollback;

-- ===============================================================
-- NEGATIVE 2: Refunds cannot exceed Payment
-- Expected: OSG_REFUND_EXCEEDS_PAYMENT
-- ===============================================================
begin;
insert into reservation (id,organization_id,property_id,channel_id,reference_code,commercial_status,booked_at,currency)
values ('00000000-0000-7000-8000-000000009011','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','TEST-FOLIO-2','CONFIRMED',now(),'PLN');
insert into folio (id,organization_id,reservation_id,currency,status)
values ('00000000-0000-7000-8000-000000009012','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009011','PLN','OPEN');
insert into payment (id,organization_id,folio_id,method,amount,currency,status)
values ('00000000-0000-7000-8000-000000009013','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009012','CARD',100,'PLN','CONFIRMED');
insert into refund (id,organization_id,payment_id,amount,currency,status)
values ('00000000-0000-7000-8000-000000009014','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009013',60,'PLN','CONFIRMED');

savepoint before_over_refund;
-- Must fail because total would become 110 > 100:
-- insert into refund (id,organization_id,payment_id,amount,currency,status)
-- values ('00000000-0000-7000-8000-000000009015','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009013',50,'PLN','CONFIRMED');
rollback to savepoint before_over_refund;
rollback;

-- ===============================================================
-- NEGATIVE 3: cannot close Folio with non-zero balance
-- Expected: OSG_FOLIO_BALANCE_NOT_ZERO
-- ===============================================================
begin;
insert into reservation (id,organization_id,property_id,channel_id,reference_code,commercial_status,booked_at,currency)
values ('00000000-0000-7000-8000-000000009021','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','TEST-FOLIO-3','CONFIRMED',now(),'PLN');
insert into folio (id,organization_id,reservation_id,currency,status)
values ('00000000-0000-7000-8000-000000009022','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009021','PLN','OPEN');
insert into charge (id,organization_id,folio_id,charge_type,description,quantity,unit_price,gross_amount,status)
values ('00000000-0000-7000-8000-000000009023','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009022','FEE','Test fee',1,300,300,'POSTED');

savepoint before_bad_close;
-- Must fail:
-- update folio set status='CLOSED' where id='00000000-0000-7000-8000-000000009022';
rollback to savepoint before_bad_close;
rollback;

-- ===============================================================
-- POSITIVE: charge + payment settles and Folio closes
-- ===============================================================
begin;
insert into reservation (id,organization_id,property_id,channel_id,reference_code,commercial_status,booked_at,currency)
values ('00000000-0000-7000-8000-000000009031','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','TEST-FOLIO-4','CONFIRMED',now(),'PLN');
insert into folio (id,organization_id,reservation_id,currency,status)
values ('00000000-0000-7000-8000-000000009032','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009031','PLN','OPEN');
insert into charge (id,organization_id,folio_id,charge_type,description,quantity,unit_price,gross_amount,status)
values ('00000000-0000-7000-8000-000000009033','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009032','FEE','Test fee',1,300,300,'POSTED');
insert into payment (id,organization_id,folio_id,method,amount,currency,status)
values ('00000000-0000-7000-8000-000000009034','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009032','CARD',300,'PLN','CONFIRMED');
update folio set status='CLOSED' where id='00000000-0000-7000-8000-000000009032';
select * from osg_folio_balance where folio_id='00000000-0000-7000-8000-000000009032';
rollback;

-- Negative commands are commented because plain psql would abort on expected errors.
-- CI implementation should execute them with pgTAP or test framework exception assertions.
