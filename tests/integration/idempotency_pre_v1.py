"""OSG P0 Idempotency & deduplication proof — DEV only.

Covers the concurrency-critical core of Issue #5:
- concurrent integration delivery claim: exactly one claimant
- sequential PMS ×5 domain-effect scenario is already loaded by scenario 08
- concurrent command claim using INSERT .. ON CONFLICT, never SELECT-then-INSERT
- same key + same hash after success => deterministic replay
- same key + different hash => payload mismatch
- duplicate Financial posting command => one POSTED effect
- concurrent automation retry => one AutomationExecution + one Notification

The CI database is disposable; posted proof facts are intentionally not deleted.
"""

from __future__ import annotations

import json
import threading
import time
from dataclasses import dataclass

import psycopg

ORG = "00000000-0000-7000-8000-000000000001"
PROPERTY = "00000000-0000-7000-8000-000000000010"
INTEGRATION = "00000000-0000-7000-8000-000000001501"  # scenario 08
AUTOMATION_RULE = "00000000-0000-7000-8000-000000001921"  # scenario 12
TRIGGER_EVENT = "00000000-0000-7000-8000-000000001920"  # scenario 12
OPERATOR_ROLE = "00000000-0000-7000-8000-000000001901"  # scenario 12
TURNOVER = "00000000-0000-7000-8000-000000001910"  # scenario 12


def connect():
    return psycopg.connect("")


def scalar(conn, query: str, params=()):
    return conn.execute(query, params).fetchone()[0]


@dataclass
class Result:
    outcome: str | None = None
    error: str | None = None


def test_concurrent_integration_claim() -> None:
    """Five simultaneous deliveries must yield exactly one processing claim."""

    barrier = threading.Barrier(5)
    results = [Result() for _ in range(5)]
    ids = [f"00000000-0000-7000-8000-00000000960{i}" for i in range(5)]

    def worker(index: int) -> None:
        try:
            with connect() as conn:
                barrier.wait(timeout=10)
                row = conn.execute(
                    """
                    insert into integration_processing_record (
                      id,organization_id,integration_id,external_event_id,action_key,
                      status,attempts,first_seen_at,last_attempt_at
                    ) values (%s,%s,%s,'evt-p0-concurrent','upsert_reservation',
                              'PROCESSING',1,now(),now())
                    on conflict (integration_id,external_event_id,action_key) do nothing
                    returning id
                    """,
                    (ids[index], ORG, INTEGRATION),
                ).fetchone()
                if row:
                    # Keep the unique claim uncommitted briefly so competitors
                    # actually contend on the same key.
                    time.sleep(0.25)
                    results[index].outcome = "CLAIMED"
                else:
                    results[index].outcome = "DUPLICATE"
        except Exception as exc:  # pragma: no cover - diagnostic path
            results[index].error = repr(exc)

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(5)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=15)

    if any(t.is_alive() for t in threads):
        raise AssertionError("integration idempotency concurrency proof timed out")
    if any(r.error for r in results):
        raise AssertionError(f"integration claim unexpected errors: {results}")
    outcomes = [r.outcome for r in results]
    if outcomes.count("CLAIMED") != 1 or outcomes.count("DUPLICATE") != 4:
        raise AssertionError(f"expected 1 claim + 4 duplicates, got {outcomes}")

    with connect() as conn:
        count = scalar(
            conn,
            """
            select count(*) from integration_processing_record
            where integration_id=%s
              and external_event_id='evt-p0-concurrent'
              and action_key='upsert_reservation'
            """,
            (INTEGRATION,),
        )
        # Scenario 08 already proved 5 sequential deliveries of PMS-RES-001
        # remain one Reservation domain effect. Reassert that invariant here.
        reservation_count = scalar(
            conn,
            "select count(*) from reservation where reference_code='PMS-RES-001'",
        )
    if count != 1:
        raise AssertionError(f"integration claim count expected 1, got {count}")
    if reservation_count != 1:
        raise AssertionError(f"PMS-RES-001 domain effect expected 1, got {reservation_count}")
    print("PASS integration ×5 concurrent claim: one processing owner; PMS domain effect remains one")


def claim_command(
    conn,
    *,
    row_id: str,
    principal: str,
    command_name: str,
    key: str,
    request_hash: str,
    aggregate_type: str | None = None,
    aggregate_id: str | None = None,
):
    """Atomic command claim contract used by the proof.

    The INSERT is the claim. We intentionally do not SELECT before INSERT.
    PostgreSQL uniqueness serializes concurrent same-key claimants.
    """

    inserted = conn.execute(
        """
        insert into command_idempotency (
          id,organization_id,property_id,principal_key,command_name,
          idempotency_key,request_hash,status,aggregate_type,aggregate_id
        ) values (%s,%s,%s,%s,%s,%s,%s,'IN_PROGRESS',%s,%s)
        on conflict (organization_id,principal_key,command_name,idempotency_key)
        do nothing
        returning id
        """,
        (
            row_id,
            ORG,
            PROPERTY,
            principal,
            command_name,
            key,
            request_hash,
            aggregate_type,
            aggregate_id,
        ),
    ).fetchone()

    if inserted:
        return "CLAIMED", str(inserted[0]), None

    existing = conn.execute(
        """
        select id,request_hash,status,http_status,response_body
        from command_idempotency
        where organization_id=%s
          and principal_key=%s
          and command_name=%s
          and idempotency_key=%s
        """,
        (ORG, principal, command_name, key),
    ).fetchone()
    if existing is None:
        raise AssertionError("idempotency conflict occurred but existing claim is not visible")
    if existing[1] != request_hash:
        return "PAYLOAD_MISMATCH", str(existing[0]), None
    if existing[2] == "SUCCEEDED":
        return "REPLAY", str(existing[0]), existing[4]
    return existing[2], str(existing[0]), existing[4]


def test_duplicate_financial_command_one_effect() -> None:
    event_id = "00000000-0000-7000-8000-000000009620"
    allocation_id = "00000000-0000-7000-8000-000000009621"
    command_ids = [
        "00000000-0000-7000-8000-000000009622",
        "00000000-0000-7000-8000-000000009623",
    ]
    domain_ids = [
        "00000000-0000-7000-8000-000000009624",
        "00000000-0000-7000-8000-000000009625",
    ]
    outbox_ids = [
        "00000000-0000-7000-8000-000000009626",
        "00000000-0000-7000-8000-000000009627",
    ]
    principal = "user:p0-idempotency"
    command = "PostEconomicEvent"
    key = "p0-fin-post-0001"
    request_hash = "sha256:p0-fin-post-request-v1"

    with connect() as conn:
        conn.execute(
            """
            insert into economic_event (
              id,organization_id,property_id,event_type,economic_date,amount,currency,status
            ) values (%s,%s,%s,'OPEX','2026-09-16',120,'PLN','DRAFT')
            """,
            (event_id, ORG, PROPERTY),
        )
        conn.execute(
            """
            insert into allocation (
              id,organization_id,economic_event_id,amount,property_id,
              allocation_type,classification,confidence,allocation_method,rationale
            ) values (%s,%s,%s,120,%s,'DIRECT','OPEX','VERIFIED',
                      'P0_IDEMPOTENCY','command-idempotency proof')
            """,
            (allocation_id, ORG, event_id, PROPERTY),
        )

    barrier = threading.Barrier(2)
    results = [Result(), Result()]

    def worker(index: int) -> None:
        try:
            with connect() as conn:
                barrier.wait(timeout=10)
                outcome, ledger_id, response = claim_command(
                    conn,
                    row_id=command_ids[index],
                    principal=principal,
                    command_name=command,
                    key=key,
                    request_hash=request_hash,
                    aggregate_type="EconomicEvent",
                    aggregate_id=event_id,
                )
                if outcome == "CLAIMED":
                    conn.execute(
                        "select osg_post_economic_event_v02(%s,%s,%s,%s,%s)",
                        (ORG, event_id, None, domain_ids[index], outbox_ids[index]),
                    )
                    body = json.dumps({"economic_event_id": event_id, "status": "POSTED"})
                    conn.execute(
                        """
                        update command_idempotency
                        set status='SUCCEEDED',http_status=200,
                            response_body=%s::jsonb,completed_at=now()
                        where id=%s
                        """,
                        (body, ledger_id),
                    )
                    time.sleep(0.30)
                    results[index].outcome = "CLAIMED_POSTED"
                elif outcome == "REPLAY":
                    results[index].outcome = "REPLAY"
                else:
                    results[index].error = f"unexpected command outcome {outcome}"
        except Exception as exc:  # pragma: no cover
            results[index].error = repr(exc)

    threads = [threading.Thread(target=worker, args=(0,)), threading.Thread(target=worker, args=(1,))]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=15)

    if any(t.is_alive() for t in threads):
        raise AssertionError("command-idempotency concurrency proof timed out")
    if any(r.error for r in results):
        raise AssertionError(f"command-idempotency unexpected errors: {results}")
    outcomes = sorted(r.outcome for r in results)
    if outcomes != ["CLAIMED_POSTED", "REPLAY"]:
        raise AssertionError(f"expected one mutation + one replay, got {outcomes}")

    with connect() as conn:
        ledger_count = scalar(
            conn,
            """
            select count(*) from command_idempotency
            where organization_id=%s and principal_key=%s
              and command_name=%s and idempotency_key=%s
            """,
            (ORG, principal, command, key),
        )
        status = scalar(conn, "select status from economic_event where id=%s", (event_id,))
        domain_count = scalar(
            conn,
            "select count(*) from domain_event where aggregate_id=%s and event_type='EconomicEvent.Posted'",
            (event_id,),
        )
        outbox_count = scalar(
            conn,
            """
            select count(*) from outbox_event o
            join domain_event d on d.organization_id=o.organization_id and d.id=o.domain_event_id
            where d.aggregate_id=%s and d.event_type='EconomicEvent.Posted'
            """,
            (event_id,),
        )
        replay_outcome, _, replay_body = claim_command(
            conn,
            row_id="00000000-0000-7000-8000-000000009628",
            principal=principal,
            command_name=command,
            key=key,
            request_hash=request_hash,
            aggregate_type="EconomicEvent",
            aggregate_id=event_id,
        )
        mismatch_outcome, _, _ = claim_command(
            conn,
            row_id="00000000-0000-7000-8000-000000009629",
            principal=principal,
            command_name=command,
            key=key,
            request_hash="sha256:DIFFERENT-PAYLOAD",
            aggregate_type="EconomicEvent",
            aggregate_id=event_id,
        )

    if ledger_count != 1 or status != "POSTED" or domain_count != 1 or outbox_count != 1:
        raise AssertionError(
            f"duplicate command leaked effects: ledger={ledger_count}, status={status}, domain={domain_count}, outbox={outbox_count}"
        )
    if replay_outcome != "REPLAY" or replay_body is None:
        raise AssertionError("same key/hash did not replay committed response")
    if mismatch_outcome != "PAYLOAD_MISMATCH":
        raise AssertionError("same key with different request hash was not rejected as mismatch")
    print("PASS concurrent command idempotency: one Financial POST + deterministic replay + payload mismatch")


def test_concurrent_automation_retry_one_effect() -> None:
    action_key = "notify-turnover:p0-concurrency"
    notification_key = "p0-turnover-risk-concurrency"
    execution_ids = [
        "00000000-0000-7000-8000-000000009640",
        "00000000-0000-7000-8000-000000009641",
    ]
    notification_ids = [
        "00000000-0000-7000-8000-000000009642",
        "00000000-0000-7000-8000-000000009643",
    ]

    barrier = threading.Barrier(2)
    results = [Result(), Result()]

    def worker(index: int) -> None:
        try:
            with connect() as conn:
                barrier.wait(timeout=10)
                claimed = conn.execute(
                    """
                    insert into automation_execution (
                      id,organization_id,automation_rule_id,trigger_event_id,
                      action_key,status,started_at,retry_count
                    ) values (%s,%s,%s,%s,%s,'RUNNING',now(),0)
                    on conflict (automation_rule_id,trigger_event_id,action_key)
                    do nothing returning id
                    """,
                    (execution_ids[index], ORG, AUTOMATION_RULE, TRIGGER_EVENT, action_key),
                ).fetchone()
                if claimed:
                    conn.execute(
                        """
                        insert into notification (
                          id,organization_id,property_id,target_role_id,severity,
                          category,title,body,subject_type,subject_id,deduplication_key
                        ) values (%s,%s,%s,%s,'ACTION_REQUIRED','P0_IDEMPOTENCY',
                                  'P0 turnover idempotency','One automation effect only',
                                  'Turnover',%s,%s)
                        on conflict (organization_id,deduplication_key) do nothing
                        """,
                        (notification_ids[index], ORG, PROPERTY, OPERATOR_ROLE, TURNOVER, notification_key),
                    )
                    conn.execute(
                        """
                        update automation_execution
                        set status='SUCCEEDED',completed_at=now(),result=%s::jsonb
                        where id=%s
                        """,
                        (json.dumps({"notification_key": notification_key}), str(claimed[0])),
                    )
                    time.sleep(0.25)
                    results[index].outcome = "EFFECT_CREATED"
                else:
                    results[index].outcome = "DUPLICATE_SKIPPED"
        except Exception as exc:  # pragma: no cover
            results[index].error = repr(exc)

    threads = [threading.Thread(target=worker, args=(0,)), threading.Thread(target=worker, args=(1,))]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=15)

    if any(t.is_alive() for t in threads):
        raise AssertionError("automation idempotency concurrency proof timed out")
    if any(r.error for r in results):
        raise AssertionError(f"automation idempotency unexpected errors: {results}")
    outcomes = sorted(r.outcome for r in results)
    if outcomes != ["DUPLICATE_SKIPPED", "EFFECT_CREATED"]:
        raise AssertionError(f"expected one automation effect + one duplicate skip, got {outcomes}")

    with connect() as conn:
        execution_count = scalar(
            conn,
            """
            select count(*) from automation_execution
            where automation_rule_id=%s and trigger_event_id=%s and action_key=%s
            """,
            (AUTOMATION_RULE, TRIGGER_EVENT, action_key),
        )
        notification_count = scalar(
            conn,
            "select count(*) from notification where organization_id=%s and deduplication_key=%s",
            (ORG, notification_key),
        )
    if execution_count != 1 or notification_count != 1:
        raise AssertionError(
            f"automation retry leaked duplicate effects: executions={execution_count}, notifications={notification_count}"
        )
    print("PASS concurrent automation retry: one execution claim + one downstream notification")


def main() -> None:
    test_concurrent_integration_claim()
    test_duplicate_financial_command_one_effect()
    test_concurrent_automation_retry_one_effect()
    print("PASS OSG Issue #5 idempotency core concurrency proof")


if __name__ == "__main__":
    main()
