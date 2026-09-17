"""OSG P1 Folio invariant proof — DEV only.

Issue #10 executable acceptance. Unlike the historical SQL scaffold, every
negative case is actually executed and its stable OSG error is asserted.
"""

from __future__ import annotations

import psycopg
from psycopg import errors

ORG = "00000000-0000-7000-8000-000000000001"
PROPERTY = "00000000-0000-7000-8000-000000000010"
CHANNEL = "00000000-0000-7000-8000-000000000351"


def connect():
    return psycopg.connect("")


def scalar(conn, query: str, params=()):
    return conn.execute(query, params).fetchone()[0]


def expect_raise(conn, sql: str, params, expected: str, label: str) -> None:
    conn.execute("savepoint folio_expected_error")
    try:
        conn.execute(sql, params)
    except errors.RaiseException as exc:
        text = str(exc)
        conn.execute("rollback to savepoint folio_expected_error")
        conn.execute("release savepoint folio_expected_error")
        if expected not in text:
            raise AssertionError(f"{label}: expected {expected}, got {text}") from exc
        print(f"PASS {label}: {expected}")
        return
    except Exception:
        conn.execute("rollback to savepoint folio_expected_error")
        conn.execute("release savepoint folio_expected_error")
        raise
    else:
        conn.execute("rollback to savepoint folio_expected_error")
        conn.execute("release savepoint folio_expected_error")
        raise AssertionError(f"{label}: expected {expected}")


def create_reservation_folio(conn, suffix: int):
    reservation_id = f"00000000-0000-7000-8000-000000009{suffix:03d}"
    folio_id = f"00000000-0000-7000-8000-000000008{suffix:03d}"
    conn.execute(
        """
        insert into reservation (
          id,organization_id,property_id,channel_id,reference_code,
          commercial_status,booked_at,currency
        ) values (%s,%s,%s,%s,%s,'CONFIRMED',now(),'PLN')
        """,
        (reservation_id, ORG, PROPERTY, CHANNEL, f"P0-FOLIO-{suffix}"),
    )
    conn.execute(
        "insert into folio (id,organization_id,reservation_id,currency,status,opened_at) values (%s,%s,%s,'PLN','OPEN',now())",
        (folio_id, ORG, reservation_id),
    )
    return reservation_id, folio_id


def test_payment_currency_mismatch() -> None:
    conn = connect()
    try:
        _, folio = create_reservation_folio(conn, 100)
        expect_raise(
            conn,
            """
            insert into payment (
              id,organization_id,folio_id,method,amount,currency,status
            ) values ('00000000-0000-7000-8000-000000008101',%s,%s,'CARD',100,'EUR','CONFIRMED')
            """,
            (ORG, folio),
            "OSG_FOLIO_CURRENCY_MISMATCH",
            "Payment currency differing from Folio rejected",
        )
    finally:
        conn.rollback(); conn.close()


def test_refund_guards() -> None:
    conn = connect()
    try:
        _, folio = create_reservation_folio(conn, 110)
        payment = "00000000-0000-7000-8000-000000008111"
        conn.execute(
            "insert into payment (id,organization_id,folio_id,method,amount,currency,status) values (%s,%s,%s,'CARD',100,'PLN','CONFIRMED')",
            (payment, ORG, folio),
        )

        expect_raise(
            conn,
            """
            insert into refund (id,organization_id,payment_id,amount,currency,status)
            values ('00000000-0000-7000-8000-000000008112',%s,%s,10,'EUR','CONFIRMED')
            """,
            (ORG, payment),
            "OSG_REFUND_CURRENCY_MISMATCH",
            "Refund currency differing from Payment rejected",
        )

        conn.execute(
            "insert into refund (id,organization_id,payment_id,amount,currency,status) values ('00000000-0000-7000-8000-000000008113',%s,%s,60,'PLN','CONFIRMED')",
            (ORG, payment),
        )
        expect_raise(
            conn,
            """
            insert into refund (id,organization_id,payment_id,amount,currency,status)
            values ('00000000-0000-7000-8000-000000008114',%s,%s,50,'PLN','CONFIRMED')
            """,
            (ORG, payment),
            "OSG_REFUND_EXCEEDS_PAYMENT",
            "Confirmed refunds cannot exceed Payment",
        )
        total = scalar(conn, "select coalesce(sum(amount),0) from refund where payment_id=%s and status='CONFIRMED'", (payment,))
        if total != 60:
            raise AssertionError(f"failed over-refund leaked state: confirmed_refunds={total}")
        print("PASS rejected over-refund leaves confirmed refund total unchanged")
    finally:
        conn.rollback(); conn.close()


def test_close_balance_and_controlled_reopen() -> None:
    # Non-zero balance must not close.
    conn = connect()
    try:
        _, folio = create_reservation_folio(conn, 120)
        conn.execute(
            """
            insert into charge (
              id,organization_id,folio_id,charge_type,description,quantity,
              unit_price,gross_amount,status
            ) values ('00000000-0000-7000-8000-000000008121',%s,%s,'FEE','P0 non-zero close',1,300,300,'POSTED')
            """,
            (ORG, folio),
        )
        expect_raise(
            conn,
            "update folio set status='CLOSED' where id=%s",
            (folio,),
            "OSG_FOLIO_BALANCE_NOT_ZERO",
            "Folio with non-zero balance cannot close",
        )
    finally:
        conn.rollback(); conn.close()

    # Zero balance closes and controlled reopen is explicit.
    conn = connect()
    try:
        _, folio = create_reservation_folio(conn, 130)
        conn.execute(
            """
            insert into charge (
              id,organization_id,folio_id,charge_type,description,quantity,
              unit_price,gross_amount,status
            ) values ('00000000-0000-7000-8000-000000008131',%s,%s,'FEE','P0 zero balance close',1,300,300,'POSTED')
            """,
            (ORG, folio),
        )
        conn.execute(
            "insert into payment (id,organization_id,folio_id,method,amount,currency,status) values ('00000000-0000-7000-8000-000000008132',%s,%s,'CARD',300,'PLN','CONFIRMED')",
            (ORG, folio),
        )
        conn.execute("update folio set status='CLOSED' where id=%s", (folio,))
        row = conn.execute("select status,closed_at from folio where id=%s", (folio,)).fetchone()
        balance = scalar(conn, "select balance_due from osg_folio_balance where folio_id=%s", (folio,))
        if row[0] != "CLOSED" or row[1] is None or abs(balance) > 0.01:
            raise AssertionError(f"zero-balance Folio close invalid: row={row}, balance={balance}")
        print("PASS zero-balance Folio closes and stamps closed_at")

        expect_raise(
            conn,
            "update folio set status='OPEN' where id=%s",
            (folio,),
            "OSG_CONTROLLED_FOLIO_REOPEN_REQUIRED",
            "uncontrolled Folio reopen rejected",
        )
        conn.execute("select set_config('osg.controlled_folio_reopen','on',true)")
        conn.execute("update folio set status='OPEN' where id=%s", (folio,))
        reopened = conn.execute("select status,closed_at from folio where id=%s", (folio,)).fetchone()
        if reopened != ("OPEN", None):
            raise AssertionError(f"controlled Folio reopen invalid: {reopened}")
        print("PASS privileged controlled Folio reopen succeeds and clears closed_at")
    finally:
        conn.rollback(); conn.close()


def test_reference_full_refund_preserves_history() -> None:
    folio = "00000000-0000-7000-8000-000000001420"
    payment = "00000000-0000-7000-8000-000000001422"
    refund = "00000000-0000-7000-8000-000000001425"
    original_charge = "00000000-0000-7000-8000-000000001421"
    reversal_charge = "00000000-0000-7000-8000-000000001429"

    with connect() as conn:
        status = scalar(conn, "select status from folio where id=%s", (folio,))
        balance = scalar(conn, "select balance_due from osg_folio_balance where folio_id=%s", (folio,))
        payment_count = scalar(conn, "select count(*) from payment where id=%s", (payment,))
        refund_count = scalar(conn, "select count(*) from refund where id=%s and payment_id=%s", (refund, payment))
        charge_count = scalar(conn, "select count(*) from charge where id in (%s,%s)", (original_charge, reversal_charge))
        original_gross = scalar(conn, "select gross_amount from charge where id=%s", (original_charge,))
        reversal_gross = scalar(conn, "select gross_amount from charge where id=%s", (reversal_charge,))

    if status != "CLOSED" or abs(balance) > 0.01:
        raise AssertionError(f"reference full-refund Folio not closed/zero: status={status}, balance={balance}")
    if (payment_count, refund_count, charge_count) != (1, 1, 2):
        raise AssertionError(
            f"full-refund history incomplete: payment={payment_count}, refund={refund_count}, charges={charge_count}"
        )
    if original_gross != 1000 or reversal_gross != -1000:
        raise AssertionError(f"full-refund commercial reversal invalid: original={original_gross}, reversal={reversal_gross}")
    print("PASS full-refund scenario preserves Payment/Refund/original+reversal Charge history and zero Folio balance")


def main() -> None:
    test_payment_currency_mismatch()
    test_refund_guards()
    test_close_balance_and_controlled_reopen()
    test_reference_full_refund_preserves_history()
    print("PASS OSG Issue #10 executable Folio invariants")


if __name__ == "__main__":
    main()
