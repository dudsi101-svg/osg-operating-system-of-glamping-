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

## 5. Security / Privacy
- `security/OSG_M6_Permissions_and_Security_v0.1.md`
- permission matrix
- `privacy/OSG_M9_Data_Lifecycle_and_Privacy_v0.1.md`

## 6. Metrics
- `metrics/OSG_M7_Metric_Dictionary_v0.1.md`

## 7. Integracje
- `integrations/OSG_M8_Integration_Contracts_v0.1.md`

## 8. Produkt
- `product/OSG_M10_Application_Boundary_v0.1.md`
- `product/OSG_Command_Center_Contract_v0.1.md`

## 9. API / Events
- `api/OSG_OpenAPI_Skeleton_v0.1.yaml`
- `api/OSG_Command_Contracts_v0.1.md`
- `api/OSG_Error_Model_v0.1.md`
- `events/OSG_M4_Domain_Events_and_Automations_v0.1.md`
- `events/schemas/`

## 10. Agenci
- `agents/OSG_Agent_Operating_Model_v1.md`
- `agents/OSG_Parallel_Implementation_Backlog_v0.1.md`

## 11. Walidacja / readiness
- `scenarios/OSG_End_to_End_Scenarios_v0.1.md`
- `readiness/OSG_M11_Schema_Freeze_Gate_v0.1.md`
- `readiness/OSG_M12_Build_Readiness_Review_v0.1.md`
- `readiness/OSG_Schema_Freeze_Candidate_v0.9.md`
- `readiness/OSG_Technical_Freeze_Checklist_v0.1.md`

## 12. Database proof
- `../database/proof/`
- `../database/seeds/`
- `../database/MIGRATIONS.md`

## 13. Status projektu

Current architecture state:
- Concept: mature
- Domain model: stable candidate
- Financial Truth: stable candidate
- Contracts: first complete pass
- Technical schema: proof stage
- Production implementation: not started
- Schema freeze: v0.9 candidate, not v1.0 final

## 14. Następny krok

Wykonać P0 technical proof items z `OSG_Technical_Freeze_Checklist_v0.1.md`, następnie ogłosić albo odrzucić Schema v1.0 FINAL.
