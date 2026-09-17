# OSG — Project Documentation Index

Status: kanoniczny indeks dokumentacji
Data aktualizacji: 2026-09-16
Aktualny etap: **Schema v1.0 RC1 CONSOLIDATED → production migrations + complete RLS**

## 1. Checkpointy
- `checkpoints/OSG_02_Core_Data_Model_Checkpoint_v1.3.md`
- `checkpoints/OSG_03_PreBuild_Architecture_Checkpoint_v0.1.md`
- `checkpoints/OSG_04_PreFreeze_v0.96_Checkpoint.md`
- `checkpoints/OSG_05_Schema_v1_RC1_Readiness_Checkpoint.md`
- `checkpoints/OSG_06_Schema_v1_RC1_Consolidated_Checkpoint.md` — **current handoff checkpoint**

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
- `commercial/OSG_Charge_Correction_Contract_v0.1.md`

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
- `engineering/OSG_RC1_Database_Function_Promotion_Register_v0.1.md` — runtime/proof classification for RC1
- `observability/OSG_Observability_Model_v0.1.md`

## 13. Agenci
- `agents/OSG_Agent_Operating_Model_v1.md`
- `agents/OSG_Parallel_Implementation_Backlog_v0.1.md`
- root `../AGENTS.md`

## 14. Walidacja / readiness
- `readiness/OSG_Technical_Freeze_Checklist_v0.1.md`
- `readiness/OSG_PreFreeze_Gap_Register_v0.96.md`
- `readiness/OSG_M11_Schema_Freeze_Gate_v0.1.md`
- `readiness/OSG_M12_Build_Readiness_Review_v0.1.md`
- `readiness/OSG_Schema_Freeze_Candidate_v0.9.md` — historical pre-execution assessment
- `readiness/OSG_Schema_Freeze_Assessment_v0.95.md` — historical assessment
- `scenarios/OSG_End_to_End_Scenarios_v0.1.md`

Current execution status is authoritative in Checkpoint 06. Historical `PENDING_EXECUTION` language in older assessment files is retained only as architecture history.

## 15. Database schema — current canonical RC1 candidate

Fresh-install candidate:
- `../database/rc/osg_schema_v1_rc1.sql`

Deterministic SHA-256:
- `4c43fa53da21192b4160936b26770a1d9845acc5780f3d2c4d4b32a0be589f0d`

Database guide:
- `../database/README.md`

Migration policy draft/guidance:
- `../database/MIGRATIONS.md`

The historical v0.95 + pre-v1 patch chain remains regeneration/evolution evidence, not the preferred fresh-install interface.

Accepted RC1 behavior includes:
- historical-period relation + closed-target guard
- posted-allocation immutability
- PropertyStayPolicy
- AvailabilityBlock impact semantics
- EconomicEvent NORMAL/REVERSAL direction
- same-tenant Property-context guards
- ExternalReference tenant-target fail-closed guard
- HARD_CLOSED mutation/controlled reopen guards
- mandatory FinancialPeriod assignment + non-overlap
- CommandIdempotency ledger
- Property reporting-currency guard
- Guest identity/merge provenance + alias guards
- overnight attribution anchor
- Folio currency/refund/close guards
- final Charge immutability + explicit reversal conservation
- concurrent Charge reversal serialization

Historical only:
- `../database/schema/osg_logical_schema_v0.1.sql`

## 16. Semantic SQL — current business truth
- `../database/semantic/osg_semantic_occupancy_v0.1.sql`
- `../database/semantic/osg_semantic_accommodation_nights_v0.1.sql`
- `../database/semantic/osg_semantic_financial_truth_v0.1.sql`
- `../database/semantic/osg_semantic_folio_v0.1.sql`
- `../database/semantic/osg_semantic_cash_v0.1.sql`
- `../database/semantic/osg_semantic_revenue_v0.1.sql`
- `../database/semantic/osg_semantic_operations_v0.1.sql`
- `../database/semantic/osg_semantic_guest_v0.1.sql`
- `../database/semantic/osg_data_quality_checks_v0.1.sql`
- `../database/semantic/osg_data_quality_accommodation_nights_v0.1.sql`

## 17. Database proof lineage / runtime promotion

Historically developed under `database/proof/` and promoted into RC1 runtime candidate:
- `../database/proof/financial_conservation_guards_v0.1.sql`
- `../database/proof/resource_capacity_guard_v0.1.sql`
- `../database/proof/financial_posting_workflow_v0.2.sql`

Classification authority:
- `engineering/OSG_RC1_Database_Function_Promotion_Register_v0.1.md`

Not a production baseline:
- `../database/proof/tenant_rls_v0.1.sql` — selective proof only
- `../database/proof/constraints_v0.1.sql` — historical model proof
- `../database/proof/financial_posting_workflow_v0.1.sql` — superseded

## 18. Reference configuration / scenarios

Configuration:
- `../database/seeds/glamping_nad_stawem_master_v0.95.sql`
- `../database/seeds/glamping_nad_stawem_stay_policy_v0.97.sql`
- `../database/seeds/glamping_nad_stawem_financial_periods_v0.99.sql`

Business scenarios 01–10 + 12 execute under CI.
Negative/capacity scenario 11 executes under `../tests/sql/`.

## 19. Executable proof harnesses

Pre-v1 lineage proof:
- `../.github/workflows/osg-pre-v1-clean-load.yml`

RC1 deterministic equivalence/drift proof:
- `../.github/workflows/osg-schema-v1-rc1-equivalence.yml`
- `../tests/integration/schema_v1_rc1_equivalence.sh`

Primary integration proofs:
- `../tests/integration/resource_concurrency_pre_v1.py`
- `../tests/integration/financial_posting_pre_v1.py`
- `../tests/integration/idempotency_pre_v1.py`
- `../tests/integration/idempotency_business_effects_pre_v1.py`
- `../tests/integration/tenant_isolation_pre_v1.py`
- `../tests/integration/property_context_pre_v1.py`
- `../tests/integration/settlement_concurrency_pre_v1.py`
- `../tests/integration/folio_invariants_pre_v1.py`
- `../tests/integration/charge_reversal_pre_v1.py`

Key accepted runs:
- pre-v1 repaired full proof `35093917785` — **PASS**
- deterministic RC1 generation/equivalence `35113431149` — **PASS**
- RC1 promotion `35113875981` — **PASS**
- committed RC1 byte-drift + full behavior verification `35114164171` — **PASS**

RC1 proof inventory:
- 92 tables
- 20 views
- 238 functions
- 22 non-internal triggers
- 659 constraints

## 20. GitHub execution gates

Completed:
- #1 StaySegment overlap — CLOSED / PASS
- #2 Resource concurrency — CLOSED / PASS
- #3 Atomic Financial Truth posting / closed period — CLOSED / PASS
- #4 tenant isolation DB/runtime role/jobs — CLOSED / PASS for proven critical runtime paths
- #5 integration/automation/command idempotency — CLOSED / PASS
- #8 clean-load current schema + scenarios — CLOSED / PASS
- #9 same-tenant cross-Property integrity — CLOSED / PASS
- #10 Folio balance/currency/refund proof — CLOSED / PASS
- #11 Charge immutability/reversal proof — CLOSED / PASS
- #14 Settlement conservation true concurrency — CLOSED / PASS
- #15 deterministic consolidated RC1 + behavioral equivalence — COMPLETED / PASS

Open RC gates before FINAL:
- #16 production migration baseline + data-preserving upgrade path
- #17 production-wide tenant RLS policy + complete coverage proof

External discovery still open:
- #6 real PMS/reservation/channel flow
- #7 bank/cash import discovery

## 21. Current status

- Product concept: mature
- Domain boundaries: consolidated into proven RC1 candidate
- Financial Truth: semantic + atomic/concurrency/immutability proof green
- Property/Digital Twin: core + cross-Property integrity proof green
- Commercial accommodation-night semantics: separated from physical utilization
- Guest identity provenance: modeled additively
- Semantic API/KPI: coherent pre-v1/RC candidate
- Tenant integrity: critical runtime paths proven; **production-wide RLS coverage still pending #17**
- Idempotency: command/integration/automation business-effect proof green
- Settlement: conservation and true-concurrency proof green
- Folio/Charge: live-commerce invariant proof green
- PostgreSQL pre-v1 patch-chain clean-load: PASS
- Deterministic consolidated Schema v1.0 RC1: **COMMITTED / BYTE-EQUIVALENT / BEHAVIORALLY PROVEN**
- Production migrations: pending #16
- Production RLS: pending #17
- Production implementation: not started
- Schema freeze: **RC1; NOT v1.0 FINAL**

## 22. Immediate gate

1. Execute #16 — create real production migration baseline and prove representative data preservation/upgrade behavior.
2. Execute #17 — classify every RC1 table and install/prove production-wide tenant RLS with realistic roles.
3. Run independent freeze review across schema, migrations, RLS, security and unresolved readiness/config/legal items.
4. Only then decide `Schema v1.0 FINAL` and create final tag/checkpoint.
5. Continue #6/#7 discovery for the first Glamping Nad Stawem pilot without vendor-modeling OSG Core prematurely.
