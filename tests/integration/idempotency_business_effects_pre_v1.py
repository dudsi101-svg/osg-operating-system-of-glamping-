"""OSG P0 idempotency business-effect proofs — DEV only.

Adds the acceptance cases that must be proven as real business effects:
- five concurrent deliveries of the same PMS event create exactly one
  Reservation + ExternalReference + Folio + Charge + Payment,
- duplicate rate is observable through the single processing claim attempts,
- three concurrent/retried automation attempts create exactly one Turnover.

All claim paths use INSERT .. ON CONFLICT in the same transaction as the
business effect. No SELECT-then-INSERT race is used.
"""

from __future__ import annotations

import threading
import time
from dataclasses import dataclass

import psycopg

ORG = "00000000-0000-7000-8000-000000000001"
PROPERTY = "00000000-0000-7000-8000-000000000010"
CHANNEL = "00000000-0000-7000-8000-000000000351"
FOREST = "00000000-0000-7000-8000-000000000201"


def connect():
    return psycopg.connect("")


def scalar(conn, query: str, params=()):
    return conn.execute(query, params).fetchone()[0]


@dataclass
class Result:
    outcome: str | None = None
    error: str | None = None


def run_threads(workers):
    threads = [threading.Thread(target=fn) for fn in workers]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=20)
    if any(thread.is_alive() for thread in threads):
        raise AssertionError("P0 idempotency business-effect proof timed out")


def test_concurrent_pms_replay_creates_one_commerce_chain() -> None:
    integration_id = "00000000-0000-7000-8000-000000009800"
    party_id = "00000000-0000-7000-8000-000000009801"
    guest_id = "00000000-0000-7000-8000-000000009802"
    reservation_id = "00000000-0000-7000-8000-000000009820"
    external_ref_id = "00000000-0000-7000-8000-000000009821"
    folio_id = "00000000-0000-7000-8000-000000009822"
    charge_id = "00000000-0000-7000-8000-000000009823"
    payment_id = "00000000-0000-7000-8000-000000009824"
    external_event_id = "p0-pms-commerce-replay-001"
    external_reservation_id = "P0-PMS-COMMERCE-001"

    with connect() as conn:
        conn.execute(
            """
            insert into integration (
              id,organization_id,property_id,provider,integration_type,status,
              sync_mode,credentials_reference
            ) values (%s,%s,%s,'P0 PMS','RESERVATION_SOURCE','ACTIVE',
                      'WEBHOOK_PRIMARY','secret://p0/pms')
            """,
            (integration_id, ORG, PROPERTY),
        )
        conn.execute(
            "insert into party (id,organization_id,party_type,display_name,active) values (%s,%s,'PERSON','P0 replay guest',true)",
            (party_id, ORG),
        )
        conn.execute(
            "insert into guest_profile (id,organization_id,party_id,preferred_language,crm_status) values (%s,%s,%s,'pl','ACTIVE')",
            (guest_id, ORG, party_id),
        )

    barrier = threading.Barrier(5)
    results = [Result() for _ in range(5)]

    def worker(index: int) -> None:
        processing_id = f"00000000-0000-7000-8000-00000000981{index}"
        try:
            with connect() as conn:
                barrier.wait(timeout=10)
                claim = conn.execute(
                    """
                    insert into integration_processing_record (
                      id,organization_id,integration_id,external_event_id,action_key,
                      status,attempts,first_seen_at,last_attempt_at
                    ) values (%s,%s,%s,%s,'upsert_reservation','PROCESSING',1,now(),now())
                    on conflict (integration_id,external_event_id,action_key) do nothing
                    returning id
                    """,
                    (processing_id, ORG, integration_id, external_event_id),
                ).fetchone()

                if claim:
                    conn.execute(
                        """
                        insert into reservation (
                          id,organization_id,property_id,channel_id,primary_guest_id,
                          reference_code,commercial_status,booked_at,currency,
                          source_created_at,source_updated_at
                        ) values (%s,%s,%s,%s,%s,%s,'CONFIRMED',now(),'PLN',now(),now())
                        """,
                        (reservation_id, ORG, PROPERTY, CHANNEL, guest_id, external_reservation_id),
                    )
                    conn.execute(
                        """
                        insert into external_reference (
                          id,organization_id,integration_id,external_type,external_id,
                          osg_entity_type,osg_entity_id
                        ) values (%s,%s,%s,'reservation',%s,'Reservation',%s)
                        """,
                        (external_ref_id, ORG, integration_id, external_reservation_id, reservation_id),
                    )
                    conn.execute(
                        "insert into folio (id,organization_id,reservation_id,currency,status,opened_at) values (%s,%s,%s,'PLN','OPEN',now())",
                        (folio_id, ORG, reservation_id),
                    )
                    conn.execute(
                        """
                        insert into charge (
                          id,organization_id,folio_id,charge_type,description,quantity,
                          unit_price,gross_amount,recognized_at,status
                        ) values (%s,%s,%s,'ACCOMMODATION','P0 PMS replay',1,100,100,now(),'RECOGNIZED')
                        """,
                        (charge_id, ORG, folio_id),
                    )
                    conn.execute(
                        """
                        insert into payment (
                          id,organization_id,folio_id,payer_party_id,method,provider,
                          amount,currency,status,paid_at,external_reference
                        ) values (%s,%s,%s,%s,'OTA_COLLECT','P0_PMS',100,'PLN','CONFIRMED',now(),'P0-PMS-PAY-001')
                        """,
                        (payment_id, ORG, folio_id, party_id),
                    )
                    conn.execute(
                        """
                        update integration_processing_record
                        set status='SUCCEEDED',result_reference=%s,last_attempt_at=now()
                        where id=%s
                        """,
                        (f"Reservation:{reservation_id}", processing_id),
                    )
                    time.sleep(0.20)
                    results[index].outcome = "OWNER"
                else:
                    conn.execute(
                        """
                        update integration_processing_record
                        set attempts=attempts+1,last_attempt_at=now()
                        where integration_id=%s and external_event_id=%s
                          and action_key='upsert_reservation'
                        """,
                        (integration_id, external_event_id),
                    )
                    results[index].outcome = "DUPLICATE"
        except Exception as exc:  # pragma: no cover
            results[index].error = repr(exc)

    run_threads([lambda i=i: worker(i) for i in range(5)])
    if any(r.error for r in results):
        raise AssertionError(f"PMS replay unexpected errors: {results}")
    if [r.outcome for r in results].count("OWNER") != 1 or [r.outcome for r in results].count("DUPLICATE") != 4:
        raise AssertionError(f"expected one owner + four duplicates, got {results}")

    with connect() as conn:
        processing_count = scalar(
            conn,
            "select count(*) from integration_processing_record where integration_id=%s and external_event_id=%s and action_key='upsert_reservation'",
            (integration_id, external_event_id),
        )
        attempts = scalar(
            conn,
            "select attempts from integration_processing_record where integration_id=%s and external_event_id=%s and action_key='upsert_reservation'",
            (integration_id, external_event_id),
        )
        counts = tuple(
            scalar(conn, query, (value,))
            for query, value in (
                ("select count(*) from reservation where id=%s", reservation_id),
                ("select count(*) from external_reference where id=%s", external_ref_id),
                ("select count(*) from folio where id=%s", folio_id),
                ("select count(*) from charge where id=%s", charge_id),
                ("select count(*) from payment where id=%s", payment_id),
            )
        )

    if processing_count != 1 or attempts != 5 or counts != (1, 1, 1, 1, 1):
        raise AssertionError(
            f"PMS replay leaked duplicate business effects: processing={processing_count}, "
            f"attempts={attempts}, effects={counts}"
        )
    duplicate_rate = (attempts - 1) / attempts
    print("PASS PMS x5 concurrent replay -> one Reservation/ExternalReference/Folio/Charge/Payment")
    print(f"OSG_METRIC duplicate_rate={duplicate_rate:.2f} duplicate_deliveries={attempts-1} total_deliveries={attempts}")


def test_automation_retries_create_one_turnover() -> None:
    trigger_id = "00000000-0000-7000-8000-000000009830"
    rule_id = "00000000-0000-7000-8000-000000009831"
    turnover_id = "00000000-0000-7000-8000-000000009832"
    action_key = "create-turnover:p0-retry"

    with connect() as conn:
        conn.execute(
            """
            insert into domain_event (
              id,organization_id,property_id,event_type,event_version,aggregate_type,
              aggregate_id,occurred_at,actor_type,payload
            ) values (%s,%s,%s,'Stay.CheckedOut',1,'Property',%s,now(),'SYSTEM','{}'::jsonb)
            """,
            (trigger_id, ORG, PROPERTY, PROPERTY),
        )
        conn.execute(
            """
            insert into automation_rule (
              id,organization_id,property_id,code,version_no,trigger_event_type,
              conditions,actions,active
            ) values (%s,%s,%s,'P0_CREATE_TURNOVER_RETRY',1,'Stay.CheckedOut','{}'::jsonb,'{}'::jsonb,true)
            """,
            (rule_id, ORG, PROPERTY),
        )

    barrier = threading.Barrier(3)
    results = [Result() for _ in range(3)]

    def worker(index: int) -> None:
        execution_id = f"00000000-0000-7000-8000-00000000984{index}"
        try:
            with connect() as conn:
                barrier.wait(timeout=10)
                claim = conn.execute(
                    """
                    insert into automation_execution (
                      id,organization_id,automation_rule_id,trigger_event_id,action_key,
                      status,started_at,retry_count
                    ) values (%s,%s,%s,%s,%s,'RUNNING',now(),0)
                    on conflict (automation_rule_id,trigger_event_id,action_key) do nothing
                    returning id
                    """,
                    (execution_id, ORG, rule_id, trigger_id, action_key),
                ).fetchone()
                if claim:
                    conn.execute(
                        """
                        insert into turnover (
                          id,organization_id,property_id,unit_id,available_from,
                          ready_deadline,status,priority
                        ) values (%s,%s,%s,%s,'2027-01-15T11:00:00+01',
                                  '2027-01-15T14:30:00+01','PENDING','HIGH')
                        """,
                        (turnover_id, ORG, PROPERTY, FOREST),
                    )
                    conn.execute(
                        """
                        update automation_execution
                        set status='SUCCEEDED',completed_at=now(),
                            result=jsonb_build_object('turnover_id',%s::text)
                        where id=%s
                        """,
                        (turnover_id, execution_id),
                    )
                    time.sleep(0.20)
                    results[index].outcome = "OWNER"
                else:
                    conn.execute(
                        """
                        update automation_execution
                        set retry_count=retry_count+1
                        where automation_rule_id=%s and trigger_event_id=%s and action_key=%s
                        """,
                        (rule_id, trigger_id, action_key),
                    )
                    results[index].outcome = "RETRY_DEDUPED"
        except Exception as exc:  # pragma: no cover
            results[index].error = repr(exc)

    run_threads([lambda i=i: worker(i) for i in range(3)])
    if any(r.error for r in results):
        raise AssertionError(f"automation retry unexpected errors: {results}")
    if [r.outcome for r in results].count("OWNER") != 1 or [r.outcome for r in results].count("RETRY_DEDUPED") != 2:
        raise AssertionError(f"expected one automation owner + two deduped retries, got {results}")

    with connect() as conn:
        execution_count = scalar(
            conn,
            "select count(*) from automation_execution where automation_rule_id=%s and trigger_event_id=%s and action_key=%s",
            (rule_id, trigger_id, action_key),
        )
        retry_count = scalar(
            conn,
            "select retry_count from automation_execution where automation_rule_id=%s and trigger_event_id=%s and action_key=%s",
            (rule_id, trigger_id, action_key),
        )
        turnover_count = scalar(conn, "select count(*) from turnover where id=%s", (turnover_id,))

    if (execution_count, retry_count, turnover_count) != (1, 2, 1):
        raise AssertionError(
            f"automation retry leaked effects: execution={execution_count}, retries={retry_count}, turnover={turnover_count}"
        )
    print("PASS automation x3 retry/concurrency -> one AutomationExecution + one Turnover")


def main() -> None:
    test_concurrent_pms_replay_creates_one_commerce_chain()
    test_automation_retries_create_one_turnover()
    print("PASS OSG Issue #5 business-effect idempotency acceptance")


if __name__ == "__main__":
    main()
