-- OSG Scenario 03 v0.95 — operator-funded expense → EconomicEvent → Settlement → repayment
-- Synthetic reference data. Requires master seed + schema/proof financial guards.

begin;

-- Separate economic bearer from individual owner/operator.
insert into party (id,organization_id,party_type,display_name,legal_name,active) values
('00000000-0000-7000-8000-000000001001','00000000-0000-7000-8000-000000000001','COMPANY','Glamping Nad Stawem — Economic Bearer','Reference business entity',true),
('00000000-0000-7000-8000-000000001002','00000000-0000-7000-8000-000000000001','COMPANY','Dostawca Testowy','Synthetic supplier',true);

-- Kuba buys housekeeping supplies for 430 PLN using his own/reference funds.
insert into financial_document (id,organization_id,document_type,document_number,issuer_party_id,recipient_party_id,issue_date,service_date,currency,gross_total,status)
values ('00000000-0000-7000-8000-000000001010','00000000-0000-7000-8000-000000000001','RECEIPT','TEST/09/001','00000000-0000-7000-8000-000000001002','00000000-0000-7000-8000-000000001001','2026-09-14','2026-09-14','PLN',430,'VERIFIED');

insert into financial_document_line (id,organization_id,financial_document_id,line_no,description,gross_amount)
values ('00000000-0000-7000-8000-000000001011','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001010',1,'Środki czystości / housekeeping',430);

-- Real/logical cash leaves Kuba reference funds.
insert into cash_movement (id,organization_id,from_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000001012','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000605',430,'PLN','2026-09-14T11:00:00+02','KUBA-EXP-TEST-001','VERIFIED');

-- Economic meaning: 430 PLN OPEX belongs to the glamping business.
insert into economic_event (id,organization_id,property_id,event_type,economic_date,amount,currency,source_document_line_id,status)
values ('00000000-0000-7000-8000-000000001020','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','OPEX','2026-09-14',430,'PLN','00000000-0000-7000-8000-000000001011','DRAFT');

insert into allocation (id,organization_id,economic_event_id,amount,property_id,cost_center_id,paid_by_party_id,economic_bearer_party_id,allocation_type,classification,confidence,allocation_method,rationale)
values ('00000000-0000-7000-8000-000000001021','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001020',430,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000501','00000000-0000-7000-8000-000000000022','00000000-0000-7000-8000-000000001001','DIRECT','OPEX','VERIFIED','DOCUMENT_LINE','Operator paid housekeeping supplies for business');

update economic_event set status='POSTED',posted_at=now() where id='00000000-0000-7000-8000-000000001020';
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000001020');

-- Document/cash are reconciled but remain separate facts.
insert into reconciliation_link (id,organization_id,financial_document_id,cash_movement_id,economic_event_id,match_status,matched_amount,confidence,rationale)
values ('00000000-0000-7000-8000-000000001022','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001010','00000000-0000-7000-8000-000000001012','00000000-0000-7000-8000-000000001020','MATCHED',430,'VERIFIED','Receipt, operator cash outflow and OPEX refer to same business purchase');

-- The difference payer != economic bearer creates a liability to Kuba.
insert into settlement_entry (id,organization_id,source_economic_event_id,source_allocation_id,creditor_party_id,debtor_party_id,amount,currency,status)
values ('00000000-0000-7000-8000-000000001030','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001020','00000000-0000-7000-8000-000000001021','00000000-0000-7000-8000-000000000022','00000000-0000-7000-8000-000000001001',430,'PLN','OPEN');

-- Later glamping bank repays Kuba.
insert into cash_movement (id,organization_id,from_money_account_id,to_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000001031','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000601','00000000-0000-7000-8000-000000000605',430,'PLN','2026-09-16T12:00:00+02','SETTLEMENT-KUBA-TEST-001','VERIFIED');

insert into settlement_application (id,organization_id,settlement_entry_id,cash_movement_id,amount,applied_at)
values ('00000000-0000-7000-8000-000000001032','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001030','00000000-0000-7000-8000-000000001031',430,'2026-09-16T12:00:00+02');

select osg_assert_settlement_not_overapplied('00000000-0000-7000-8000-000000001030');

update settlement_entry set status='SETTLED' where id='00000000-0000-7000-8000-000000001030';

insert into reconciliation_link (id,organization_id,cash_movement_id,settlement_application_id,match_status,matched_amount,confidence,rationale)
values ('00000000-0000-7000-8000-000000001033','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001031','00000000-0000-7000-8000-000000001032','MATCHED',430,'VERIFIED','Business repayment settles operator-funded expense');

commit;

-- Expected outputs:
-- Economic OPEX: 430 PLN
-- Initial settlement: Business owes Kuba 430 PLN
-- After repayment: settlement open balance = 0
-- Repayment cash movement MUST NOT create a second OPEX event.
