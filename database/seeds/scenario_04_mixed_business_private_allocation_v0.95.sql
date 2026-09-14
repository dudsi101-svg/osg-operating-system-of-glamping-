-- OSG Scenario 04 v0.95 — 8000 PLN document, only 20% economic business share
-- Synthetic test data. Requires master seed + supporting schema.

begin;

insert into party (id,organization_id,party_type,display_name,legal_name,active) values
('00000000-0000-7000-8000-000000001101','00000000-0000-7000-8000-000000000001','COMPANY','Glamping Economic Bearer C04','Reference business entity',true),
('00000000-0000-7000-8000-000000001102','00000000-0000-7000-8000-000000000001','COMPANY','Leasing / Vehicle Supplier Test','Synthetic supplier',true);

insert into financial_document (id,organization_id,document_type,document_number,issuer_party_id,recipient_party_id,issue_date,service_date,currency,gross_total,status)
values ('00000000-0000-7000-8000-000000001110','00000000-0000-7000-8000-000000000001','INVOICE','VEH-TEST-001','00000000-0000-7000-8000-000000001102','00000000-0000-7000-8000-000000001101','2026-09-10','2026-09-10','PLN',8000,'VERIFIED');

insert into financial_document_line (id,organization_id,financial_document_id,line_no,description,gross_amount)
values ('00000000-0000-7000-8000-000000001111','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001110',1,'Vehicle-related monthly cost',8000);

insert into cash_movement (id,organization_id,from_money_account_id,amount,currency,occurred_at,external_reference,status)
values ('00000000-0000-7000-8000-000000001112','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000601',8000,'PLN','2026-09-10T09:00:00+02','VEH-BANK-TEST-001','VERIFIED');

insert into economic_event (id,organization_id,property_id,event_type,economic_date,amount,currency,source_document_line_id,status)
values ('00000000-0000-7000-8000-000000001120','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','OPEX','2026-09-10',8000,'PLN','00000000-0000-7000-8000-000000001111','DRAFT');

-- 20% belongs economically to the glamping; 80% is explicitly excluded.
insert into allocation (id,organization_id,economic_event_id,amount,property_id,cost_center_id,economic_bearer_party_id,allocation_type,classification,confidence,allocation_method,rationale) values
('00000000-0000-7000-8000-000000001121','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001120',1600,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000505','00000000-0000-7000-8000-000000001101','SHARED','OPEX','ESTIMATED','MANUAL_PERCENTAGE','Reference assumption: 20% real glamping use'),
('00000000-0000-7000-8000-000000001122','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001120',6400,null,null,null,'NON_BUSINESS','NON_BUSINESS','ESTIMATED','MANUAL_PERCENTAGE','Reference assumption: 80% outside Glamping Nad Stawem economics');

update economic_event set status='POSTED',posted_at=now() where id='00000000-0000-7000-8000-000000001120';
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000001120');

insert into reconciliation_link (id,organization_id,financial_document_id,cash_movement_id,economic_event_id,match_status,matched_amount,confidence,rationale)
values ('00000000-0000-7000-8000-000000001123','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001110','00000000-0000-7000-8000-000000001112','00000000-0000-7000-8000-000000001120','MATCHED',8000,'VERIFIED','One document and cash outflow; economic allocation splits business relevance');

commit;

-- Expected views:
-- Accounting/document view: 8000
-- Cash outflow: 8000
-- Economic OPEX Glamping Nad Stawem: 1600
-- NON_BUSINESS: 6400
-- Data confidence must reveal that the 20/80 split is ESTIMATED.
