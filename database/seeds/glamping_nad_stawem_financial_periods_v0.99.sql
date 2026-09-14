-- Glamping Nad Stawem — FinancialPeriod fixture v0.99
-- Synthetic/pre-freeze configuration. Period policy may later be generated automatically.

insert into financial_period (
  id,organization_id,property_id,period_start,period_end,status,closed_at
) values
('00000000-0000-7000-8000-000000000720','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','2026-07-01','2026-07-31','OPEN',null),
('00000000-0000-7000-8000-000000000721','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','2026-08-01','2026-08-31','OPEN',null),
('00000000-0000-7000-8000-000000000722','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','2026-09-01','2026-09-30','OPEN',null),
('00000000-0000-7000-8000-000000000723','00000000-0000-7000-8000-000000000001','00000000-0000-7000-8000-000000000010','2026-10-01','2026-10-31','OPEN',null);

-- Production period generation/closing is an application workflow.
-- These fixture rows only make pre-freeze economic posting scenarios executable.
