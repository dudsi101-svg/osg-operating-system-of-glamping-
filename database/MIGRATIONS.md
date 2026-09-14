# OSG — Database Migration Policy v0.1

## Principles

1. Migrations are append-only after merge to main.
2. Never edit an applied production migration.
3. Every breaking schema change requires ADR and migration plan.
4. Destructive changes use expand → migrate → contract.
5. Data migrations are separate from schema migrations when practical.
6. Each migration must be reversible where reasonably possible, but correctness is preferred over fake reversibility.
7. Production migrations run only after staging success and backup verification.

## Naming

`YYYYMMDDHHMM_<scope>_<description>.sql`

Examples:
- `202609141700_core_create_organizations.sql`
- `202609141710_property_create_units.sql`
- `202609141720_finance_create_economic_events.sql`

## Expand-contract example

Old: `guest_name`
New: structured Party/Guest fields

1. add new fields/table
2. dual write
3. backfill
4. validate
5. switch reads
6. stop old writes
7. remove old field in later release

## Migration gates

Before merge:
- syntax validation
- clean database apply
- previous schema upgrade apply
- invariant tests
- seed/reference dataset apply

Before PROD:
- staging migration success
- current backup exists
- recovery path documented
- expected lock duration assessed
- monitoring ready

## Tenant safety

Any new tenant-owned table must include organization_id and be reviewed for cross-tenant leakage before migration acceptance.

## Financial safety

Migrations touching posted financial facts require explicit review and must preserve auditability and historical explainability.
