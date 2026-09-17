# OSG — Checkpoint 05: Schema v1.0 RC1 Readiness

Data: 2026-09-16
Status: **PRE-FREEZE PROOF COMPLETE / READY FOR RC CONSOLIDATION**
Repo: `dudsi101-svg/osg-operating-system-of-glamping-`
Writer branch: `agent/engineering/clean-load-ci`
Primary proof PR: #13

## 1. Purpose of this checkpoint

This checkpoint closes the stage in which OSG's pre-v1 semantic/schema candidate was converted from reviewed documentation and SQL scaffolds into executable evidence on PostgreSQL 16.

It does **not** declare `Schema v1.0 FINAL`.

The next stage is consolidation: turn the accepted base + patches into one clean Schema v1.0 Candidate, then prove clean-load equivalence, production migrations and upgrade behavior.

## 2. Current verdict

### What is now established

The current pre-v1 patch-chain candidate has executable evidence for its critical invariants:

- tenancy isolation,
- same-tenant Property isolation,
- StaySegment temporal integrity,
- Resource capacity/exclusive concurrency,
- Financial Truth atomic posting,
- POSTED financial immutability,
- FinancialPeriod/HARD_CLOSED behavior,
- command/integration/automation idempotency,
- Settlement conservation,
- Folio currency/refund/close behavior,
- Charge immutability and reversal conservation,
- canonical clean-load and reference scenarios.

### What is not established yet

- one consolidated canonical v1.0 DDL baseline,
- production migration chain,
- tested upgrade path from supported prior schema,
- production-wide RLS rollout for every tenant-owned table,
- independent final freeze review,
- real PMS/bank integration discovery.

Therefore:

> **OSG may enter Schema v1.0 RC consolidation. It may not yet be labelled Schema v1.0 FINAL.**

## 3. Proof baseline

Latest full PostgreSQL proof after the final evidence-backed repair:

- GitHub Actions run: `35093917785`
- PostgreSQL: 16
- result: **PASS**

The run includes:

1. clean database startup,
2. canonical base + accepted pre-v1 patch load,
3. semantic layer load,
4. Glamping Nad Stawem master/reference configuration,
5. numbered business scenarios,
6. SQL invariant suites,
7. true-concurrency Python integration tests,
8. runtime-role RLS proof,
9. final smoke queries,
10. retained proof log artifact.

## 4. Closed execution gates

- Issue #1 — StaySegment overlap proof — PASS / CLOSED
- Issue #2 — Resource concurrency — PASS / CLOSED
- Issue #3 — Atomic Financial Truth posting — PASS / CLOSED
- Issue #4 — Tenant isolation — PASS / CLOSED
- Issue #5 — Integration/automation/command idempotency — PASS / CLOSED
- Issue #8 — Canonical clean-load/reference scenarios — PASS / CLOSED
- Issue #9 — Same-tenant cross-Property guards — PASS / CLOSED
- Issue #10 — Folio balance/currency/refund invariants — PASS / CLOSED
- Issue #11 — Charge immutability/reversal invariants — PASS / CLOSED
- Issue #14 — Settlement conservation under concurrency — PASS / CLOSED

External discovery remains intentionally open:

- Issue #6 — real PMS/reservation/channel flow
- Issue #7 — first bank/cash import path

## 5. Evidence-backed defects found during proof

### DEFECT-01 — semantic SQL ordering
A PostgreSQL-resolvable output-order issue existed in `osg_semantic_operations_v0.1.sql`.

Resolution: corrected and rerun through full pipeline.

### DEFECT-02 — FinancialPeriod UUID aggregation
Financial period resolution relied on unsupported `min(uuid)`.

Resolution: corrected implementation and rerun.

### DEFECT-03 — EXCLUSIVE Resource concurrency path
Raw concurrent GiST behavior was not an adequate normal-path concurrency contract.

Resolution: Resource row serialization + capacity guard became the normal path; exclusion remains fail-closed defense-in-depth.

### DEFECT-04 — polymorphic ExternalReference tenant hole
`ExternalReference` could belong to ORG_A while its generic `osg_entity_id` targeted a Reservation in ORG_B. Composite FKs cannot protect an unconstrained polymorphic target.

Resolution:
- explicit supported-target tenant lookup,
- fail closed for cross-tenant mapping,
- runtime negative proof added.

Result: ORG_A → ORG_B mapping is rejected.

### DEFECT-05 — concurrent Charge over-reversal race
Sequential Charge reversal conservation was correct, but two concurrent reversal inserts used a shared lock on the original Charge. Two `-600` reversals against original `+1000` could both commit.

Resolution:
- original Charge becomes the aggregate serialization point,
- `FOR SHARE` changed to row-level `FOR UPDATE`,
- no table-wide lock,
- different original Charges remain independent.

Result after rerun:
- exactly one concurrent `-600` commits,
- loser receives `OSG_CHARGE_OVER_REVERSED`,
- cumulative reversal never exceeds original Charge.

## 6. Accepted core invariants entering RC1

### Tenancy

- every tenant-owned fact carries `organization_id`,
- normal runtime access is tenant scoped,
- no tenant context means fail closed,
- polymorphic integration references validate target tenant,
- RLS is defense-in-depth, not the only security boundary.

### Property context

Within one Organization, Property-specific entities cannot silently cross-link between Property A and Property B where business semantics require a single Property context.

Explicit Organization-level facts remain possible.

### Reservation / stay

- commercial Reservation history is separate from physical Stay execution,
- one Stay may contain multiple StaySegments,
- active segments for the same Unit cannot overlap,
- `[start,end)` adjacency is valid,
- historical relocation does not rewrite the original commercial booking.

### Resource capacity

- EXCLUSIVE and capacity resources serialize through the Resource aggregate,
- holds, expiry and buffers are explicit,
- concurrent requests cannot exceed capacity.

### Financial Truth

Accounting/document, CashMovement, EconomicEvent and Allocation remain distinct facts.

POSTED EconomicEvent:
- must be fully allocated,
- is immutable in material meaning,
- belongs to an applicable FinancialPeriod,
- cannot mutate a HARD_CLOSED period in place,
- is corrected through explicit reversal/corrective facts.

### Settlement

`payer != economic_bearer` may create an explicit liability. Settlement application is conserved transactionally and cannot be double-used under concurrent repayment attempts.

### Folio / commerce

- Charges, Payments and Refunds retain history,
- Folio currency is coherent,
- confirmed Refund cannot exceed Payment,
- CLOSED Folio requires effectively zero commercial balance,
- reopen is controlled,
- full cancellation/refund unwinds obligation without inventing a second OPEX.

### Charge correction

- final Charge is immutable,
- no mutable `REVERSED` state,
- correction is an explicit linked Charge,
- reversal stays on the same Folio,
- reversal sign opposes original,
- partial reversals may sum to original but never exceed it,
- concurrent reversals serialize on the original Charge.

### Idempotency

Retry/replay is a normal operating condition:
- PMS duplicate deliveries,
- commands,
- Financial posting,
- automation execution
must resolve to one intended business effect.

## 7. Glamping Nad Stawem reference implementation status

The reference tenant remains configuration/fixture data rather than hardcoded OSG Core semantics.

Reference configuration covers the current property model including Units such as Forest, Boho, Loft, Ostoja and Aura plus shared Resources/services used by the executable scenarios.

No real guest PII or production bank credentials belong in reference fixtures.

## 8. RC1 consolidation rules

The consolidation stage must not redesign already-proven semantics without a new explicit decision/gate.

Rules:

1. consolidate accepted behavior, do not re-invent the domain model;
2. preserve historical patch files as architecture-evolution evidence until final promotion;
3. remove duplicate/replaced trigger/function definitions from the consolidated baseline;
4. consolidated schema must reproduce the same accepted constraints/errors/relationships;
5. run the full proof suite against the consolidated candidate itself;
6. generate real migrations separately from the fresh baseline;
7. prove upgrade path with existing data fixtures;
8. writer does not self-merge/finalize without independent review.

## 9. Next execution gates

### RC-001 — Canonical v1.0 Candidate DDL
Create one clean baseline representing the accepted current model.

### RC-002 — Behavioral equivalence
Run complete clean-load/reference/concurrency/RLS/commerce proof against consolidated candidate and compare expected behavior with the accepted patch chain.

### RC-003 — Production migration chain
Create ordered, versioned migrations from the chosen supported starting point.

### RC-004 — Upgrade-path proof
Test migrations on representative pre-v1 data, including financial history, reservations, Folios, settlements and integration references.

### RC-005 — Production-wide RLS coverage
Inventory every tenant-owned table, apply the production tenant policy model and execute automated coverage checks.

### RC-006 — Independent freeze review
Review schema, migrations, evidence log and remaining P1/discovery risks. Only then may `Schema v1.0 FINAL` be considered.

## 10. Explicit non-blockers for schema consolidation

The following remain necessary for production pilot but are not reasons to reopen proven Core entity boundaries unless discovery reveals a genuine missing concept:

- actual PMS/channel provider mapping,
- first bank import adapter,
- exact commission configuration,
- approval amount thresholds,
- CAPEX small-asset threshold,
- retention periods,
- operational policy configuration.

## 11. Handoff instruction

A future engineering session must start from this checkpoint and the current repository state. Do not restart OSG architecture from zero and do not treat old `PENDING_EXECUTION` statements in superseded documents as current truth.

Technical source of truth remains the repository plus the latest green execution evidence. This checkpoint records the transition from **PRE-FREEZE proof** to **Schema v1.0 RC consolidation**.
