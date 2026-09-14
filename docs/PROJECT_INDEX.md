# OSG — Project Documentation Index

Status: kanoniczny indeks dokumentacji
Data: 2026-09-14

## 1. Checkpointy
- `checkpoints/OSG_02_Core_Data_Model_Checkpoint_v1.3.md`
- `checkpoints/OSG_03_PreBuild_Architecture_Checkpoint_v0.1.md`
- `checkpoints/OSG_04_PreFreeze_v0.96_Checkpoint.md`

## 2. Architektura / ADR
- `architecture/OSG_Implementation_Architecture_v0.1.md`
- `decisions/ADR-001-relational-core-postgresql.md`
- `decisions/ADR-002-separate-financial-truth-layers.md`
- `decisions/ADR-003-multi-property-ready-from-day-one.md`
- `decisions/ADR-004-api-first-and-contract-versioning.md`
- `decisions/ADR-005-event-driven-cross-domain-coordination.md`
- `decisions/ADR-006-pwa-first-web-delivery.md`
- `decisions/ADR-007-uuidv7-application-generated-identifiers.md`

## 3. Model domenowy
- `data-model/OSG_M2_Relationship_Map_v0.2.md`
- `data-model/OSG_Canonical_Entity_Catalog_v0.95.md`
- `business-rules/OSG_M3_Business_Rules_Catalog_v0.2.md`
- `state-machines/OSG_State_Machines_v0.1.md`
- Logical ERD / Source-of-Truth artifacts

## 4. Financial Truth
- `financial/OSG_M5_Financial_Truth_Specification_v0.1.md`
- `financial/OSG_Financial_Truth_Reports_v0.1.md`
- `financial/OSG_Financial_Invariants_v0.1.md`
- `financial/OSG_Prepayment_Refund_and_Clearing_Contract_v0.1.md`
- `commerce/OSG_Commercial_Snapshot_Contract_v0.1.md`

## 5. Security / Privacy / Approvals
- `security/OSG_M6_Permissions_and_Security_v0.1.md`
- `security/OSG_Tenant_Isolation_Contract_v0.1.md`
- `security/OSG_Approval_Policy_Framework_v0.1.md`
- permission matrix
- `privacy/OSG_M9_Data_Lifecycle_and_Privacy_v0.1.md`

## 6. Metrics / Analytics / Data Quality
- `metrics/OSG_M7_Metric_Dictionary_v0.1.md`
- `analytics/OSG_Semantic_Layer_v0.1.md`
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
- `api/OSG_OpenAPI_Skeleton_v0.1.yaml`
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

## 15. Database schema — current candidate
Load order and status: `../database/README.md`

Current candidate:
- `../database/schema/osg_schema_v0.95_core.sql`
- `../database/schema/osg_schema_v0.95_extensions.sql`
- `../database/schema/osg_schema_v0.95_supporting.sql`
- `../database/schema/osg_schema_v0.96_patch.sql`
- `../database/schema/osg_schema_v0.96_financial_guard_patch.sql`

Historical only:
- `../database/schema/osg_logical_schema_v0.1.sql`

## 16. Database proof guards
- `../database/proof/financial_conservation_guards_v0.1.sql`
- `../database/proof/resource_capacity_guard_v0.1.sql`
- `../database/proof/tenant_rls_v0.1.sql`
- other historical proof files in `../database/proof/`

## 17. Reference data / end-to-end executable scenarios
Master:
- `../database/seeds/glamping_nad_stawem_master_v0.95.sql`

Business-path scenarios:
- `../database/seeds/scenario_01_direct_stay_sauna_v0.95.sql`
- `../database/seeds/scenario_02_ota_net_payout_v0.95.sql`
- `../database/seeds/scenario_03_operator_expense_settlement_v0.95.sql`
- `../database/seeds/scenario_04_mixed_business_private_allocation_v0.95.sql`
- `../database/seeds/scenario_05_capex_opex_one_invoice_v0.95.sql`
- `../database/seeds/scenario_06_incident_relocation_v0.95.sql`
- `../database/seeds/scenario_07_prepayment_full_refund_v0.96.sql`
- `../database/seeds/scenario_08_duplicate_pms_event_v0.96.sql`
- `../database/seeds/scenario_09_shared_electricity_allocation_v0.96.sql`
- `../database/seeds/scenario_10_late_invoice_closed_period_v0.96.sql`
- `../database/seeds/scenario_12_turnover_at_risk_v0.96.sql`

Negative/capacity test:
- `../tests/sql/scenario_11_resource_capacity_v0.96.sql`

## 18. P0 proof specifications
- `../tests/specs/OSG_P0_Executable_Test_Vectors_v0.1.yaml`
- `../tests/specs/OSG_P0_Proof_Execution_Plan_v0.1.md`
- `../tests/sql/p0_invariants_v0.1.sql`

GitHub Issues #1–#5 contain individual P0 proofs.
Issue #8 is the full clean-load/scenario execution gate.
Issues #6–#7 contain real PMS/bank discovery.

## 19. Current status

- Concept: mature
- Domain model: stable pre-freeze candidate
- Financial Truth: stable pre-freeze candidate
- Product contracts: coherent first-pass
- Semantic/AI governance: foundation defined
- Technical schema: v0.96 candidate, not executed in PostgreSQL yet
- Reference scenarios: 12 designed; 11 valid-path seeds + 1 negative/capacity SQL test
- Production implementation: not started
- Schema freeze: **v0.96 semantic candidate; NOT v1.0 FINAL**

## 20. Next gate

1. Execute Issue #8 clean load in real PostgreSQL.
2. Execute concurrent P0 proofs Issues #1–#5.
3. Fold accepted patches into one canonical v1.0 DDL.
4. Generate versioned DEV migrations.
5. Only then decide `Schema v1.0 FINAL`.
