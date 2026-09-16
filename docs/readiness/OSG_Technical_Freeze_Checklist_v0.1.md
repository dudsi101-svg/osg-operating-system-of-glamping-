# OSG — Technical Freeze Checklist v0.1

Status: P0 PROOF COMPLETE / FINAL FREEZE PENDING CONSOLIDATION
Data aktualizacji: 2026-09-16

## P0 — executable pre-freeze proof gates

- [x] StaySegment exclusion constraint executed successfully in PostgreSQL
- [x] Resource capacity race-condition test passes under concurrent writes
- [x] EconomicEvent posting transaction passes full-allocation, rollback, closed-period and tenant tests
- [x] Posted financial immutability enforced and tested
- [x] Settlement over-application prevented transactionally, including true concurrency
- [x] Cross-tenant leakage suite green with realistic runtime-role RLS/fail-closed worker behavior
- [x] Integration/command/automation idempotency and one-business-effect retry behavior green
- [x] Reference seed loads on clean schema
- [x] 12 numbered reference scenarios/gates executable against the PostgreSQL harness
- [x] Same-tenant cross-Property context guards executed
- [x] Folio currency/refund/zero-balance close/controlled-reopen invariants executed
- [x] Final Charge immutability and explicit reversal conservation executed, including concurrent reversals

Latest full proof: GitHub Actions run `35093917785` — PASS on PostgreSQL 16.

## Evidence-backed defects found by executable proof

The harness is not only a smoke test. It has already exposed real defects that documentation review did not catch:

1. PostgreSQL-resolvable ordering issue in `osg_semantic_operations_v0.1.sql`.
2. Unsupported `min(uuid)` in FinancialPeriod resolution.
3. EXCLUSIVE Resource normal path required serialized Resource locking rather than relying only on concurrent GiST behavior.
4. Polymorphic `ExternalReference` allowed an ORG_A mapping to target an ORG_B entity; fixed with a fail-closed tenant-target guard.
5. Two concurrent Charge reversals could both observe the same reversible balance under `FOR SHARE`; fixed by serializing reversals on the original Charge with row-level `FOR UPDATE`.

All fixes were rerun through the full clean-load/scenario/invariant pipeline.

## Pre-v1 technical proof verdict

**PASS.** The current patch-chain candidate has executable evidence for the critical model/concurrency/isolation invariants.

This is not equivalent to `Schema v1.0 FINAL`.

Before FINAL, the accepted patch chain must still be converted into a clean implementation baseline and validated as a deliverable migration path.

## RC / consolidation gates — required before Schema v1.0 FINAL

- [ ] Consolidate accepted v0.95 + pre-v1 patches into one canonical `Schema v1.0 Candidate` DDL baseline
- [ ] Prove clean-load equivalence of consolidated candidate against the accepted patch-chain behavior
- [ ] Define real versioned production migrations
- [ ] Execute upgrade-path migration test, not only fresh-schema load
- [ ] Apply/test production-wide tenant RLS policy coverage for all tenant-owned tables
- [ ] Run regression suite against consolidated candidate/migration chain
- [ ] Independent review of PR #13 / schema candidate
- [ ] Pin Schema/Semantic/Metric versions and create final checkpoint/tag only after the above are green

## P1 — required before production pilot

- [ ] Real reservation/PMS/channel source identified (#6)
- [ ] First integration adapter contract validated against a sanitized real payload/export
- [ ] First bank/cash import path identified and mapped (#7)
- [ ] Cancellation/no-show rules configured from actual commercial policy
- [ ] Deposit/prepayment rules configured from actual commercial policy
- [ ] Approval thresholds configured
- [ ] Period-close operating policy configured
- [ ] CAPEX small-asset threshold configured
- [ ] Privacy retention policy legally/accountingly reviewed
- [ ] Audit redaction policy implemented before real PII
- [ ] Backup and recovery drill passed
- [ ] Staging environment deployed

## Canonical artifacts

Architecture:
- `OSG_Implementation_Architecture_v0.1.md`
- `OSG_Aggregate_and_Concurrency_Model_v0.1.md`
- `OSG_Property_Context_Integrity_v0.1.md`
- ADR-001..011

Domain:
- `OSG_M2_Relationship_Map_v0.2.md`
- `OSG_Canonical_Entity_Catalog_v0.95.md`
- `OSG_M3_Business_Rules_Catalog_v0.2.md`
- `OSG_State_Machines_v0.1.md`

Finance / Commerce:
- `OSG_M5_Financial_Truth_Specification_v0.1.md`
- `OSG_Financial_Truth_Reports_v0.1.md`
- `OSG_Financial_Invariants_v0.1.md`
- `OSG_Folio_Close_and_Balance_Contract_v0.1.md`
- `OSG_Charge_Correction_Contract_v0.1.md`

Validation:
- `.github/workflows/osg-pre-v1-clean-load.yml`
- `tests/integration/`
- `tests/sql/`
- `database/proof/`
- `OSG_End_to_End_Scenarios_v0.1.md`
- `OSG_CI_and_Test_Strategy_v0.1.md`

## Rule

Schema v1.0 FINAL cannot be declared from documentation review or from fresh clean-load alone. It requires executable proof of invariants **and** a green consolidated schema + real migration/upgrade path.
