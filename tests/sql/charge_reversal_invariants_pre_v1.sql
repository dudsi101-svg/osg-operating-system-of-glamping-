-- OSG Charge correction/reversal test scaffold pre-v1
-- Negative statements are commented for pgTAP/test-runner assertion conversion.

begin;

insert into reservation (id,organization_id,property_id,channel_id,reference_code,commercial_status,booked_at,currency)
values ('00000000-0000-7000-8000-000000009101','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000351','TEST-CHARGE-1','CONFIRMED',now(),'PLN');
insert into folio (id,organization_id,reservation_id,currency,status)
values ('00000000-0000-7000-8000-000000009102','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009101','PLN','OPEN');
insert into charge (id,organization_id,folio_id,charge_type,description,quantity,unit_price,gross_amount,status)
values ('00000000-0000-7000-8000-000000009103','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009102','ACCOMMODATION','Original',1,1000,1000,'POSTED');

-- NEGATIVE: final Charge material edit must fail OSG_FINAL_CHARGE_IMMUTABLE.
-- update charge set gross_amount=900 where id='00000000-0000-7000-8000-000000009103';

-- POSITIVE: partial reversal of 400.
insert into charge (id,organization_id,folio_id,charge_type,description,quantity,unit_price,gross_amount,status,reverses_charge_id)
values ('00000000-0000-7000-8000-000000009104','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009102','ACCOMMODATION','Partial reversal',1,-400,-400,'POSTED','00000000-0000-7000-8000-000000009103');

-- POSITIVE: second partial reversal of 600 reaches exactly original absolute amount.
insert into charge (id,organization_id,folio_id,charge_type,description,quantity,unit_price,gross_amount,status,reverses_charge_id)
values ('00000000-0000-7000-8000-000000009105','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000009102','ACCOMMODATION','Remaining reversal',1,-600,-600,'POSTED','00000000-0000-7000-8000-000000009103');

-- NEGATIVE: another -1 would exceed original amount.
-- insert into charge (...) values (...,-1,...,'00000000-0000-7000-8000-000000009103');
-- Expected OSG_CHARGE_OVER_REVERSED.

-- NEGATIVE: reversal with same sign must fail.
-- insert positive Charge with reverses_charge_id = original.
-- Expected OSG_CHARGE_REVERSAL_SIGN_INVALID.

-- NEGATIVE: reversal on a different Folio must fail.
-- Expected OSG_CHARGE_REVERSAL_FOLIO_MISMATCH.

select net_charges,balance_due
from osg_folio_balance
where folio_id='00000000-0000-7000-8000-000000009102';
-- Expected net_charges=0.

rollback;
