-- OSG Scenario 05 v0.95 — one invoice contains CAPEX and OPEX
-- Synthetic test data. Requires master seed + supporting schema.

begin;

insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000001202','00000000-0000-7000-8000-000000000001','COMPANY','Supplier Test C05',true);

insert into investment_project (id,organization_id,property_id,name,status,budget,planned_start,actual_start)
values ('00000000-0000-7000-8000-000000001203','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','Reference Expansion Project','IN_PROGRESS',100000,'2026-09-01','2026-09-01');

insert into financial_document (id,organization_id,document_type,document_number,issuer_party_id,issue_date,service_date,currency,gross_total,status)
values ('00000000-0000-7000-8000-000000001210','00000000-0000-7000-8000-000000000001','INVOICE','CAPEX-OPEX-TEST-001','00000000-0000-7000-8000-000000001202','2026-09-12','2026-09-12','PLN',6500,'VERIFIED');

insert into financial_document_line (id,organization_id,financial_document_id,line_no,description,gross_amount) values
('00000000-0000-7000-8000-000000001211','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001210',1,'Construction material for new capacity',5000),
('00000000-0000-7000-8000-000000001212','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001210',2,'Pool / wellness chemicals',800),
('00000000-0000-7000-8000-000000001213','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001210',3,'Small operational tools',700);

insert into cash_movement (id,organization_id,from_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000001214','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000601',6500,'PLN','2026-09-14T10:00:00+02','CAPEX-OPEX-PAY-001','VERIFIED');

-- Separate economic events per document line preserve different classification.
insert into economic_event (id,organization_id,property_id,event_type,economic_date,amount,currency,source_document_line_id,status) values
('00000000-0000-7000-8000-000000001220','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','CAPEX','2026-09-12',5000,'PLN','00000000-0000-7000-8000-000000001211','DRAFT'),
('00000000-0000-7000-8000-000000001221','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','OPEX','2026-09-12',800,'PLN','00000000-0000-7000-8000-000000001212','DRAFT'),
('00000000-0000-7000-8000-000000001222','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','OPEX','2026-09-12',700,'PLN','00000000-0000-7000-8000-000000001213','DRAFT');

insert into allocation (id,organization_id,economic_event_id,amount,property_id,resource_id,investment_project_id,cost_center_id,allocation_type,classification,confidence,allocation_method,rationale) values
('00000000-0000-7000-8000-000000001230','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001220',5000,'00000000-0000-7000-8000-000000000010',null,'00000000-0000-7000-8000-000000001203',null,'DIRECT','CAPEX','VERIFIED','DOCUMENT_LINE','Construction material belongs to investment project'),
('00000000-0000-7000-8000-000000001231','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001221',800,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000302',null,'00000000-0000-7000-8000-000000000504','DIRECT','OPEX','VERIFIED','DOCUMENT_LINE','Wellness chemicals are current operating cost'),
('00000000-0000-7000-8000-000000001232','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001222',700,'00000000-0000-7000-8000-000000000010',null,null,'00000000-0000-7000-8000-000000000502','OVERHEAD','OPEX','MANUAL','DOCUMENT_LINE','Reference treatment: small tools expensed as maintenance OPEX');

update economic_event set status='POSTED',posted_at=now() where id in (
'00000000-0000-7000-8000-000000001220','00000000-0000-7000-8000-000000001221','00000000-0000-7000-8000-000000001222');
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000001220');
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000001221');
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000001222');

insert into reconciliation_link (id,organization_id,financial_document_id,cash_movement_id,match_status,matched_amount,confidence,rationale)
values ('00000000-0000-7000-8000-000000001240','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001210','00000000-0000-7000-8000-000000001214','MATCHED',6500,'VERIFIED','Invoice paid by one bank transfer; economics remain line-specific');

commit;

-- Expected:
-- Cash outflow/document total = 6500
-- CAPEX = 5000
-- OPEX = 1500
-- Operating result is not reduced by full 6500 as if all were OPEX.
