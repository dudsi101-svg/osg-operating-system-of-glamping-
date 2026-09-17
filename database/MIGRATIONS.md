# OSG — Database Migration Policy v0.2

Date: 2026-09-16
Status: RC / production-baseline policy

## 1. Supported production baseline

The first supported OSG production database baseline is **Schema v1.0**.

Current source candidate for that baseline:
- `database/rc/osg_schema_v1_rc1.sql`
- RC1 SHA-256: `4c43fa53da21192b4160936b26770a1d9845acc5780f3d2c4d4b32a0be589f0d`

The historical v0.95/pre-v1 base+patch chain is **development lineage and proof evidence**, not a previously released production version. We do not manufacture a fake historical production migration chain from DEV filenames.

Representative pre-v1 data will still be used as a preservation/normalization test input before FINAL.

## 2. Principles

1. Migrations are append-only after merge to `main`.
2. Never edit an applied migration. Add a forward migration instead.
3. Every breaking schema change requires ADR or explicit schema review plus migration plan.
4. Destructive changes use expand → migrate → validate → switch → contract.
5. Data migrations are separate from schema migrations when practical.
6. Correct forward recovery is preferred over fake reversibility.
7. Production migrations run only after staging success and backup/recovery verification.
8. Migration order and file checksum are part of the production contract.
9. One migration cannot silently change after it has been recorded as applied.
10. Posted financial/history facts must never be rewritten merely to simplify a schema migration.

## 3. Naming and ordering

Canonical migration directory:

`database/migrations/`

File naming:

`YYYYMMDDHHMM_<scope>_<description>.sql`

Lexicographic filename order is execution order.

The first baseline migration is generated from the proven RC1 DDL and reviewed as an immutable production baseline candidate.

Examples for later releases:
- `202609171000_security_enable_tenant_rls.sql`
- `202609181230_guest_add_identity_index.sql`

## 4. Deterministic checksums

`database/migrations/CHECKSUMS.sha256` is the repository checksum manifest.

CI must verify:
- every executable `.sql` migration is listed exactly once;
- every listed migration exists;
- `sha256sum -c` succeeds;
- no unlisted migration is executable by the runner.

At runtime the migration ledger stores the migration filename and SHA-256 used when the migration was applied.

If the same filename is already recorded with a different checksum, execution fails closed.

## 5. Database migration ledger

The migration runner owns one global infrastructure table:

`osg_schema_migration`

Minimum fields:
- `migration_name text primary key`
- `checksum_sha256 text not null`
- `applied_at timestamptz not null default now()`

This is a global deployment/system table, not tenant business data. It is intentionally outside Organization-level RLS semantics.

The runner must use a PostgreSQL advisory lock so two deployers cannot apply the same migration chain concurrently.

## 6. Transaction policy

Default: each migration is applied atomically in one transaction together with its migration-ledger insert.

If a future migration requires PostgreSQL operations that cannot run inside a transaction (for example some concurrent index operations), it must use an explicit reviewed non-transactional migration contract. Do not silently weaken the default runner.

The v1 baseline is required to run transactionally.

## 7. RC1 → production baseline generation

The RC1 file is a normalized `pg_dump --schema-only` artifact. Its only `psql` meta commands are the deterministic `\restrict` / `\unrestrict` guard lines.

The production baseline generator removes **only** those two meta-command lines and otherwise preserves the proven RC1 DDL byte-for-byte.

The generator must fail if any other backslash/meta command appears. This prevents accidental reliance on interactive `psql` behavior.

The generated baseline is then tested from an empty PostgreSQL 16 database through the production migration runner.

## 8. Fresh-install gate

Before production baseline acceptance:
1. empty PostgreSQL 16 database;
2. initialize migration ledger;
3. apply all migrations through the production runner;
4. verify migration ledger/checksums;
5. compare resulting business schema with RC1, excluding migration infrastructure intentionally added by the runner;
6. load Glamping Nad Stawem reference configuration;
7. execute business scenarios;
8. execute full invariant/concurrency proof suite.

## 9. Existing-data preservation gate

Even though pre-v1 is not a supported production release, RC freeze must prove that representative lineage data is not semantically lost.

Required representative history includes:
- Reservation/Stay/StaySegments;
- Folio/final Charge/Charge reversal;
- Payment/Refund;
- POSTED EconomicEvent/Allocation;
- FinancialPeriod including closed history;
- SettlementEntry/SettlementApplication;
- ExternalReference;
- guest identity/alias provenance;
- CAPEX/OPEX and operator-funded expense cases.

Before/after checks must preserve:
- stable IDs and links;
- immutable posted financial history;
- commercial history and explainability;
- settlement conservation;
- tenant ownership;
- key semantic projections/fingerprints.

No real guest PII or credentials are used in this fixture.

## 10. Expand-contract example

Old: `guest_name`
New: structured Party/Guest fields

1. expand with new fields/table;
2. dual write if needed;
3. backfill under an explicit data migration;
4. validate counts/fingerprints;
5. switch reads;
6. stop old writes;
7. remove old field only in a later reviewed migration.

## 11. Migration gates

Before merge:
- deterministic checksum manifest;
- syntax validation;
- empty database apply through production runner;
- previous supported schema upgrade apply when one exists;
- representative DEV-lineage data-preservation proof during v1 freeze;
- invariant/concurrency tests;
- reference seed/scenario apply.

Before PROD:
- staging migration success;
- current backup exists;
- recovery path documented and tested at the required release level;
- expected lock duration assessed;
- monitoring/health checks ready.

## 12. Tenant safety

Any new tenant-owned table must include `organization_id` and be reviewed for cross-tenant leakage before migration acceptance.

Production-wide RLS is tracked separately under Issue #17. The selective historical proof policy is not automatically copied into the baseline migration.

## 13. Financial safety

Migrations touching POSTED financial facts, final Charges, Payments/Refunds, settled periods or settlement history require explicit review.

Default policy:
- schema migration may add compatible representation/indexes/constraints;
- historical material facts remain immutable;
- corrections remain new linked business facts, not migration-time edits;
- any unavoidable historical data transformation requires a dedicated data migration, before/after fingerprint, reconciliation evidence and rollback/forward-fix plan.

## 14. Current gate

Issue #16 owns:
- baseline migration generation,
- migration runner/ledger,
- checksum enforcement,
- empty-DB migration proof,
- representative data-preservation proof.

Passing Issue #16 is necessary but not sufficient for `Schema v1.0 FINAL`; Issue #17 production RLS and independent freeze review remain separate gates.
