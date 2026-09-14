# OSG — Project Documentation Index

Status: kanoniczny indeks dokumentacji
Data: 2026-09-15

## 1. Checkpointy
- `checkpoints/OSG_02_Core_Data_Model_Checkpoint_v1.3.md`
- `checkpoints/OSG_03_PreBuild_Architecture_Checkpoint_v0.1.md`
- `checkpoints/OSG_04_PreFreeze_v0.96_Checkpoint.md`

## 2. Architektura / ADR
- `architecture/OSG_Implementation_Architecture_v0.1.md`
- `architecture/OSG_Aggregate_and_Concurrency_Model_v0.1.md`
- `architecture/OSG_Property_Context_Integrity_v0.1.md`
- ADR-001 relational core/PostgreSQL
- ADR-002 separate Financial Truth layers
- ADR-003 multi-property from day one
- ADR-004 API-first/versioned contracts
- ADR-005 event-driven cross-domain coordination
- ADR-006 PWA-first
- ADR-007 UUIDv7 application-generated IDs
- ADR-008 versioned PropertyStayPolicy/unit-night semantics
- ADR-009 aggregate concurrency + idempotent commands
- ADR-010 single Property reporting currency v1
- ADR-011 commercial occupancy vs physical utilization

## 3. Model domenowy
- `data-model/OSG_M2_Relationship_Map_v0.2.md`
- `data-model/OSG_Canonical_Entity_Catalog_v0.95.md`
- `business-rules/OSG_M3_Business_Rules_Catalog_v0.2.md`
- `state-machines/OSG_State_Machines_v0.1.md`

## 4. Financial Truth / Commerce
- `financial/OSG_M5_Financial_Truth_Specification_v0.1.md`
- `financial/OSG_Financial_Truth_Reports_v0.1.md`
- `financial/OSG_Financial_Invariants_v0.1.md`
- `financial/OSG_Prepayment_Refund_and_Clearing_Contract_v0.1.md`
- `financial/OSG_Financial_Period_Close_Contract_v0.1.md`
- `financial/OSG_Financial_Period_Assignment_v0.1.md`
- `commercial/OSG_Commercial_Snapshot_Contract_v0.1.md`
- `commercial/OSG_Folio_Close_and_Balance_Contract_v0.1.md`

## 5. Security / Identity / Privacy
- `security/OSG_M6_Permissions_and_Security_v0.1.md`
- `security/OSG_Tenant_Isolation_Contract_v0.1.md`
- `security/OSG_Approval_Policy_Framework_v0.1.md`
- `security/OSG_Permission_Matrix_v0.2.md`
- `privacy/OSG_M9_Data_Lifecycle_and_Privacy_v0.1.md`
- `guest/OSG_Guest_Identity_and_Merge_Contract_v0.1.md`

## 6. Metrics / Analytics / Data Quality
- `metrics/OSG_M7_Metric_Dictionary_v0.3.md` — current metric contract
- `metrics/OSG_M7_Metric_Dictionary_v0.1.md` / v0.2 — historical evolution
- `analytics/OSG_Semantic_Layer_v0.1.md`
- `analytics/OSG_Semantic_API_Contract_v0.1.md`
- `analytics/OSG_Explainability_Contract_v0.1.md`
- `data-quality/OSG_Data_Quality_Scoring_v0.1.md`

## 7. Integracje
- `integrations/OSG_M8_Integration_Contracts_v0.1.md`
- `integrations/OSG_Idempotency_and_Deduplication_v0.1.md`

## 8. Produkt / UX contracts
- `product/OSG_M10_Application_Boundary_v0.1.md`
- `product/OSG_Command_Center_Contract_v0.1.md`
- `product/OSG_Operations_Center_Detail_v0.1.md`
- `product/OSG_Guest_Portal_Contract_v0.1.md`
- `product/OSG_Owner_Finance_Cockpit_v0.1.md`
- `product/OSG_Role_Based_Information_Architecture_v0.1.md`

## 9. Property / Operations / Maintenance / Inventory
- `property/OSG_Availability_Conflict_Policy_v0.1.md`
- `operations/OSG_Resource_Capacity_Concurrency_v0.1.md`
- `maintenance/OSG_Maintenance_and_Asset_Lifecycle_v0.1.md`
- `inventory/OSG_Minimal_Inventory_v0.1.md`

## 10. Revenue / Intelligence
- `revenue/OSG_Revenue_Engine_v0.1.md`
- `intelligence/OSG_Intelligence_Governance_v0.1.md`

## 11. Communication
- `communication/OSG_Communication_and_Notification_Contract_v0.1.md`

## 12. API / Events / Engineering / Observability
- `api/OSG_OpenAPI_v0.2.yaml` — current API candidate
- `api/OSG_OpenAPI_Skeleton_v0.1.yaml` — historical
- `api/OSG_Command_Contracts_v0.1.md`
- `api/OSG_Error_Model_v0.1.md`
- `events/OSG_M4_Domain_Events_and_Automations_v0.1.md`
- `events/schemas/`
- `engineering/OSG_CI_and_Test_Strategy_v0.1.md`
- `engineering/OSG_Definition_of_Done_v0.1.md`
- `engineering/OSG_Outbox_and_Event_Delivery_v0.1.md`
- `observability/OSG_Observability_Model_v0.1.md`

## 13. Agenci
- `agents/OSG_Agent_Operating_Model_v1.md`
- `agents/OSG_Parallel_Implementation_Backlog_v0.1.md`
- root `../AGENTS.md`

## 14. Walidacja / readiness
- `scenarios/OSG_End_to_End_Scenarios_v0.1.md`
- `readiness/OSG_M11_Schema_Freeze_Gate_v0.1.md`
- `readiness/OSG_M12_Build_Readiness_Review_v0.1.md`
- `readiness/OSG_Schema_Freeze_Candidate_v0.9.md`
- `readiness/OSG_Schema_Freeze_Assessment_v0.95.md`
- `readiness/OSG_PreFreeze_Gap_Register_v0.96.md`
- `readiness/OSG_Technical_Freeze_Checklist_v0.1.md`

## 15. Database schema — current pre-v1 candidate
Canonical clean-load sequence: `../database/README.md`.

Base:
- `../database/schema/osg_schema_v0.95_core.sql`
- `../database/schema/osg_schema_v0.95_extensions.sql`
- `../database/schema/osg_schema_v0.95_supporting.sql`

Additive/pre-v1 patches currently include:
- v0.96 historical-period relation + closed-target guard
- v0.96 posted-allocation immutability
- PropertyStayPolicy
- AvailabilityBlock impact semantics
- EconomicEvent NORMAL/REVERSAL direction
- same-tenant Property-context guards
- HARD_CLOSED mutation/controlled reopen guards
- mandatory FinancialPeriod assignment + non-overlap
- CommandIdempotency ledger
- Property reporting-currency guard
- Guest identity/merge provenance + alias guards
- overnight attribution anchor
- Folio currency/refund/close guards

Historical only:
- `../database/schema/osg_logical_schema_v0.1.sql`

## 16. Semantic SQL — current business truth
- `../database/semantic/osg_semantic_occupancy_v0.1.sql` — capacity/physical facts
- `../database/semantic/osg_semantic_accommodation_nights_v0.1.sql` — commercial accommodation nights
- `../database/semantic/osg_semantic_financial_truth_v0.1.sql` — economic result/unit/stay/settlement
- `../database/semantic/osg_semantic_folio_v0.1.sql`
- `../database/semantic/osg_semantic_cash_v0.1.sql`
- `../database/semantic/osg_semantic_revenue_v0.1.sql` — content semantics v0.3
- `../database/semantic/osg_semantic_operations_v0.1.sql`
- `../database/semantic/osg_semantic_guest_v0.1.sql`
- `../database/semantic/osg_data_quality_checks_v0.1.sql`
- `../database/semantic/osg_data_quality_accommodation_nights_v0.1.sql`

## 17. Database proof guards/workflows
- `../database/proof/financial_conservation_guards_v0.1.sql`
- `../database/proof/resource_capacity_guard_v0.1.sql`
- `../database/proof/financial_posting_workflow_v0.2.sql` — current posting proof
- `../database/proof/tenant_rls_v0.1.sql`

## 18. Reference configuration / scenarios
Configuration:
- `../database/seeds/glamping_nad_stawem_master_v0.95.sql`
- `../database/seeds/glamping_nad_stawem_stay_policy_v0.97.sql` — current content includes overnight anchor
- `../database/seeds/glamping_nad_stawem_financial_periods_v0.99.sql`

Business scenarios 01–10 + 12 under `../database/seeds/`.
Negative/capacity scenario 11 under `../tests/sql/`.

## 19. Executable test specifications
- `../tests/specs/OSG_P0_Executable_Test_Vectors_v0.1.yaml`
- `../tests/specs/OSG_P0_Proof_Execution_Plan_v0.1.md`
- `../tests/sql/p0_invariants_v0.1.sql`
- `../tests/sql/folio_invariants_pre_v1.sql`

## 20. GitHub execution gates
- #1 StaySegment overlap
- #2 Resource concurrency
- #3 Atomic Financial Truth posting / closed period
- #4 tenant isolation DB/API/jobs
- #5 integration/automation/command idempotency
- #6 real PMS/reservation discovery
- #7 bank/cash import discovery
- #8 clean-load entire current schema + scenarios
- #9 same-tenant cross-Property integrity
- #10 Folio balance/currency/refund proof (P1 before live payments)

## 21. Current status

- Product concept: mature
- Domain boundaries: stable pre-v1 candidate
- Financial Truth: mature semantic candidate; executable proof pending
- Property/Digital Twin: mature core candidate
- Commercial accommodation-night semantics: separated from physical utilization
- Guest identity provenance: modeled additively
- Semantic API/KPI: coherent pre-v1 candidate
- Technical schema: base v0.95 + reviewed pre-v1 patches; not yet consolidated
- PostgreSQL clean-load: **not executed yet**
- Production implementation: not started
- Schema freeze: **NOT v1.0 FINAL**

## 22. Immediate gate

1. Execute Issue #8 on real PostgreSQL.
2. Execute P0 Issues #1–#5 and #9 under real concurrency/runtime roles.
3. Fix only evidence-backed failures.
4. Consolidate accepted patches into one canonical v1.0 schema.
5. Generate actual migrations and rerun tests.
6. Then decide Schema v1.0 FINAL.
