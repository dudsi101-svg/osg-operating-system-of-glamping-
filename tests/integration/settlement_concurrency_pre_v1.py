"""OSG P0 Settlement conservation proof — DEV only.

Issue #14.

Protects owner/operator reimbursements from double application:
- exact fill 200 + 230 of a 430 Settlement,
- +1 over-application rolls back with stable OSG error,
- two independent connections race for the same remaining balance and exactly
  one application commits.

The safe write path locks SettlementEntry before inserting an application,
then calls osg_assert_settlement_not_overapplied() in the same transaction.
"""

from __future__ import annotations

import threading
import time
from dataclasses import dataclass

import psycopg
from psycopg import errors

ORG = "00000000-0000-7000-8000-000000000001"
SOURCE_EVENT = "00000000-0000-7000-8000-000000001020"
SOURCE_ALLOCATION = "00000000-0000-7000-8000-000000001021"
CREDITOR = "00000000-0000-7000-8000-000000000022"  # Kuba reference Party
DEBTOR = "00000000-0000-7000-8000-000000001001"    # business economic bearer

SETTLEMENT_EXACT = "00000000-0000-7000-8000-000000009850"
SETTLEMENT_RACE = "00000000-0000-7000-8000-000000009860"


def connect():
    return psycopg.connect("")


def scalar(conn, query: str, params=()):
    return conn.execute(query, params).fetchone()[0]


def insert_settlement(conn, settlement_id: str, amount: int) -> None:
    conn.execute(
        """
        insert into settlement_entry (
          id,organization_id,source_economic_event_id,source_allocation_id,
          creditor_party_id,debtor_party_id,amount,currency,status
        ) values (%s,%s,%s,%s,%s,%s,%s,'PLN','OPEN')
        """,
        (settlement_id, ORG, SOURCE_EVENT, SOURCE_ALLOCATION, CREDITOR, DEBTOR, amount),
    )


def insert_application(conn, application_id: str, settlement_id: str, amount: int) -> None:
    conn.execute(
        """
        insert into settlement_application (
          id,organization_id,settlement_entry_id,amount,applied_at
        ) values (%s,%s,%s,%s,now())
        """,
        (application_id, ORG, settlement_id, amount),
    )


def test_exact_fill_and_overapply_reject() -> None:
    conn = connect()
    try:
        insert_settlement(conn, SETTLEMENT_EXACT, 430)
        insert_application(conn, "00000000-0000-7000-8000-000000009851", SETTLEMENT_EXACT, 200)
        conn.execute("select osg_assert_settlement_not_overapplied(%s)", (SETTLEMENT_EXACT,))
        insert_application(conn, "00000000-0000-7000-8000-000000009852", SETTLEMENT_EXACT, 230)
        conn.execute("select osg_assert_settlement_not_overapplied(%s)", (SETTLEMENT_EXACT,))

        applied = scalar(
            conn,
            "select coalesce(sum(amount),0) from settlement_application where settlement_entry_id=%s",
            (SETTLEMENT_EXACT,),
        )
        amount = scalar(conn, "select amount from settlement_entry where id=%s", (SETTLEMENT_EXACT,))
        if amount != 430 or applied != 430 or amount - applied != 0:
            raise AssertionError(f"exact Settlement fill invalid: amount={amount} applied={applied}")
        print("PASS Settlement 430 + applications 200/230 -> zero open balance")

        conn.execute("savepoint settlement_overapply")
        try:
            insert_application(conn, "00000000-0000-7000-8000-000000009853", SETTLEMENT_EXACT, 1)
            conn.execute("select osg_assert_settlement_not_overapplied(%s)", (SETTLEMENT_EXACT,))
        except errors.RaiseException as exc:
            text = str(exc)
            conn.execute("rollback to savepoint settlement_overapply")
            conn.execute("release savepoint settlement_overapply")
            if "OSG_SETTLEMENT_OVER_APPLIED" not in text:
                raise AssertionError(f"expected OSG_SETTLEMENT_OVER_APPLIED, got {text}") from exc
            print("PASS Settlement +1 over-application rejected: OSG_SETTLEMENT_OVER_APPLIED")
        else:
            conn.execute("rollback to savepoint settlement_overapply")
            conn.execute("release savepoint settlement_overapply")
            raise AssertionError("Settlement over-application unexpectedly succeeded")

        applied_after = scalar(
            conn,
            "select coalesce(sum(amount),0) from settlement_application where settlement_entry_id=%s",
            (SETTLEMENT_EXACT,),
        )
        if applied_after != 430:
            raise AssertionError(f"failed over-application leaked state: applied={applied_after}")
        print("PASS rejected over-application leaves Settlement state unchanged")
    finally:
        conn.rollback()
        conn.close()


@dataclass
class Result:
    outcome: str | None = None
    error: str | None = None


def cleanup_race_fixture() -> None:
    with connect() as conn:
        conn.execute("delete from settlement_application where settlement_entry_id=%s", (SETTLEMENT_RACE,))
        conn.execute("delete from settlement_entry where id=%s", (SETTLEMENT_RACE,))


def setup_race_fixture() -> None:
    cleanup_race_fixture()
    with connect() as conn:
        insert_settlement(conn, SETTLEMENT_RACE, 100)
        insert_application(conn, "00000000-0000-7000-8000-000000009861", SETTLEMENT_RACE, 40)
        conn.execute("select osg_assert_settlement_not_overapplied(%s)", (SETTLEMENT_RACE,))


def test_true_concurrency_one_remaining_balance_winner() -> None:
    setup_race_fixture()
    barrier = threading.Barrier(2)
    results = [Result(), Result()]
    app_ids = [
        "00000000-0000-7000-8000-000000009862",
        "00000000-0000-7000-8000-000000009863",
    ]

    def worker(index: int) -> None:
        try:
            with connect() as conn:
                barrier.wait(timeout=10)

                # Canonical safe ordering: serialize on aggregate root BEFORE the
                # child application is created.
                row = conn.execute(
                    "select amount from settlement_entry where id=%s for update",
                    (SETTLEMENT_RACE,),
                ).fetchone()
                if not row:
                    raise AssertionError("Settlement race fixture missing")

                insert_application(conn, app_ids[index], SETTLEMENT_RACE, 60)
                conn.execute("select osg_assert_settlement_not_overapplied(%s)", (SETTLEMENT_RACE,))
                time.sleep(0.25)
            results[index].outcome = "SUCCESS"
        except errors.RaiseException as exc:
            if "OSG_SETTLEMENT_OVER_APPLIED" not in str(exc):
                results[index].error = str(exc)
            else:
                results[index].outcome = "REJECTED_OVER_APPLIED"
        except Exception as exc:  # pragma: no cover
            results[index].error = repr(exc)

    threads = [threading.Thread(target=worker, args=(0,)), threading.Thread(target=worker, args=(1,))]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=15)

    try:
        if any(thread.is_alive() for thread in threads):
            raise AssertionError("Settlement concurrency proof timed out")
        if any(result.error for result in results):
            raise AssertionError(f"Settlement concurrency unexpected errors: {results}")
        outcomes = sorted(result.outcome for result in results)
        if outcomes != ["REJECTED_OVER_APPLIED", "SUCCESS"]:
            raise AssertionError(f"expected one success / one rejection, got {outcomes}")

        with connect() as conn:
            amount = scalar(conn, "select amount from settlement_entry where id=%s", (SETTLEMENT_RACE,))
            applied = scalar(
                conn,
                "select coalesce(sum(amount),0) from settlement_application where settlement_entry_id=%s",
                (SETTLEMENT_RACE,),
            )
            committed_race_apps = scalar(
                conn,
                "select count(*) from settlement_application where id = any(%s::uuid[])",
                (app_ids,),
            )
        if amount != 100 or applied != 100 or committed_race_apps != 1:
            raise AssertionError(
                f"Settlement race violated conservation: amount={amount} applied={applied} committed_race_apps={committed_race_apps}"
            )
        print("PASS true Settlement concurrency: exactly one remaining-balance application committed")
        print("OSG_ERROR_CODE=SETTLEMENT_OVER_APPLIED for losing concurrent request")
    finally:
        cleanup_race_fixture()


def main() -> None:
    test_exact_fill_and_overapply_reject()
    test_true_concurrency_one_remaining_balance_winner()
    print("PASS OSG Issue #14 Settlement conservation proof")


if __name__ == "__main__":
    main()
