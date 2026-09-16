"""OSG P0 Resource capacity/concurrency proof — DEV only.

Covers Issue #2 acceptance using real PostgreSQL transactions and at least
2 independent DB connections.

The test intentionally uses synthetic fixture IDs and removes them afterwards.
"""

from __future__ import annotations

import threading
import time
from dataclasses import dataclass

import psycopg
from psycopg import errors

ORG = "00000000-0000-7000-8000-000000000001"
PROPERTY = "00000000-0000-7000-8000-000000000010"
ZONE = "00000000-0000-7000-8000-000000000034"
SAUNA = "00000000-0000-7000-8000-000000000301"
CAP8 = "00000000-0000-7000-8000-000000009300"


def connect():
    # Empty conninfo delegates to libpq PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE.
    return psycopg.connect("")


def cleanup() -> None:
    with connect() as conn:
        conn.execute(
            "delete from resource_reservation where organization_id=%s and id::text like '00000000-0000-7000-8000-0000000093%%'",
            (ORG,),
        )
        conn.execute("delete from resource where id=%s", (CAP8,))


def setup_capacity_resource() -> None:
    with connect() as conn:
        conn.execute(
            """
            insert into resource (
              id,organization_id,property_id,zone_id,code,name,resource_type,
              capacity,booking_mode,buffer_before,buffer_after,active
            ) values (
              %s,%s,%s,%s,'P0CAP8','P0 Capacity 8','TEST',8,'CAPACITY',
              interval '30 minutes',interval '15 minutes',true
            )
            """,
            (CAP8, ORG, PROPERTY, ZONE),
        )


def insert_rr(
    conn,
    *,
    rr_id: str,
    resource_id: str,
    start: str,
    end: str,
    effective_start: str,
    effective_end: str,
    capacity: int,
    exclusive: bool,
    status: str = "CONFIRMED",
    expires_at: str | None = None,
) -> None:
    conn.execute(
        """
        insert into resource_reservation (
          id,organization_id,resource_id,start_at,end_at,effective_start_at,
          effective_end_at,capacity_used,exclusive_booking,status,expires_at
        ) values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """,
        (
            rr_id,
            ORG,
            resource_id,
            start,
            end,
            effective_start,
            effective_end,
            capacity,
            exclusive,
            status,
            expires_at,
        ),
    )


def assert_capacity(
    conn,
    start: str,
    end: str,
    amount: int,
    as_of: str = "2026-12-10T12:00:00+01",
    resource_id: str = CAP8,
) -> None:
    conn.execute(
        "select osg_assert_resource_capacity(%s,%s,%s,%s,null,%s)",
        (resource_id, start, end, amount, as_of),
    )


def expect_capacity_rejection(fn, label: str) -> None:
    try:
        fn()
    except errors.RaiseException as exc:
        if "OSG_RESOURCE_CAPACITY_EXCEEDED" not in str(exc):
            raise AssertionError(f"{label}: unexpected error: {exc}") from exc
        print(f"PASS {label}: RESOURCE_CAPACITY_EXCEEDED")
        return
    raise AssertionError(f"{label}: expected RESOURCE_CAPACITY_EXCEEDED")


def test_capacity_exact_fill_and_overflow() -> None:
    # Existing 6 + request 2 = 8 -> accept.
    with connect() as conn:
        insert_rr(
            conn,
            rr_id="00000000-0000-7000-8000-000000009301",
            resource_id=CAP8,
            start="2026-12-11T18:00:00+01",
            end="2026-12-11T19:00:00+01",
            effective_start="2026-12-11T17:30:00+01",
            effective_end="2026-12-11T19:15:00+01",
            capacity=6,
            exclusive=False,
        )

    with connect() as conn:
        assert_capacity(conn, "2026-12-11T17:30:00+01", "2026-12-11T19:15:00+01", 2)
        insert_rr(
            conn,
            rr_id="00000000-0000-7000-8000-000000009302",
            resource_id=CAP8,
            start="2026-12-11T18:00:00+01",
            end="2026-12-11T19:00:00+01",
            effective_start="2026-12-11T17:30:00+01",
            effective_end="2026-12-11T19:15:00+01",
            capacity=2,
            exclusive=False,
        )
    print("PASS capacity existing 6 + request 2")

    # Remove accepted +2; prove existing 6 + request 3 rejects.
    with connect() as conn:
        conn.execute(
            "delete from resource_reservation where id=%s",
            ("00000000-0000-7000-8000-000000009302",),
        )

    def overflow():
        with connect() as conn:
            assert_capacity(conn, "2026-12-11T17:30:00+01", "2026-12-11T19:15:00+01", 3)

    expect_capacity_rejection(overflow, "capacity existing 6 + request 3")


def test_expired_hold_ignored() -> None:
    with connect() as conn:
        insert_rr(
            conn,
            rr_id="00000000-0000-7000-8000-000000009303",
            resource_id=CAP8,
            start="2026-12-12T18:00:00+01",
            end="2026-12-12T19:00:00+01",
            effective_start="2026-12-12T17:30:00+01",
            effective_end="2026-12-12T19:15:00+01",
            capacity=8,
            exclusive=False,
            status="HELD",
            expires_at="2026-12-12T10:00:00+01",
        )

    with connect() as conn:
        assert_capacity(
            conn,
            "2026-12-12T17:30:00+01",
            "2026-12-12T19:15:00+01",
            8,
            as_of="2026-12-12T12:00:00+01",
        )
    print("PASS expired HOLD ignored")


def test_effective_buffer_overlap() -> None:
    # Requested windows do not overlap: existing ends 19:00, next starts 19:10.
    # Effective windows do overlap because buffers extend them.
    with connect() as conn:
        insert_rr(
            conn,
            rr_id="00000000-0000-7000-8000-000000009304",
            resource_id=CAP8,
            start="2026-12-13T18:00:00+01",
            end="2026-12-13T19:00:00+01",
            effective_start="2026-12-13T17:30:00+01",
            effective_end="2026-12-13T19:15:00+01",
            capacity=8,
            exclusive=False,
        )

    def buffer_conflict():
        with connect() as conn:
            assert_capacity(conn, "2026-12-13T18:40:00+01", "2026-12-13T20:15:00+01", 1)

    expect_capacity_rejection(buffer_conflict, "effective buffer overlap")


@dataclass
class ThreadResult:
    outcome: str | None = None
    error: str | None = None


def test_capacity_true_concurrency() -> None:
    # Two requests of 5 against capacity 8. Correct locking => exactly one commit.
    barrier = threading.Barrier(2)
    results = [ThreadResult(), ThreadResult()]
    ids = [
        "00000000-0000-7000-8000-000000009305",
        "00000000-0000-7000-8000-000000009306",
    ]

    def worker(index: int) -> None:
        try:
            with connect() as conn:
                barrier.wait(timeout=10)
                assert_capacity(conn, "2026-12-14T17:30:00+01", "2026-12-14T19:15:00+01", 5)
                insert_rr(
                    conn,
                    rr_id=ids[index],
                    resource_id=CAP8,
                    start="2026-12-14T18:00:00+01",
                    end="2026-12-14T19:00:00+01",
                    effective_start="2026-12-14T17:30:00+01",
                    effective_end="2026-12-14T19:15:00+01",
                    capacity=5,
                    exclusive=False,
                )
                # Keep the Resource row lock briefly so the competing transaction
                # must actually wait and re-read committed capacity afterwards.
                time.sleep(0.35)
            results[index].outcome = "SUCCESS"
        except errors.RaiseException as exc:
            if "OSG_RESOURCE_CAPACITY_EXCEEDED" not in str(exc):
                results[index].error = str(exc)
            else:
                results[index].outcome = "REJECTED"
        except Exception as exc:  # pragma: no cover - diagnostic path
            results[index].error = repr(exc)

    threads = [
        threading.Thread(target=worker, args=(0,)),
        threading.Thread(target=worker, args=(1,)),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=15)

    if any(thread.is_alive() for thread in threads):
        raise AssertionError("capacity concurrency proof timed out")
    if any(result.error for result in results):
        raise AssertionError(f"capacity concurrency unexpected errors: {results}")

    outcomes = sorted(result.outcome for result in results)
    if outcomes != ["REJECTED", "SUCCESS"]:
        raise AssertionError(
            f"capacity concurrency expected one success/one reject, got {outcomes}"
        )
    print("PASS capacity true concurrency: exactly one of two capacity=5 requests committed")


def test_exclusive_true_concurrency() -> None:
    # EXCLUSIVE uses the same serialized ReserveResource workflow as CAPACITY.
    # The GiST exclusion constraint remains a fail-closed backstop; using only
    # concurrent bare INSERTs can produce a PostgreSQL deadlock rather than the
    # stable domain error required by OSG.
    barrier = threading.Barrier(2)
    results = [ThreadResult(), ThreadResult()]
    ids = [
        "00000000-0000-7000-8000-000000009307",
        "00000000-0000-7000-8000-000000009308",
    ]

    def worker(index: int) -> None:
        try:
            with connect() as conn:
                barrier.wait(timeout=10)
                assert_capacity(
                    conn,
                    "2026-12-15T17:30:00+01",
                    "2026-12-15T19:15:00+01",
                    1,
                    resource_id=SAUNA,
                )
                insert_rr(
                    conn,
                    rr_id=ids[index],
                    resource_id=SAUNA,
                    start="2026-12-15T18:00:00+01",
                    end="2026-12-15T19:00:00+01",
                    effective_start="2026-12-15T17:30:00+01",
                    effective_end="2026-12-15T19:15:00+01",
                    capacity=1,
                    exclusive=True,
                )
                time.sleep(0.35)
            results[index].outcome = "SUCCESS"
        except errors.RaiseException as exc:
            if "OSG_RESOURCE_CAPACITY_EXCEEDED" not in str(exc):
                results[index].error = str(exc)
            else:
                results[index].outcome = "REJECTED"
        except errors.ExclusionViolation as exc:
            # This is still fail-closed, but it means the canonical lock/guard
            # workflow failed to serialize and therefore is a test failure.
            results[index].error = (
                f"unexpected exclusion backstop instead of stable guard error; "
                f"constraint={exc.diag.constraint_name}: {exc}"
            )
        except Exception as exc:  # pragma: no cover - diagnostic path
            results[index].error = repr(exc)

    threads = [
        threading.Thread(target=worker, args=(0,)),
        threading.Thread(target=worker, args=(1,)),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=15)

    if any(thread.is_alive() for thread in threads):
        raise AssertionError("exclusive concurrency proof timed out")
    if any(result.error for result in results):
        raise AssertionError(f"exclusive concurrency unexpected errors: {results}")

    outcomes = sorted(result.outcome for result in results)
    if outcomes != ["REJECTED", "SUCCESS"]:
        raise AssertionError(
            f"exclusive concurrency expected one success/one reject, got {outcomes}"
        )
    print("PASS exclusive true concurrency: exactly one overlapping Sauna reservation committed")
    print("OSG_ERROR_CODE=RESOURCE_CAPACITY_EXCEEDED via serialized resource guard")


def main() -> None:
    cleanup()
    try:
        setup_capacity_resource()
        test_capacity_exact_fill_and_overflow()
        test_expired_hold_ignored()
        test_effective_buffer_overlap()
        test_capacity_true_concurrency()
        test_exclusive_true_concurrency()
        print("PASS OSG Issue #2 Resource capacity concurrency proof")
    finally:
        cleanup()


if __name__ == "__main__":
    main()
