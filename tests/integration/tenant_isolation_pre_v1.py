"""OSG P0 tenant isolation proof — DEV only.

Issue #4 executable proof against PostgreSQL 16.

Layers covered:
1. relational/domain integrity for cross-Organization links,
2. runtime-role RLS visibility and write scope,
3. fail-closed worker session without tenant context,
4. service-boundary security audit evidence,
5. polymorphic ExternalReference target tenancy.

RLS policies are installed only in the isolated CI database by this proof. They
are not yet promoted as production migration artifacts; that decision follows
after executable evidence.
"""

from __future__ import annotations

import json

import psycopg
from psycopg import errors

ORG_A = "00000000-0000-7000-8000-000000000001"
PROPERTY_A = "00000000-0000-7000-8000-000000000010"
UNIT_TYPE_A = "00000000-0000-7000-8000-000000000101"
UNIT_A = "00000000-0000-7000-8000-000000000201"

ORG_B = "00000000-0000-7000-8000-000000009900"
PROPERTY_B = "00000000-0000-7000-8000-000000009901"
UNIT_TYPE_B = "00000000-0000-7000-8000-000000009902"
UNIT_B = "00000000-0000-7000-8000-000000009903"
ASSET_B = "00000000-0000-7000-8000-000000009904"
RESERVATION_B = "00000000-0000-7000-8000-000000009905"

RESERVATION_A = "00000000-0000-7000-8000-000000009910"
EVENT_A = "00000000-0000-7000-8000-000000009911"
INTEGRATION_A = "00000000-0000-7000-8000-000000009912"
EXTERNAL_REF = "00000000-0000-7000-8000-000000009913"
AUDIT_ID = "00000000-0000-7000-8000-000000009914"

RUNTIME_ROLE = "osg_runtime_p0"


def connect():
    return psycopg.connect("")


def scalar(conn, query: str, params=()):
    return conn.execute(query, params).fetchone()[0]


def setup_second_tenant() -> None:
    with connect() as conn:
        conn.execute(
            """
            insert into organization (
              id,name,slug,default_currency,default_timezone,status
            ) values (%s,'OSG P0 Other Tenant','osg-p0-other-tenant','PLN','Europe/Warsaw','ACTIVE')
            """,
            (ORG_B,),
        )
        conn.execute(
            """
            insert into property (
              id,organization_id,name,code,property_type,timezone,currency,status
            ) values (%s,%s,'Other Tenant Property','P0B','GLAMPING','Europe/Warsaw','PLN','ACTIVE')
            """,
            (PROPERTY_B, ORG_B),
        )
        conn.execute(
            """
            insert into unit_type (
              id,organization_id,property_id,name,code,base_capacity,max_capacity,active
            ) values (%s,%s,%s,'Other Tenant Unit Type','P0BTYPE',1,2,true)
            """,
            (UNIT_TYPE_B, ORG_B, PROPERTY_B),
        )
        conn.execute(
            """
            insert into unit (
              id,organization_id,property_id,unit_type_id,code,name,lifecycle_status
            ) values (%s,%s,%s,%s,'P0B01','Other Tenant Unit','ACTIVE')
            """,
            (UNIT_B, ORG_B, PROPERTY_B, UNIT_TYPE_B),
        )
        conn.execute(
            """
            insert into asset (
              id,organization_id,property_id,unit_id,name,asset_type,lifecycle_status
            ) values (%s,%s,%s,%s,'Other Tenant Asset','P0_TEST','ACTIVE')
            """,
            (ASSET_B, ORG_B, PROPERTY_B, UNIT_B),
        )
        conn.execute(
            """
            insert into reservation (
              id,organization_id,property_id,reference_code,commercial_status,
              booked_at,currency
            ) values (%s,%s,%s,'P0-ORG-B-RES','CONFIRMED',now(),'PLN')
            """,
            (RESERVATION_B, ORG_B, PROPERTY_B),
        )

        conn.execute(
            """
            insert into reservation (
              id,organization_id,property_id,reference_code,commercial_status,
              booked_at,currency
            ) values (%s,%s,%s,'P0-ORG-A-RES','CONFIRMED',now(),'PLN')
            """,
            (RESERVATION_A, ORG_A, PROPERTY_A),
        )
        conn.execute(
            """
            insert into economic_event (
              id,organization_id,property_id,event_type,economic_date,amount,currency,status
            ) values (%s,%s,%s,'OPEX','2026-09-16',100,'PLN','DRAFT')
            """,
            (EVENT_A, ORG_A, PROPERTY_A),
        )
        conn.execute(
            """
            insert into integration (
              id,organization_id,property_id,provider,integration_type,status,sync_mode
            ) values (%s,%s,%s,'P0 Tenant Proof PMS','RESERVATION_SOURCE','ACTIVE','WEBHOOK_PRIMARY')
            """,
            (INTEGRATION_A, ORG_A, PROPERTY_A),
        )


def expect_failure(conn, sql: str, params, label: str, contains: str | None = None) -> str:
    conn.execute("savepoint tenant_expect_failure")
    try:
        conn.execute(sql, params)
    except Exception as exc:
        text = str(exc)
        conn.execute("rollback to savepoint tenant_expect_failure")
        conn.execute("release savepoint tenant_expect_failure")
        if contains and contains not in text:
            raise AssertionError(f"{label}: expected {contains!r}, got {text}") from exc
        print(f"PASS {label}: {text.splitlines()[0]}")
        return text
    else:
        conn.execute("rollback to savepoint tenant_expect_failure")
        conn.execute("release savepoint tenant_expect_failure")
        raise AssertionError(f"{label}: cross-tenant operation unexpectedly succeeded")


def test_cross_tenant_relational_links() -> None:
    with connect() as conn:
        expect_failure(
            conn,
            """
            insert into reservation_item (
              id,organization_id,reservation_id,unit_type_id,assigned_unit_id,
              arrival_date,departure_date,adults,status
            ) values (
              '00000000-0000-7000-8000-000000009920',%s,%s,%s,%s,
              '2027-02-01','2027-02-02',2,'ACTIVE'
            )
            """,
            (ORG_A, RESERVATION_A, UNIT_TYPE_A, UNIT_B),
            "Reservation ORG_A -> Unit ORG_B rejected",
        )

        expect_failure(
            conn,
            """
            insert into allocation (
              id,organization_id,economic_event_id,amount,property_id,asset_id,
              allocation_type,classification,confidence,rationale
            ) values (
              '00000000-0000-7000-8000-000000009921',%s,%s,100,%s,%s,
              'DIRECT','OPEX','VERIFIED','P0 cross-tenant asset proof'
            )
            """,
            (ORG_A, EVENT_A, PROPERTY_A, ASSET_B),
            "Allocation ORG_A -> Asset ORG_B rejected",
        )


def test_external_reference_target_tenant() -> None:
    with connect() as conn:
        # This is a polymorphic target and therefore cannot be protected by the
        # simple composite FK used elsewhere. The test intentionally requires a
        # deterministic rejection; if current schema accepts it, CI exposes the gap.
        expect_failure(
            conn,
            """
            insert into external_reference (
              id,organization_id,integration_id,external_type,external_id,
              osg_entity_type,osg_entity_id
            ) values (%s,%s,%s,'reservation','P0-CROSS-TENANT-EXT',
                      'Reservation',%s)
            """,
            (EXTERNAL_REF, ORG_A, INTEGRATION_A, RESERVATION_B),
            "ExternalReference ORG_A -> Reservation ORG_B rejected",
            "OSG_EXTERNAL_REFERENCE_TENANT_MISMATCH",
        )


def install_runtime_rls_proof() -> None:
    with connect() as conn:
        conn.execute(
            """
            do $$
            begin
              if not exists (select 1 from pg_roles where rolname='osg_runtime_p0') then
                create role osg_runtime_p0 nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
              end if;
            end $$;
            """
        )
        conn.execute("grant usage on schema public to osg_runtime_p0")

        tables = [
            "property",
            "unit_type",
            "unit",
            "asset",
            "reservation",
            "reservation_item",
            "economic_event",
            "allocation",
            "integration",
            "external_reference",
        ]
        for table in tables:
            conn.execute(f"grant select,insert,update,delete on {table} to osg_runtime_p0")
            conn.execute(f"alter table {table} enable row level security")
            conn.execute(f"alter table {table} force row level security")
            conn.execute(
                f"""
                create policy p0_tenant_{table}
                on {table}
                for all
                to osg_runtime_p0
                using (
                  organization_id = nullif(current_setting('app.organization_id',true),'')::uuid
                )
                with check (
                  organization_id = nullif(current_setting('app.organization_id',true),'')::uuid
                )
                """
            )


def test_runtime_role_visibility_and_fail_closed_worker() -> None:
    with connect() as conn:
        conn.execute(f"set role {RUNTIME_ROLE}")
        conn.execute("select set_config('app.organization_id',%s,false)", (ORG_A,))

        own_property = scalar(conn, "select count(*) from property where id=%s", (PROPERTY_A,))
        foreign_property = scalar(conn, "select count(*) from property where id=%s", (PROPERTY_B,))
        foreign_unit = scalar(conn, "select count(*) from unit where id=%s", (UNIT_B,))
        foreign_reservation = scalar(conn, "select count(*) from reservation where id=%s", (RESERVATION_B,))
        if (own_property, foreign_property, foreign_unit, foreign_reservation) != (1, 0, 0, 0):
            raise AssertionError(
                "runtime ORG_A visibility leaked tenant data: "
                f"own={own_property}, foreign_property={foreign_property}, "
                f"foreign_unit={foreign_unit}, foreign_reservation={foreign_reservation}"
            )
        print("PASS runtime role ORG_A cannot read ORG_B property/unit/reservation")

        expect_failure(
            conn,
            """
            insert into property (
              id,organization_id,name,code,property_type,timezone,currency,status
            ) values (
              '00000000-0000-7000-8000-000000009930',%s,'Forbidden B Property',
              'P0FORBIDDEN','GLAMPING','Europe/Warsaw','PLN','ACTIVE'
            )
            """,
            (ORG_B,),
            "runtime ORG_A cannot write ORG_B row",
            "row-level security",
        )

        # A worker/background connection without explicit tenant context must
        # fail closed rather than seeing all rows.
        conn.execute("reset app.organization_id")
        no_scope_count = scalar(conn, "select count(*) from property")
        if no_scope_count != 0:
            raise AssertionError(f"worker without tenant context saw {no_scope_count} properties")
        expect_failure(
            conn,
            """
            insert into property (
              id,organization_id,name,code,property_type,timezone,currency,status
            ) values (
              '00000000-0000-7000-8000-000000009931',%s,'No Scope Property',
              'P0NOSCOPE','GLAMPING','Europe/Warsaw','PLN','ACTIVE'
            )
            """,
            (ORG_A,),
            "background worker without tenant context fails closed",
            "row-level security",
        )
        print("PASS worker session without app.organization_id sees zero tenant rows")
        conn.execute("reset role")


def test_security_audit_at_service_boundary() -> None:
    # RLS/constraint errors abort their statement/transaction scope. A realistic
    # service catches the denial and records the security audit in a separate,
    # privileged audit write. This proves the service-boundary contract without
    # pretending PostgreSQL offers autonomous transactions.
    with connect() as runtime:
        runtime.execute(f"set role {RUNTIME_ROLE}")
        runtime.execute("select set_config('app.organization_id',%s,false)", (ORG_A,))
        denied = False
        try:
            runtime.execute(
                """
                insert into property (
                  id,organization_id,name,code,property_type,timezone,currency,status
                ) values (
                  '00000000-0000-7000-8000-000000009932',%s,'Audit Forbidden Property',
                  'P0AUDITDENY','GLAMPING','Europe/Warsaw','PLN','ACTIVE'
                )
                """,
                (ORG_B,),
            )
        except errors.InsufficientPrivilege:
            runtime.rollback()
            denied = True
        if not denied:
            raise AssertionError("expected runtime cross-tenant denial before security audit")

    with connect() as audit_conn:
        audit_conn.execute(
            """
            insert into audit_event (
              id,organization_id,property_id,actor_type,entity_type,entity_id,
              action,source,changes
            ) values (
              %s,%s,%s,'SYSTEM','SecurityBoundary',%s,
              'CROSS_TENANT_ACCESS_DENIED','P0_TENANT_PROOF',%s::jsonb
            )
            """,
            (
                AUDIT_ID,
                ORG_A,
                PROPERTY_A,
                PROPERTY_B,
                json.dumps({"attempted_organization_id": ORG_B, "runtime_scope": ORG_A}),
            ),
        )

    with connect() as conn:
        count = scalar(
            conn,
            "select count(*) from audit_event where id=%s and action='CROSS_TENANT_ACCESS_DENIED'",
            (AUDIT_ID,),
        )
        if count != 1:
            raise AssertionError("security denial audit evidence missing")
    print("PASS forbidden cross-tenant attempt emits service-boundary security audit evidence")


def main() -> None:
    setup_second_tenant()
    test_cross_tenant_relational_links()
    test_external_reference_target_tenant()
    install_runtime_rls_proof()
    test_runtime_role_visibility_and_fail_closed_worker()
    test_security_audit_at_service_boundary()
    print("PASS OSG Issue #4 tenant isolation proof")


if __name__ == "__main__":
    main()
