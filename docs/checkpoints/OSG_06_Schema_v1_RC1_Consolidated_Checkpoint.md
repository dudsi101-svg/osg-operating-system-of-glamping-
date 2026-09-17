# OSG — Checkpoint 06: Schema v1.0 RC1 Consolidated

Data: 2026-09-16
Status: **SCHEMA v1.0 RC1 CONSOLIDATED / PROVEN / NOT FINAL**

## 1. Stage boundary reached

The pre-freeze base + patch lineage has been consolidated into one deterministic fresh-install database candidate and proven behaviorally equivalent to the accepted lineage.

Canonical candidate:

`database/rc/osg_schema_v1_rc1.sql`

SHA-256:

`4c43fa53da21192b4160936b26770a1d9845acc5780f3d2c4d4b32a0be589f0d`

This is the first point at which OSG has a single executable schema candidate rather than only an ordered development patch chain.

## 2. Evidence chain

### Pre-freeze proof baseline
Full accepted pre-v1 proof after evidence-backed repairs:
- run `35093917785` — PASS.

### Deterministic RC generation + behavioral equivalence
- run `35113431149` — PASS.
- two normalized dumps from the same source were byte-for-byte identical.
- generated RC1 clean-loaded into a second PostgreSQL 16 database.
- source and flattened inventories matched.
- full accepted scenario/invariant/concurrency suite passed.

### Canonical promotion
- promotion run `35113875981` — PASS.
- workflow committed the generated candidate only after the complete proof succeeded.
- promotion commit: `cc775739790937d7e292a1ac36765a71a3376822`.

### Post-promotion drift verification
- run `35114164171` — PASS.
- newly regenerated schema SHA matched the committed RC1 SHA.
- explicit CI evidence: `OSG_RC committed candidate byte-equivalence PASS`.
- full behavior suite passed again against the regenerated/flattened candidate.

## 3. RC1 structural inventory

Source lineage and flattened RC1 matched at proof time:
- 92 ordinary tables,
- 20 views,
- 238 functions,
- 22 non-internal triggers,
- 659 constraints.

Inventory equality is supporting evidence; behavioral and concurrency tests remain authoritative for correctness.

## 4. Important failures discovered and repaired before RC1

RC1 is not merely a documentation consolidation. Executable gates found real defects, including:
- cross-tenant ExternalReference target hole;
- concurrent Charge over-reversal race caused by a shared lock on the original Charge.

The Charge race was repaired by serializing reversals on the original Charge using an exclusive row lock; true-concurrency proof now yields exactly one winning over-limit contender and stable `OSG_CHARGE_OVER_REVERSED` for the loser.

## 5. Runtime vs proof boundary

The explicit classification is recorded in:

`docs/engineering/OSG_RC1_Database_Function_Promotion_Register_v0.1.md`

Promoted runtime-candidate functions include:
- `osg_assert_payment_not_overallocated(...)`,
- `osg_assert_settlement_not_overapplied(...)`,
- `osg_assert_resource_capacity(...)`,
- `osg_post_economic_event_v02(...)`.

`osg_charge_applied_amount(...)` remains an included read/derivation helper.

Historical `database/proof/tenant_rls_v0.1.sql` is **not** promoted as the production RLS baseline.

## 6. What RC1 proves

RC1 has executable evidence for:
- clean schema load,
- StaySegment overlap prevention,
- Resource exclusive/capacity concurrency,
- atomic Financial Truth posting,
- allocation conservation,
- immutable POSTED financial facts,
- explicit financial reversals,
- FinancialPeriod assignment and HARD_CLOSED behavior,
- command/integration/automation idempotency,
- cross-tenant and cross-Property integrity on proven paths,
- settlement conservation under true concurrency,
- Folio currency/refund/close behavior,
- immutable final Charges and explicit Charge reversal conservation,
- concurrent Charge over-reversal protection,
- reference Glamping Nad Stawem scenarios/configuration.

## 7. What RC1 does NOT prove / contain

RC1 must not be described as production-final because these gates remain:

### #16 — production migration baseline + data-preserving upgrade path
Need real ordered production migrations, deterministic migration metadata/checksums, fresh-install proof and representative existing-data preservation proof.

### #17 — production-wide RLS coverage
Need machine-generated tenant table inventory, production DB role model and complete policy coverage. Current selective runtime-role proof is not sufficient for production rollout.

### Independent freeze review
A separate review must inspect the resulting migration/RLS package and unresolved P1/config/legal items before FINAL.

### External discovery
Still open:
- #6 actual PMS/reservation/channel flow,
- #7 first bank/cash import path.

These are pilot/integration blockers unless they reveal a genuinely missing Core concept; they do not by themselves invalidate RC1.

## 8. Change control from this checkpoint

Do not edit `database/rc/osg_schema_v1_rc1.sql` manually as an ordinary development file.

Any intentional semantic schema change must:
1. identify the business/invariant reason;
2. update the accepted source lineage or successor migration intentionally;
3. regenerate/review the candidate;
4. pass behavioral/concurrency proof;
5. update the candidate/hash/checkpoint if the RC version changes.

Current CI fails when committed RC1 differs byte-for-byte from the deterministic schema generated from the accepted lineage.

## 9. Immediate execution order

1. Execute Issue #16: production migration baseline and data-preservation proof.
2. Execute Issue #17: complete production RLS policy and coverage proof.
3. Run independent freeze review across schema, migrations, security and unresolved readiness items.
4. Only then decide whether to declare `Schema v1.0 FINAL` and create the final tag/checkpoint.

## 10. Handoff instruction

Do **not** restart OSG schema design from scratch.

Treat `database/rc/osg_schema_v1_rc1.sql` plus this checkpoint as the current database source-of-truth candidate. Historical base/patch/proof files remain evolution and regeneration evidence. Continue by proving the migration and security packaging around the already-proven semantics.
