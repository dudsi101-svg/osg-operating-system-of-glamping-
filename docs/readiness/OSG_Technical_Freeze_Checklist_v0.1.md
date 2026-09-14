# OSG — Technical Freeze Checklist v0.1

Status: ACTIVE
Data: 2026-09-14

## P0 — must pass before Schema v1.0 FINAL

- [ ] StaySegment exclusion constraint executed successfully in PostgreSQL
- [ ] Resource capacity race-condition test passes under concurrent writes
- [ ] EconomicEvent posting transaction passes full-allocation and tenant tests
- [ ] Posted financial immutability enforced and tested
- [ ] Settlement over-application prevented transactionally
- [ ] Cross-tenant leakage test suite green
- [ ] Event outbox idempotency/retry test green
- [ ] Reference seed loads on clean schema
- [ ] 12 canonical end-to-end scenarios executable against test harness

## P1 — required before production pilot

- [ ] Real reservation source identified
- [ ] First integration adapter contract validated
- [ ] Cancellation/no-show rules configured
- [ ] deposit/prepayment rules configured
- [ ] approval thresholds configured
- [ ] period-close policy configured
- [ ] CAPEX small-asset threshold configured
- [ ] privacy retention policy reviewed
- [ ] backup and recovery drill passed
- [ ] staging environment deployed

## Canonical artifacts

Architecture:
- OSG_Implementation_Architecture_v0.1.md
- ADR-001..006

Domain:
- OSG_M2_Relationship_Map_v0.2.md
- OSG_M3_Business_Rules_Catalog_v0.2.md
- OSG_State_Machines_v0.1.md

Finance:
- OSG_M5_Financial_Truth_Specification_v0.1.md
- OSG_Financial_Truth_Reports_v0.1.md

Contracts:
- OSG_OpenAPI_Skeleton_v0.1.yaml
- OSG_Command_Contracts_v0.1.md
- Domain Event schemas

Validation:
- OSG_End_to_End_Scenarios_v0.1.md
- OSG_CI_and_Test_Strategy_v0.1.md
- PostgreSQL proof files

## Rule

Schema v1.0 FINAL cannot be declared from documentation review alone. P0 items require executable proof.
