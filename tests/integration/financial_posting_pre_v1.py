"""OSG P0 Financial Truth posting proof — DEV only.

Covers the DB-backed core of Issue #3:
- balanced atomic posting + DomainEvent/Outbox evidence
- unbalanced rollback
- cross-property/cross-tenant allocation rejection
- posted event/allocation immutability
- reversal via separate corrective record
- HARD_CLOSED period rejection
- concurrent duplicate posting attempt -> one committed effect

Command-idempotency replay semantics remain covered by the dedicated idempotency P0 gate.
"""

from __future__ import annotations

import threading
import time
from dataclasses import dataclass

import psycopg
from psycopg import errors

ORG = "00000000-0000-7000-8000-000000000001"
PROPERTY = "00000000-0000-7000-8000-000000000010"
PERIOD_SEP = "00000000-0000-7000-8000-000000000722"


def connect():
    return psycopg.connect("")


def insert_event(conn, event_id: str, amount: int, *, date: str = "2026-09-15", event_type: str = "OPEX", effect_direction: str = "NORMAL", reverses_event_id: str | None = None) -> None:
    conn.execute(
        """
        insert into economic_event (
          id,organization_id,property_id,event_type,economic_date,amount,currency,
          effect_direction,reverses_event_id,status
        ) values (%s,%s,%s,%s,%s,%s,'PLN',%s,%s,'DRAFT')
        """,
        (event_id, ORG, PROPERTY, event_type, date, amount, effect_direction, reverses_event_id),
    )


def insert_allocation(conn, allocation_id: str, event_id: str, amount: int, *, property_id: str = PROPERTY, classification: str = "OPEX") -> None:
    conn.execute(
        """
        insert into allocation (
          id,organization_id,economic_event_id,amount,property_id,
          allocation_type,classification,confidence,allocation_method,rationale
        ) values (%s,%s,%s,%s,%s,'DIRECT',%s,'VERIFIED','P0_PROOF','P0 Financial posting proof')
        """,
        (allocation_id, ORG, event_id, amount, property_id, classification),
    )


def post(conn, event_id: str, domain_event_id: str, outbox_id: str) -> None:
    conn.execute(
        "select osg_post_economic_event_v02(%s,%s,%s,%s,%s)",
        (ORG, event_id, None, domain_event_id, outbox_id),
    )


def scalar(conn, query: str, params=()):
    return conn.execute(query, params).fetchone()[0]


def expect_raise(conn, sql: str, params, expected: str, label: str) -> None:
    conn.execute("savepoint p0_expect")
    try:
        conn.execute(sql, params)
    except errors.RaiseException as exc:
        text = str(exc)
        conn.execute("rollback to savepoint p0_expect")
        conn.execute("release savepoint p0_expect")
        if expected not in text:
            raise AssertionError(f"{label}: expected {expected}, got {text}") from exc
        print(f"PASS {label}: {expected}")
        return
    except Exception:
        conn.execute("rollback to savepoint p0_expect")
        conn.execute("release savepoint p0_expect")
        raise
    else:
        conn.execute("release savepoint p0_expect")
        raise AssertionError(f"{label}: expected error {expected}")


def test_balanced_atomic_post() -> None:
    event_id = "00000000-0000-7000-8000-000000009400"
    alloc_id = "00000000-0000-7000-8000-000000009401"
    domain_id = "00000000-0000-7000-8000-000000009402"
    outbox_id = "00000000-0000-7000-8000-000000009403"

    conn = connect()
    try:
        insert_event(conn, event_id, 100)
        insert_allocation(conn, alloc_id, event_id, 100)
        post(conn, event_id, domain_id, outbox_id)

        row = conn.execute(
            "select status,financial_period_id,row_version from economic_event where id=%s",
            (event_id,),
        ).fetchone()
        if row[0] != "POSTED" or str(row[1]) != PERIOD_SEP or row[2] < 2:
            raise AssertionError(f"balanced post invalid event state: {row}")
        if scalar(conn, "select count(*) from domain_event where id=%s", (domain_id,)) != 1:
            raise AssertionError("balanced post missing DomainEvent")
        if scalar(conn, "select count(*) from outbox_event where id=%s and domain_event_id=%s", (outbox_id, domain_id)) != 1:
            raise AssertionError("balanced post missing Outbox")
        print("PASS balanced atomic post + period assignment + DomainEvent + Outbox")
    finally:
        conn.rollback()
        conn.close()


def test_unbalanced_rolls_back_post_effects() -> None:
    event_id = "00000000-0000-7000-8000-000000009410"
    alloc_id = "00000000-0000-7000-8000-000000009411"
    domain_id = "00000000-0000-7000-8000-000000009412"
    outbox_id = "00000000-0000-7000-8000-000000009413"

    conn = connect()
    try:
        insert_event(conn, event_id, 100)
        insert_allocation(conn, alloc_id, event_id, 90)
        expect_raise(
            conn,
            "select osg_post_economic_event_v02(%s,%s,%s,%s,%s)",
            (ORG, event_id, None, domain_id, outbox_id),
            "OSG_ALLOCATION_NOT_BALANCED",
            "unbalanced posting rejected",
        )
        row = conn.execute(
            "select status,financial_period_id,posted_at from economic_event where id=%s",
            (event_id,),
        ).fetchone()
        if row != ("DRAFT", None, None):
            raise AssertionError(f"unbalanced failure leaked posting mutation: {row}")
        if scalar(conn, "select count(*) from domain_event where id=%s", (domain_id,)) != 0:
            raise AssertionError("unbalanced failure leaked DomainEvent")
        if scalar(conn, "select count(*) from outbox_event where id=%s", (outbox_id,)) != 0:
            raise AssertionError("unbalanced failure leaked Outbox")
        print("PASS unbalanced posting rolls back all posting effects")
    finally:
        conn.rollback()
        conn.close()


def test_cross_tenant_property_allocation_rejected() -> None:
    event_id = "00000000-0000-7000-8000-000000009420"
    org_b = "00000000-0000-7000-8000-000000009421"
    property_b = "00000000-0000-7000-8000-000000009422"

    conn = connect()
    try:
        conn.execute(
            "insert into organization (id,name,slug,status) values (%s,'P0 Other Org','p0-other-org','ACTIVE')",
            (org_b,),
        )
        conn.execute(
            """
            insert into property (id,organization_id,name,code,status)
            values (%s,%s,'Other Property','P0OTHER','ACTIVE')
            """,
            (property_b, org_b),
        )
        insert_event(conn, event_id, 100)
        expect_raise(
            conn,
            """
            insert into allocation (
              id,organization_id,economic_event_id,amount,property_id,
              allocation_type,classification,confidence
            ) values (
              '00000000-0000-7000-8000-000000009423',%s,%s,100,%s,
              'DIRECT','OPEX','VERIFIED'
            )
            """,
            (ORG, event_id, property_b),
            "PROPERTY_CONTEXT_MISMATCH allocation.property",
            "cross-tenant/property allocation rejected",
        )
        if scalar(conn, "select count(*) from allocation where economic_event_id=%s", (event_id,)) != 0:
            raise AssertionError("cross-tenant allocation was persisted")
    finally:
        conn.rollback()
        conn.close()


def test_posted_immutability_and_reversal() -> None:
    original = "00000000-0000-7000-8000-000000009430"
    original_alloc = "00000000-0000-7000-8000-000000009431"
    original_domain = "00000000-0000-7000-8000-000000009432"
    original_outbox = "00000000-0000-7000-8000-000000009433"
    reversal = "00000000-0000-7000-8000-000000009434"
    reversal_alloc = "00000000-0000-7000-8000-000000009435"
    reversal_domain = "00000000-0000-7000-8000-000000009436"
    reversal_outbox = "00000000-0000-7000-8000-000000009437"

    conn = connect()
    try:
        insert_event(conn, original, 100)
        insert_allocation(conn, original_alloc, original, 100)
        post(conn, original, original_domain, original_outbox)

        expect_raise(
            conn,
            "update economic_event set amount=101 where id=%s",
            (original,),
            "OSG_POSTED_EVENT_IMMUTABLE",
            "posted event critical field immutable",
        )
        expect_raise(
            conn,
            """
            insert into allocation (
              id,organization_id,economic_event_id,amount,property_id,
              allocation_type,classification,confidence
            ) values (
              '00000000-0000-7000-8000-000000009438',%s,%s,1,%s,
              'DIRECT','OPEX','VERIFIED'
            )
            """,
            (ORG, original, PROPERTY),
            "OSG_POSTED_ALLOCATION_IMMUTABLE",
            "posted allocation set immutable",
        )

        insert_event(
            conn,
            reversal,
            40,
            event_type="ADJUSTMENT",
            effect_direction="REVERSAL",
            reverses_event_id=original,
        )
        insert_allocation(conn, reversal_alloc, reversal, 40)
        post(conn, reversal, reversal_domain, reversal_outbox)

        row = conn.execute(
            "select status,effect_direction,reverses_event_id from economic_event where id=%s",
            (reversal,),
        ).fetchone()
        if row[0] != "POSTED" or row[1] != "REVERSAL" or str(row[2]) != original:
            raise AssertionError(f"reversal record invalid: {row}")
        if scalar(conn, "select amount from economic_event where id=%s", (original,)) != 100:
            raise AssertionError("reversal mutated original economic event")
        print("PASS correction represented by separate linked REVERSAL event")
    finally:
        conn.rollback()
        conn.close()


def test_hard_closed_period_rejects_post() -> None:
    event_id = "00000000-0000-7000-8000-000000009440"
    alloc_id = "00000000-0000-7000-8000-000000009441"
    domain_id = "00000000-0000-7000-8000-000000009442"
    outbox_id = "00000000-0000-7000-8000-000000009443"

    conn = connect()
    try:
        conn.execute(
            "update financial_period set status='HARD_CLOSED',closed_at=now() where id=%s",
            (PERIOD_SEP,),
        )
        insert_event(conn, event_id, 100)
        insert_allocation(conn, alloc_id, event_id, 100)
        expect_raise(
            conn,
            "select osg_post_economic_event_v02(%s,%s,%s,%s,%s)",
            (ORG, event_id, None, domain_id, outbox_id),
            "OSG_FINANCIAL_PERIOD_HARD_CLOSED",
            "HARD_CLOSED period blocks posting",
        )
        if scalar(conn, "select status from economic_event where id=%s", (event_id,)) != "DRAFT":
            raise AssertionError("HARD_CLOSED rejection changed event state")
        if scalar(conn, "select count(*) from domain_event where id=%s", (domain_id,)) != 0:
            raise AssertionError("HARD_CLOSED rejection leaked DomainEvent")
    finally:
        conn.rollback()
        conn.close()


@dataclass
class ThreadResult:
    outcome: str | None = None
    error: str | None = None


def cleanup_concurrent_fixture(event_id: str) -> None:
    with connect() as conn:
        row = conn.execute(
            "select status from economic_event where id=%s",
            (event_id,),
        ).fetchone()
        if row and row[0] == "POSTED":
            # The CI database is isolated and discarded after the job. A POSTED
            # proof fixture is deliberately left intact because deleting its
            # Allocation would violate the very immutability invariant we test.
            print("NOTE leaving immutable POSTED proof fixture in isolated CI database")
            return
        # Safe only for a pre-existing non-posted fixture from a partial local run.
        conn.execute(
            "delete from outbox_event where domain_event_id in (select id from domain_event where aggregate_id=%s)",
            (event_id,),
        )
        conn.execute("delete from domain_event where aggregate_id=%s", (event_id,))
        conn.execute("delete from allocation where economic_event_id=%s", (event_id,))
        conn.execute("delete from economic_event where id=%s", (event_id,))


def test_concurrent_duplicate_post_single_effect() -> None:
    event_id = "00000000-0000-7000-8000-000000009450"
    alloc_id = "00000000-0000-7000-8000-000000009451"
    domain_ids = [
        "00000000-0000-7000-8000-000000009452",
        "00000000-0000-7000-8000-000000009454",
    ]
    outbox_ids = [
        "00000000-0000-7000-8000-000000009453",
        "00000000-0000-7000-8000-000000009455",
    ]

    cleanup_concurrent_fixture(event_id)
    with connect() as conn:
        insert_event(conn, event_id, 100)
        insert_allocation(conn, alloc_id, event_id, 100)

    barrier = threading.Barrier(2)
    results = [ThreadResult(), ThreadResult()]

    def worker(index: int) -> None:
        try:
            with connect() as conn:
                barrier.wait(timeout=10)
                post(conn, event_id, domain_ids[index], outbox_ids[index])
                time.sleep(0.25)
            results[index].outcome = "SUCCESS"
        except errors.RaiseException as exc:
            if "ECONOMIC_EVENT_INVALID_STATE" not in str(exc):
                results[index].error = str(exc)
            else:
                results[index].outcome = "REJECTED_ALREADY_POSTED"
        except Exception as exc:  # pragma: no cover
            results[index].error = repr(exc)

    threads = [threading.Thread(target=worker, args=(0,)), threading.Thread(target=worker, args=(1,))]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=15)

    try:
        if any(thread.is_alive() for thread in threads):
            raise AssertionError("financial posting concurrency proof timed out")
        if any(result.error for result in results):
            raise AssertionError(f"financial posting concurrency unexpected errors: {results}")
        outcomes = sorted(result.outcome for result in results)
        if outcomes != ["REJECTED_ALREADY_POSTED", "SUCCESS"]:
            raise AssertionError(f"expected one post and one stable reject, got {outcomes}")

        with connect() as conn:
            state = conn.execute(
                "select status from economic_event where id=%s", (event_id,)
            ).fetchone()[0]
            domain_count = scalar(
                conn,
                "select count(*) from domain_event where aggregate_type='EconomicEvent' and aggregate_id=%s and event_type='EconomicEvent.Posted'",
                (event_id,),
            )
            outbox_count = scalar(
                conn,
                """
                select count(*)
                from outbox_event o
                join domain_event d on d.organization_id=o.organization_id and d.id=o.domain_event_id
                where d.aggregate_type='EconomicEvent' and d.aggregate_id=%s and d.event_type='EconomicEvent.Posted'
                """,
                (event_id,),
            )
        if state != "POSTED" or domain_count != 1 or outbox_count != 1:
            raise AssertionError(
                f"duplicate post leaked effects: state={state}, domain={domain_count}, outbox={outbox_count}"
            )
        print("PASS concurrent duplicate post: one POSTED state + one DomainEvent + one Outbox")
    finally:
        cleanup_concurrent_fixture(event_id)


def main() -> None:
    test_balanced_atomic_post()
    test_unbalanced_rolls_back_post_effects()
    test_cross_tenant_property_allocation_rejected()
    test_posted_immutability_and_reversal()
    test_hard_closed_period_rejects_post()
    test_concurrent_duplicate_post_single_effect()
    print("PASS OSG Issue #3 atomic Financial Truth posting proof core")


if __name__ == "__main__":
    main()
