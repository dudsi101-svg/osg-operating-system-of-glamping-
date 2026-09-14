# OSG — Project Documentation Index

Status: kanoniczny indeks dokumentacji
Data: 2026-09-14

## 1. Checkpointy
- `checkpoints/OSG_02_Core_Data_Model_Checkpoint_v1.3.md`
- `checkpoints/OSG_03_PreBuild_Architecture_Checkpoint_v0.1.md`

## 2. Architektura
- `architecture/OSG_Implementation_Architecture_v0.1.md`
- `decisions/ADR-001-relational-core-postgresql.md`
- `decisions/ADR-002-separate-financial-truth-layers.md`
- `decisions/ADR-003-multi-property-ready-from-day-one.md`
- `decisions/ADR-004-api-first-and-contract-versioning.md`
- `decisions/ADR-005-event-driven-cross-domain-coordination.md`
- `decisions/ADR-006-pwa-first-web-delivery.md`

## 3. Model domenowy
- `data-model/OSG_M2_Relationship_Map_v0.2.md`
- `business-rules/OSG_M3_Business_Rules_Catalog_v0.2.md`
- `state-machines/OSG_State_Machines_v0.1.md`
- Logical ERD / entity catalog / source-of-truth artifacts

## 4. Financial Truth
- `financial/OSG_M5_Financial_Truth_Specification_v0.1.md`
- `financial/OSG_Financial_Truth_Reports_v0.1.md`
- `financial/OSG_Financial_Invariants_v0.1.md`
- `financial/OSG_Prepayment_Refund_and_Clearing_Contract_v0.1.md`

## 5. Security / Privacy
- `security/OSG_M6_Permissions_and_Security_v0.1.md`
- `security/OSG_Tenant_Isolation_Contract_v0.1.md`
- `security/OSG_Approval_Policy_Framework_v0.1.md`
- permission matrix
- `privacy/OSG_M9_Data_Lifecycle_and_Privacy_v0.1.md`

## 6. Metrics / Analytics
- `metrics/OSG_M7_Metric_Dictionary_v0.1.md`
- `analytics/OSG_Semantic_Layer_v0.1.md`
- `data-quality/OSG_Data_Quality_Scoring_v0.1.md`

## 7. Integracje
- `integrations/OSG_M8_Integration_Contracts_v0.1.md`
- `integrations/OSG_Idempotency_and_Deduplication_v0.1.md`

## 8. Produkt
- `product/OSG_M10_Application_Boundary_v0.1.md`
- `product/OSG_Command_Center_Contract_v0.1.md`
- `product/OSG_Operations_Center_Detail_v0.1.md`
- `product/OSG_Guest_Portal_Contract_v0.1.md`
- `product/OSG_Owner_Finance_Cockpit_v0.1.md`

## 9. Property / Operations / Maintenance
- `property/OSG_Availability_Conflict_Policy_v0.1.md`
- `operations/OSG_Resource_Capacity_Concurrency_v0.1.md`
- `maintenance/OSG_Maintenance_and_Asset_Lifecycle_v0.1.md`
- `inventory/OSG_Minimal_Inventory_v0.1.md`

## 10. Revenue / Intelligence
- `revenue/OSG_Revenue_Engine_v0.1.md`
- `intelligence/OSG_Intelligence_Governance_v0.1.md`

## 11. API / Events / Engineering
- `api/OSG_OpenAPI_Skeleton_v0.1.yaml`
- `api/OSG_Command_Contracts_v0.1.md`
- `api/OSG_Error_Model_v0.1.md`
- `events/OSG_M4_Domain_Events_and_Automations_v0.1.md`
- `events/schemas/`
- `engineering/OSG_CI_and_Test_Strategy_v0.1.md`
- `engineering/OSG_Outbox_and_Event_Delivery_v0.1.md`
- `observability/OSG_Observability_Model_v0.1.md`

## 12. Agenci
- `agents/OSG_Agent_Operating_Model_v1.md`
- `agents/OSG_Parallel_Implementation_Backlog_v0.1.md`

## 13. Walidacja / readiness
- `scenarios/OSG_End_to_End_Scenarios_v0.1.md`
- `readiness/OSG_M11_Schema_Freeze_Gate_v0.1.md`
- `readiness/OSG_M12_Build_Readiness_Review_v0.1.md`
- `readiness/OSG_Schema_Freeze_Candidate_v0.9.md`
- `readiness/OSG_Schema_Freeze_Assessment_v0.95.md`
- `readiness/OSG_Technical_Freeze_Checklist_v0.1.md`

## 14. Database / test proof
- `../database/proof/`
- `../database/seeds/`
- `../database/MIGRATIONS.md`
- `../tests/specs/OSG_P0_Executable_Test_Vectors_v0.1.yaml`
- `../tests/specs/OSG_P0_Proof_Execution_Plan_v0.1.md`
- `../tests/sql/p0_invariants_v0.1.sql`

## 15. Status projektu

Current architecture state:
- Concept: mature
- Domain model: stable pre-freeze candidate
- Financial Truth: stable pre-freeze candidate
- Product contracts: first coherent pass
- Semantic/AI governance: foundation defined
- Technical schema: proof stage
- Production implementation: not started
- Schema freeze: v0.95 conditional, not v1.0 final

## 16. Następny krok

1. wykonać P0 technical proof suite w PostgreSQL/backendzie,
2. zwalidować referencyjne scenariusze end-to-end,
3. zaktualizować schema/proof po wynikach,
4. dopiero wtedy ogłosić albo odrzucić `Schema v1.0 FINAL`.
