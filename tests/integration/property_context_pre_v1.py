"""OSG P0 same-tenant cross-Property proof — DEV only.

Issue #9: one Organization owns Property A and Property B. Tenant equality is
therefore insufficient: business records that require one Property context must
still reject references into the sibling Property.

The proof runs against the current v0.99 guards without adding new rules first.
All synthetic rows live in one transaction and are rolled back at the end.
"""

from __future__ import annotations

import psycopg
from psycopg import errors

ORG = "00000000-0000-7000-8000-000000000001"
PROPERTY_A = "00000000-0000-7000-8000-000000000010"
UNIT_TYPE_A = "00000000-0000-7000-8000-000000000101"
UNIT_A = "00000000-0000-7000-8000-000000000201"
SERVICE_A = "00000000-0000-7000-8000-000000000401"

# Existing reference scenario 01 records loaded before this proof.
RESERVATION_A = "00000000-0000-7000-8000-000000000810"
STAY_A = "00000000-0000-7000-8000-000000000813"

PROPERTY_B = "00000000-0000-7000-8000-000000009950"
UNIT_TYPE_B = "00000000-0000-7000-8000-000000009951"
UNIT_B = "00000000-0000-7000-8000-000000009952"
RESOURCE_B = "00000000-0000-7000-8000-000000009953"
ASSET_B = "00000000-0000-7000-8000-000000009954"
SERVICE_B = "00000000-0000-7000-8000-000000009955"
CHANNEL_B = "00000000-0000-7000-8000-000000009956"
INVESTMENT_B = "00000000-0000-7000-8000-000000009957"
RESERVATION_B = "00000000-0000-7000-8000-000000009958"
RESERVATION_ITEM_B = "00000000-0000-7000-8000-000000009959"
STAY_B = "00000000-0000-7000-8000-000000009960"
ORG_COST_CENTER = "00000000-0000-7000-8000-000000009961"
EVENT_A = "00000000-0000-7000-8000-000000009962"
EVENT_ORG = "00000000-0000-7000-8000-000000009963"
SERVICE_BOOKING_A = "00000000-0000-7000-8000-000000009964"


def connect():
    return psycopg.connect("")


def expect_context_mismatch(conn, sql: str, params, label: str, suffix: str) -> None:
    conn.execute("savepoint property_context_expected")
    try:
        conn.execute(sql, params)
    except errors.RaiseException as exc:
        text = str(exc)
        conn.execute("rollback to savepoint property_context_expected")
        conn.execute("release savepoint property_context_expected")
        expected = f"PROPERTY_CONTEXT_MISMATCH {suffix}"
        if expected not in text:
            raise AssertionError(f"{label}: expected {expected}, got {text}") from exc
        print(f"PASS {label}: {expected}")
        return
    except Exception:
        conn.execute("rollback to savepoint property_context_expected")
        conn.execute("release savepoint property_context_expected")
        raise
    else:
        conn.execute("rollback to savepoint property_context_expected")
        conn.execute("release savepoint property_context_expected")
        raise AssertionError(f"{label}: cross-Property link unexpectedly succeeded")


def setup_property_b(conn) -> None:
    conn.execute(
        """
        insert into property (
          id,organization_id,name,code,property_type,timezone,currency,status
        ) values (%s,%s,'P0 Sibling Property','P0SIBLING','GLAMPING','Europe/Warsaw','PLN','ACTIVE')
        """,
        (PROPERTY_B, ORG),
    )
    conn.execute(
        """
        insert into unit_type (
          id,organization_id,property_id,name,code,base_capacity,max_capacity,active
        ) values (%s,%s,%s,'P0 B Type','P0BTYPE',1,2,true)
        """,
        (UNIT_TYPE_B, ORG, PROPERTY_B),
    )
    conn.execute(
        """
        insert into unit (
          id,organization_id,property_id,unit_type_id,code,name,lifecycle_status
        ) values (%s,%s,%s,%s,'P0BUNIT','P0 B Unit','ACTIVE')
        """,
        (UNIT_B, ORG, PROPERTY_B, UNIT_TYPE_B),
    )
    conn.execute(
        """
        insert into resource (
          id,organization_id,property_id,code,name,resource_type,capacity,booking_mode,active
        ) values (%s,%s,%s,'P0BRES','P0 B Resource','SPA',4,'EXCLUSIVE',true)
        """,
        (RESOURCE_B, ORG, PROPERTY_B),
    )
    conn.execute(
        """
        insert into asset (
          id,organization_id,property_id,unit_id,name,asset_type,lifecycle_status
        ) values (%s,%s,%s,%s,'P0 B Asset','P0_TEST','ACTIVE')
        """,
        (ASSET_B, ORG, PROPERTY_B, UNIT_B),
    )
    conn.execute(
        """
        insert into service (
          id,organization_id,property_id,code,name,service_type,pricing_mode,
          base_price,requires_booking,requires_resource,active
        ) values (%s,%s,%s,'P0BSVC','P0 B Service','WELLNESS','FIXED',100,true,true,true)
        """,
        (SERVICE_B, ORG, PROPERTY_B),
    )
    conn.execute(
        """
        insert into channel (
          id,organization_id,property_id,code,name,channel_type,active
        ) values (%s,%s,%s,'P0BCHANNEL','P0 B Channel','DIRECT',true)
        """,
        (CHANNEL_B, ORG, PROPERTY_B),
    )
    conn.execute(
        """
        insert into investment_project (
          id,organization_id,property_id,name,status
        ) values (%s,%s,%s,'P0 B Investment','PLANNED')
        """,
        (INVESTMENT_B, ORG, PROPERTY_B),
    )

    conn.execute(
        """
        insert into reservation (
          id,organization_id,property_id,reference_code,commercial_status,booked_at,currency
        ) values (%s,%s,%s,'P0-SIBLING-RES','CONFIRMED',now(),'PLN')
        """,
        (RESERVATION_B, ORG, PROPERTY_B),
    )
    conn.execute(
        """
        insert into reservation_item (
          id,organization_id,reservation_id,unit_type_id,assigned_unit_id,
          arrival_date,departure_date,adults,status
        ) values (%s,%s,%s,%s,%s,'2027-03-01','2027-03-02',1,'ACTIVE')
        """,
        (RESERVATION_ITEM_B, ORG, RESERVATION_B, UNIT_TYPE_B, UNIT_B),
    )
    conn.execute(
        """
        insert into stay (
          id,organization_id,reservation_item_id,status,guest_count_actual
        ) values (%s,%s,%s,'EXPECTED',1)
        """,
        (STAY_B, ORG, RESERVATION_ITEM_B),
    )

    conn.execute(
        "insert into cost_center (id,organization_id,property_id,code,name) values (%s,%s,null,'P0ORGCC','P0 Organization Cost Center')",
        (ORG_COST_CENTER, ORG),
    )
    conn.execute(
        """
        insert into economic_event (
          id,organization_id,property_id,event_type,economic_date,amount,currency,status
        ) values (%s,%s,%s,'OPEX','2026-09-16',100,'PLN','DRAFT')
        """,
        (EVENT_A, ORG, PROPERTY_A),
    )
    conn.execute(
        """
        insert into economic_event (
          id,organization_id,property_id,event_type,economic_date,amount,currency,status
        ) values (%s,%s,null,'OPEX','2026-09-16',25,'PLN','DRAFT')
        """,
        (EVENT_ORG, ORG),
    )
    conn.execute(
        """
        insert into service_booking (
          id,organization_id,property_id,service_id,stay_id,reservation_id,
          requested_start_at,requested_end_at,status
        ) values (%s,%s,%s,%s,%s,%s,'2027-03-10T18:00:00+01','2027-03-10T19:00:00+01','CONFIRMED')
        """,
        (SERVICE_BOOKING_A, ORG, PROPERTY_A, SERVICE_A, STAY_A, RESERVATION_A),
    )


def test_reservation_context(conn) -> None:
    expect_context_mismatch(
        conn,
        """
        insert into reservation_item (
          id,organization_id,reservation_id,unit_type_id,arrival_date,departure_date,adults,status
        ) values ('00000000-0000-7000-8000-000000009970',%s,%s,%s,'2027-04-01','2027-04-02',1,'ACTIVE')
        """,
        (ORG, RESERVATION_A, UNIT_TYPE_B),
        "Reservation A + UnitType B rejected",
        "reservation_item.unit_type",
    )
    expect_context_mismatch(
        conn,
        """
        insert into reservation_item (
          id,organization_id,reservation_id,unit_type_id,assigned_unit_id,
          arrival_date,departure_date,adults,status
        ) values ('00000000-0000-7000-8000-000000009971',%s,%s,%s,%s,'2027-04-03','2027-04-04',1,'ACTIVE')
        """,
        (ORG, RESERVATION_A, UNIT_TYPE_A, UNIT_B),
        "Reservation A + assigned Unit B rejected",
        "reservation_item.assigned_unit",
    )


def test_stay_and_service_context(conn) -> None:
    expect_context_mismatch(
        conn,
        """
        insert into stay_segment (
          id,organization_id,stay_id,unit_id,start_at,end_at,status
        ) values ('00000000-0000-7000-8000-000000009972',%s,%s,%s,
                  '2027-04-05T15:00:00+02','2027-04-06T10:00:00+02','ACTIVE')
        """,
        (ORG, STAY_A, UNIT_B),
        "Stay A + StaySegment Unit B rejected",
        "stay_segment.unit",
    )
    expect_context_mismatch(
        conn,
        """
        insert into resource_reservation (
          id,organization_id,resource_id,service_booking_id,start_at,end_at,
          effective_start_at,effective_end_at,capacity_used,exclusive_booking,status
        ) values ('00000000-0000-7000-8000-000000009973',%s,%s,%s,
                  '2027-03-10T18:00:00+01','2027-03-10T19:00:00+01',
                  '2027-03-10T18:00:00+01','2027-03-10T19:00:00+01',1,true,'CONFIRMED')
        """,
        (ORG, RESOURCE_B, SERVICE_BOOKING_A),
        "ServiceBooking A + Resource B rejected",
        "resource_reservation",
    )


def test_operations_context(conn) -> None:
    expect_context_mismatch(
        conn,
        """
        insert into turnover (
          id,organization_id,property_id,unit_id,next_stay_id,available_from,
          ready_deadline,status,priority
        ) values ('00000000-0000-7000-8000-000000009974',%s,%s,%s,%s,
                  '2027-03-01T11:00:00+01','2027-03-01T14:00:00+01','PENDING','NORMAL')
        """,
        (ORG, PROPERTY_A, UNIT_A, STAY_B),
        "Turnover A + next Stay B rejected",
        "turnover.next_stay",
    )
    expect_context_mismatch(
        conn,
        """
        insert into incident (
          id,organization_id,property_id,asset_id,severity,status,title,
          guest_impact,safety_related,reported_at
        ) values ('00000000-0000-7000-8000-000000009975',%s,%s,%s,
                  'LOW','OPEN','P0 sibling asset incident',false,false,now())
        """,
        (ORG, PROPERTY_A, ASSET_B),
        "Incident A + Asset B rejected",
        "incident.asset",
    )


def allocation_negative(conn, row_id: str, column: str, value: str, suffix: str, label: str) -> None:
    expect_context_mismatch(
        conn,
        f"""
        insert into allocation (
          id,organization_id,economic_event_id,amount,property_id,{column},
          allocation_type,classification,confidence,rationale
        ) values (%s,%s,%s,100,%s,%s,'DIRECT','OPEX','VERIFIED','P0 same-tenant cross-property')
        """,
        (row_id, ORG, EVENT_A, PROPERTY_A, value),
        label,
        suffix,
    )


def test_financial_dimensions(conn) -> None:
    allocation_negative(conn, "00000000-0000-7000-8000-000000009976", "unit_id", UNIT_B, "allocation.unit", "Allocation A + Unit B rejected")
    allocation_negative(conn, "00000000-0000-7000-8000-000000009977", "service_id", SERVICE_B, "allocation.service", "Allocation A + Service B rejected")
    allocation_negative(conn, "00000000-0000-7000-8000-000000009978", "channel_id", CHANNEL_B, "allocation.channel", "Allocation A + Channel B rejected")
    allocation_negative(conn, "00000000-0000-7000-8000-000000009979", "investment_project_id", INVESTMENT_B, "allocation.investment_project", "Allocation A + InvestmentProject B rejected")


def test_positive_organization_level_cases(conn) -> None:
    # A Property-scoped event may use an Organization-level CostCenter whose
    # property_id is NULL. This is intentionally valid.
    conn.execute(
        """
        insert into allocation (
          id,organization_id,economic_event_id,amount,property_id,cost_center_id,
          allocation_type,classification,confidence,rationale
        ) values ('00000000-0000-7000-8000-000000009980',%s,%s,100,%s,%s,
                  'DIRECT','OPEX','VERIFIED','P0 organization cost center positive case')
        """,
        (ORG, EVENT_A, PROPERTY_A, ORG_COST_CENTER),
    )
    print("PASS Property allocation may use Organization-level CostCenter")

    # An Organization-level NON_BUSINESS fact may intentionally omit Property
    # when no Property-scoped dimension is referenced.
    conn.execute(
        """
        insert into allocation (
          id,organization_id,economic_event_id,amount,property_id,
          allocation_type,classification,confidence,rationale
        ) values ('00000000-0000-7000-8000-000000009981',%s,%s,25,null,
                  'DIRECT','NON_BUSINESS','VERIFIED','P0 organization-level NON_BUSINESS')
        """,
        (ORG, EVENT_ORG),
    )
    print("PASS organization-level NON_BUSINESS fact may omit Property")

    # Same-Property path must remain valid after all guards.
    conn.execute(
        """
        insert into reservation_item (
          id,organization_id,reservation_id,unit_type_id,assigned_unit_id,
          arrival_date,departure_date,adults,status
        ) values ('00000000-0000-7000-8000-000000009982',%s,%s,%s,%s,
                  '2027-05-01','2027-05-02',1,'ACTIVE')
        """,
        (ORG, RESERVATION_A, UNIT_TYPE_A, UNIT_A),
    )
    print("PASS valid same-Property ReservationItem remains accepted")


def main() -> None:
    conn = connect()
    try:
        setup_property_b(conn)
        test_reservation_context(conn)
        test_stay_and_service_context(conn)
        test_operations_context(conn)
        test_financial_dimensions(conn)
        test_positive_organization_level_cases(conn)
        print("PASS OSG Issue #9 same-tenant cross-Property context proof")
    finally:
        conn.rollback()
        conn.close()


if __name__ == "__main__":
    main()
