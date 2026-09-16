#!/usr/bin/env python3
"""Executable pre-v1 proof for OSG Issue #11 Charge correction/reversal invariants."""

import os
import threading
import time

import psycopg

DSN = (
    f"host={os.getenv('PGHOST', '127.0.0.1')} "
    f"port={os.getenv('PGPORT', '5432')} "
    f"dbname={os.getenv('PGDATABASE', 'osg_test')} "
    f"user={os.getenv('PGUSER', 'postgres')} "
    f"password={os.getenv('PGPASSWORD', 'postgres')}"
)

ORG = "00000000-0000-7000-8000-000000000001"
PROPERTY = "00000000-0000-7000-8000-000000000010"
CHANNEL = "00000000-0000-7000-8000-000000000351"

RES_A = "00000000-0000-7000-8000-000000008201"
FOLIO_A = "00000000-0000-7000-8000-000000008202"
ORIGINAL_A = "00000000-0000-7000-8000-000000008203"
REV_400 = "00000000-0000-7000-8000-000000008204"
REV_600 = "00000000-0000-7000-8000-000000008205"

RES_B = "00000000-0000-7000-8000-000000008206"
FOLIO_B = "00000000-0000-7000-8000-000000008207"

RES_RACE = "00000000-0000-7000-8000-000000008210"
FOLIO_RACE = "00000000-0000-7000-8000-000000008211"
ORIGINAL_RACE = "00000000-0000-7000-8000-000000008212"
REV_RACE_A = "00000000-0000-7000-8000-000000008213"
REV_RACE_B = "00000000-0000-7000-8000-000000008214"


def conn():
    return psycopg.connect(DSN)


def setup_fixture():
    with conn() as c:
        with c.cursor() as cur:
            cur.execute(
                """
                insert into reservation (
                  id,organization_id,property_id,channel_id,reference_code,
                  commercial_status,booked_at,currency
                ) values
                  (%s,%s,%s,%s,'TEST-CHARGE-A','CONFIRMED',now(),'PLN'),
                  (%s,%s,%s,%s,'TEST-CHARGE-B','CONFIRMED',now(),'PLN'),
                  (%s,%s,%s,%s,'TEST-CHARGE-RACE','CONFIRMED',now(),'PLN')
                """,
                (RES_A, ORG, PROPERTY, CHANNEL,
                 RES_B, ORG, PROPERTY, CHANNEL,
                 RES_RACE, ORG, PROPERTY, CHANNEL),
            )
            cur.execute(
                """
                insert into folio (id,organization_id,reservation_id,currency,status)
                values (%s,%s,%s,'PLN','OPEN'),
                       (%s,%s,%s,'PLN','OPEN'),
                       (%s,%s,%s,'PLN','OPEN')
                """,
                (FOLIO_A, ORG, RES_A, FOLIO_B, ORG, RES_B, FOLIO_RACE, ORG, RES_RACE),
            )
            cur.execute(
                """
                insert into charge (
                  id,organization_id,folio_id,charge_type,description,
                  quantity,unit_price,gross_amount,status
                ) values
                  (%s,%s,%s,'ACCOMMODATION','Original immutable charge',1,1000,1000,'POSTED'),
                  (%s,%s,%s,'ACCOMMODATION','Concurrent reversal original',1,1000,1000,'POSTED')
                """,
                (ORIGINAL_A, ORG, FOLIO_A, ORIGINAL_RACE, ORG, FOLIO_RACE),
            )


def expect_failure(sql, params, expected, label):
    with conn() as c:
        try:
            with c.cursor() as cur:
                cur.execute(sql, params)
            c.commit()
        except Exception as exc:  # psycopg maps DB errors to typed subclasses
            c.rollback()
            text = str(exc)
            if expected not in text:
                raise AssertionError(f"{label}: expected {expected!r}, got {text!r}") from exc
            print(f"PASS {label}: {expected}")
            return
    raise AssertionError(f"{label}: operation unexpectedly succeeded")


def test_final_charge_immutability():
    expect_failure(
        "update charge set gross_amount=900 where id=%s",
        (ORIGINAL_A,),
        "OSG_FINAL_CHARGE_IMMUTABLE",
        "POSTED Charge material update rejected",
    )
    expect_failure(
        "delete from charge where id=%s",
        (ORIGINAL_A,),
        "OSG_FINAL_CHARGE_IMMUTABLE",
        "POSTED Charge delete rejected",
    )
    expect_failure(
        "update charge set status='REVERSED' where id=%s",
        (ORIGINAL_A,),
        "charge_status_check",
        "mutable REVERSED state absent",
    )


def test_reversal_semantics():
    expect_failure(
        """
        insert into charge (
          id,organization_id,folio_id,charge_type,description,
          quantity,unit_price,gross_amount,status,reverses_charge_id
        ) values ('00000000-0000-7000-8000-000000008220',%s,%s,'ACCOMMODATION',
                  'Bad sign',1,100,100,'POSTED',%s)
        """,
        (ORG, FOLIO_A, ORIGINAL_A),
        "OSG_CHARGE_REVERSAL_SIGN_INVALID",
        "same-sign reversal rejected",
    )
    expect_failure(
        """
        insert into charge (
          id,organization_id,folio_id,charge_type,description,
          quantity,unit_price,gross_amount,status,reverses_charge_id
        ) values ('00000000-0000-7000-8000-000000008221',%s,%s,'ACCOMMODATION',
                  'Wrong folio',1,-100,-100,'POSTED',%s)
        """,
        (ORG, FOLIO_B, ORIGINAL_A),
        "OSG_CHARGE_REVERSAL_FOLIO_MISMATCH",
        "cross-Folio reversal rejected",
    )

    with conn() as c:
        with c.cursor() as cur:
            cur.execute(
                """
                insert into charge (
                  id,organization_id,folio_id,charge_type,description,
                  quantity,unit_price,gross_amount,status,reverses_charge_id
                ) values
                  (%s,%s,%s,'ACCOMMODATION','Partial reversal 400',1,-400,-400,'POSTED',%s),
                  (%s,%s,%s,'ACCOMMODATION','Partial reversal 600',1,-600,-600,'POSTED',%s)
                """,
                (REV_400, ORG, FOLIO_A, ORIGINAL_A,
                 REV_600, ORG, FOLIO_A, ORIGINAL_A),
            )

    expect_failure(
        """
        insert into charge (
          id,organization_id,folio_id,charge_type,description,
          quantity,unit_price,gross_amount,status,reverses_charge_id
        ) values ('00000000-0000-7000-8000-000000008222',%s,%s,'ACCOMMODATION',
                  'Over reversal',1,-1,-1,'POSTED',%s)
        """,
        (ORG, FOLIO_A, ORIGINAL_A),
        "OSG_CHARGE_OVER_REVERSED",
        "cumulative over-reversal rejected",
    )

    with conn() as c:
        with c.cursor() as cur:
            cur.execute(
                "select status,gross_amount from charge where id=%s",
                (ORIGINAL_A,),
            )
            status, amount = cur.fetchone()
            assert status == "POSTED" and float(amount) == 1000.0, (
                "original Charge history was mutated",
                status,
                amount,
            )
            cur.execute(
                "select net_charges,balance_due from osg_folio_balance where folio_id=%s",
                (FOLIO_A,),
            )
            net, balance = cur.fetchone()
            assert float(net) == 0.0 and float(balance) == 0.0, (net, balance)
            cur.execute(
                "select count(*),sum(abs(gross_amount)) from charge where reverses_charge_id=%s and status in ('POSTED','RECOGNIZED')",
                (ORIGINAL_A,),
            )
            count, reversed_total = cur.fetchone()
            assert count == 2 and float(reversed_total) == 1000.0, (count, reversed_total)
    print("PASS partial reversals sum exactly to original; original remains historical; Folio nets to zero")


def test_concurrent_over_reversal():
    first_inserted = threading.Event()
    outcomes = []
    lock = threading.Lock()

    def worker_a():
        c = conn()
        try:
            with c.cursor() as cur:
                cur.execute(
                    """
                    insert into charge (
                      id,organization_id,folio_id,charge_type,description,
                      quantity,unit_price,gross_amount,status,reverses_charge_id
                    ) values (%s,%s,%s,'ACCOMMODATION','Race reversal A',1,-600,-600,'POSTED',%s)
                    """,
                    (REV_RACE_A, ORG, FOLIO_RACE, ORIGINAL_RACE),
                )
                first_inserted.set()
                time.sleep(0.6)
            c.commit()
            result = "committed"
        except Exception as exc:
            c.rollback()
            result = str(exc)
        finally:
            c.close()
        with lock:
            outcomes.append(("A", result))

    def worker_b():
        if not first_inserted.wait(timeout=5):
            raise AssertionError("worker A did not reach inserted state")
        c = conn()
        try:
            with c.cursor() as cur:
                cur.execute(
                    """
                    insert into charge (
                      id,organization_id,folio_id,charge_type,description,
                      quantity,unit_price,gross_amount,status,reverses_charge_id
                    ) values (%s,%s,%s,'ACCOMMODATION','Race reversal B',1,-600,-600,'POSTED',%s)
                    """,
                    (REV_RACE_B, ORG, FOLIO_RACE, ORIGINAL_RACE),
                )
            c.commit()
            result = "committed"
        except Exception as exc:
            c.rollback()
            result = str(exc)
        finally:
            c.close()
        with lock:
            outcomes.append(("B", result))

    t1 = threading.Thread(target=worker_a, daemon=True)
    t2 = threading.Thread(target=worker_b, daemon=True)
    t1.start()
    t2.start()
    t1.join(timeout=10)
    t2.join(timeout=10)
    if t1.is_alive() or t2.is_alive():
        raise AssertionError("Charge reversal concurrency test timed out")

    committed = [name for name, result in outcomes if result == "committed"]
    rejected = [result for _, result in outcomes if result != "committed"]
    if len(committed) != 1 or len(rejected) != 1:
        raise AssertionError(f"expected one committed reversal and one rejection, got {outcomes}")
    if "OSG_CHARGE_OVER_REVERSED" not in rejected[0]:
        raise AssertionError(f"losing concurrent reversal had unexpected error: {rejected[0]}")

    with conn() as c:
        with c.cursor() as cur:
            cur.execute(
                """
                select coalesce(sum(abs(gross_amount)),0)
                from charge
                where reverses_charge_id=%s and status in ('POSTED','RECOGNIZED')
                """,
                (ORIGINAL_RACE,),
            )
            total = cur.fetchone()[0]
            assert float(total) == 600.0, f"concurrent reversals over-applied original: {total}"
    print("PASS concurrent reversals serialize: exactly one -600 commits, loser gets OSG_CHARGE_OVER_REVERSED")


def main():
    setup_fixture()
    test_final_charge_immutability()
    test_reversal_semantics()
    test_concurrent_over_reversal()
    print("PASS OSG Issue #11 executable Charge immutability/reversal proof")


if __name__ == "__main__":
    main()
