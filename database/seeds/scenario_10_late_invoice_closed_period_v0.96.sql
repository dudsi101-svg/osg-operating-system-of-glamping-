-- OSG Scenario 10 v0.99 — late invoice relating to HARD_CLOSED August
-- Requires current pre-v1 schema, master seed and financial-period fixture.

begin;

insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000001701','00000000-0000-7000-8000-000000000001','COMPANY','Late Supplier Test',true);

-- Shared fixture period IDs:
-- August    = ...0721
-- September = ...0722
-- Close August through the normal forward state transition.
update financial_period
set status='HARD_CLOSED', closed_at='2026-09-05T18:00:00+02'
where id='00000000-0000-7000-8000-000000000721';

-- Invoice arrives in September but service belongs to August.
insert into financial_document (id,organization_id,document_type,document_number,issuer_party_id,issue_date,service_date,due_date,currency,gross_total,status)
values ('00000000-0000-7000-8000-000000001710','00000000-0000-7000-8000-000000000001','INVOICE','LATE-AUG-001','00000000-0000-7000-8000-000000001701','2026-09-10','2026-08-31','2026-09-24','PLN',1200,'VERIFIED');

insert into financial_document_line (id,organization_id,financial_document_id,line_no,description,gross_amount)
values ('00000000-0000-7000-8000-000000001711','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001710',1,'Service delivered in August, invoice received after close',1200);

-- Do NOT post into HARD_CLOSED August. Recognize in September and keep the
-- historical relation explicit.
insert into economic_event (
  id,organization_id,property_id,financial_period_id,relates_to_financial_period_id,
  event_type,economic_date,amount,currency,source_document_line_id,status,adjustment_reason,effect_direction
) values (
'00000000-0000-7000-8000-000000001720','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010',
'00000000-0000-7000-8000-000000000722','00000000-0000-7000-8000-000000000721',
'ADJUSTMENT','2026-09-10',1200,'PLN','00000000-0000-7000-8000-000000001711','DRAFT','Late August operating invoice received after HARD_CLOSE','NORMAL');

insert into allocation (id,organization_id,economic_event_id,amount,property_id,cost_center_id,allocation_type,classification,confidence,allocation_method,rationale)
values ('00000000-0000-7000-8000-000000001721','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001720',1200,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000505','OVERHEAD','OPEX','VERIFIED','PRIOR_PERIOD_ADJUSTMENT','Recognized in September; relates to HARD_CLOSED August');

update economic_event
set status='POSTED', posted_at=now()
where id='00000000-0000-7000-8000-000000001720';

select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000001720');

commit;

-- Expected:
-- August remains HARD_CLOSED and its existing events are untouched.
-- September contains 1200 OPEX adjustment linked to August.
-- Attempt to edit/reverse an original August event in-place must fail.
