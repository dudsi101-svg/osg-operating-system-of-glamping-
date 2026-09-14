-- OSG Scenario 10 v0.96 — late invoice relating to HARD_CLOSED August
-- Requires schema v0.95 + v0.96 patch + master seed.

begin;

insert into party (id,organization_id,party_type,display_name,active)
values ('00000000-0000-7000-8000-000000001701','00000000-0000-7000-8000-000000000001','COMPANY','Late Supplier Test',true);

insert into financial_period (id,organization_id,property_id,period_start,period_end,status,closed_at)
values
('00000000-0000-7000-8000-000000001702','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','2026-08-01','2026-08-31','HARD_CLOSED','2026-09-05T18:00:00+02'),
('00000000-0000-7000-8000-000000001703','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','2026-09-01','2026-09-30','OPEN',null);

-- Invoice arrives in September but service belongs to August.
insert into financial_document (id,organization_id,document_type,document_number,issuer_party_id,issue_date,service_date,due_date,currency,gross_total,status)
values ('00000000-0000-7000-8000-000000001710','00000000-0000-7000-8000-000000000001','INVOICE','LATE-AUG-001','00000000-0000-7000-8000-000000001701','2026-09-10','2026-08-31','2026-09-24','PLN',1200,'VERIFIED');

insert into financial_document_line (id,organization_id,financial_document_id,line_no,description,gross_amount)
values ('00000000-0000-7000-8000-000000001711','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001710',1,'Service delivered in August, invoice received after close',1200);

-- Do NOT post into the HARD_CLOSED August period. Recognize controlled adjustment in September,
-- while explicitly recording which prior period it concerns.
insert into economic_event (
  id,organization_id,property_id,financial_period_id,relates_to_financial_period_id,
  event_type,economic_date,amount,currency,source_document_line_id,status,adjustment_reason
) values (
'00000000-0000-7000-8000-000000001720','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010',
'00000000-0000-7000-8000-000000001703','00000000-0000-7000-8000-000000001702',
'ADJUSTMENT','2026-09-10',1200,'PLN','00000000-0000-7000-8000-000000001711','DRAFT','Late August operating invoice received after HARD_CLOSE');

insert into allocation (id,organization_id,economic_event_id,amount,property_id,cost_center_id,allocation_type,classification,confidence,allocation_method,rationale)
values ('00000000-0000-7000-8000-000000001721','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000001720',1200,'00000000-0000-7000-8000-000000000010','00000000-0000-7000-8000-000000000505','OVERHEAD','OPEX','VERIFIED','PRIOR_PERIOD_ADJUSTMENT','Recognized in September; relates to HARD_CLOSED August');

update economic_event
set status='POSTED', posted_at=now()
where id='00000000-0000-7000-8000-000000001720';

select osg_assert_economic_event_balanced('00000000-0000-7000-8000-000000001720');

commit;

-- Expected:
-- August remains unchanged/HARD_CLOSED.
-- September contains 1200 adjustment, explicitly linked to August.
-- Reports may separately show current-period operations and prior-period adjustments.
-- No silent historical mutation occurs.
