-- OSG Scenario 09 v0.96 — shared electricity allocated by Unit area
-- Synthetic test data. Requires v0.95 core/extensions/supporting + master seed.

begin;

insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000001601','00000000-0000-7000-8000-000000000001','COMPANY','Energy Supplier Test',true);

insert into cost_center (id,organization_id,property_id,code,name)
values ('00000000-0000-7000-8000-000000001602','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','ENERGY','Energy / Utilities');

insert into allocation_rule (id,organization_id,property_id,code,version_no,basis,configuration,valid_from,active)
values (
'00000000-0000-7000-8000-000000001603','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010',
'ENERGY_BY_AREA',1,'AREA_M2','{"unit_type_area_source":"unit_type.area_m2","rounding":"2dp","remainder_policy":"largest_remainder"}','2026-09-01',true);

insert into financial_document (id,organization_id,document_type,document_number,issuer_party_id,issue_date,service_date,currency,gross_total,status)
values ('00000000-0000-7000-8000-000000001610','00000000-0000-7000-8000-000000000001','INVOICE','ENERGY-TEST-09','00000000-0000-7000-8000-000000001601','2026-09-30','2026-09-30','PLN',5000,'VERIFIED');

insert into financial_document_line (id,organization_id,financial_document_id,line_no,description,gross_amount)
values ('00000000-0000-7000-8000-000000001611','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001610',1,'Electricity — September reference',5000);

insert into economic_event (id,organization_id,property_id,event_type,economic_date,amount,currency,source_document_line_id,status)
values ('00000000-0000-7000-8000-000000001620','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','OPEX','2026-09-30',5000,'PLN','00000000-0000-7000-8000-000000001611','DRAFT');

-- UnitType areas: Forest 50, Boho 38, Loft 38, Ostoja 34, Aura 45; total 205 m2.
-- Rounded allocations sum exactly to 5000.00.
insert into allocation (id,organization_id,economic_event_id,amount,property_id,unit_id,cost_center_id,allocation_rule_id,allocation_type,classification,confidence,allocation_method,rationale) values
('00000000-0000-7000-8000-000000001621','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001620',1219.51,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000201','00000000-0000-7000-8000-000000001602','00000000-0000-7000-8000-000000001603','SHARED','OPEX','SYSTEM_DERIVED','AREA_M2','50/205 of shared electricity'),
('00000000-0000-7000-8000-000000001622','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001620',926.83,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000202','00000000-0000-7000-8000-000000001602','00000000-0000-7000-8000-000000001603','SHARED','OPEX','SYSTEM_DERIVED','AREA_M2','38/205 of shared electricity'),
('00000000-0000-7000-8000-000000001623','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001620',926.83,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000203','00000000-0000-7000-8000-000000001602','00000000-0000-7000-8000-000000001603','SHARED','OPEX','SYSTEM_DERIVED','AREA_M2','38/205 of shared electricity'),
('00000000-0000-7000-8000-000000001624','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001620',829.27,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000204','00000000-0000-7000-8000-000000001602','00000000-0000-7000-8000-000000001603','SHARED','OPEX','SYSTEM_DERIVED','AREA_M2','34/205 of shared electricity'),
('00000000-0000-7000-8000-000000001625','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001620',1097.56,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000205','00000000-0000-7000-8000-000000001602','00000000-0000-7000-8000-000000001603','SHARED','OPEX','SYSTEM_DERIVED','AREA_M2','45/205 of shared electricity');

update economic_event set status='POSTED',posted_at=now() where id='00000000-0000-7000-8000-000000001620';
select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000001620');

commit;

-- Expected:
-- Total shared OPEX = 5000.00.
-- Allocations are reproducible from AllocationRule v1 + historical UnitType area data.
-- A future change to allocation methodology creates AllocationRule v2, not a rewrite of v1.
-- Invalid tenant/property references belong in negative P0 tests, not in a valid reference seed.
