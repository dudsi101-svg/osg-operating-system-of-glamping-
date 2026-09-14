-- OSG Financial Posting Workflow proof v0.1
-- Illustrative transaction-safe PostgreSQL function.

CREATE OR REPLACE FUNCTION osg_post_economic_event(p_event_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
  v_amount numeric(18,4);
  v_allocated numeric(18,4);
  v_org uuid;
BEGIN
  SELECT status, amount, organization_id
    INTO v_status, v_amount, v_org
  FROM economic_events
  WHERE id = p_event_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ECONOMIC_EVENT_NOT_FOUND';
  END IF;

  IF v_status NOT IN ('DRAFT','REVIEWED') THEN
    RAISE EXCEPTION 'ECONOMIC_EVENT_INVALID_STATE';
  END IF;

  SELECT COALESCE(SUM(amount),0)
    INTO v_allocated
  FROM allocations
  WHERE economic_event_id = p_event_id;

  IF round(v_allocated, 2) <> round(v_amount, 2) THEN
    RAISE EXCEPTION 'ECONOMIC_EVENT_NOT_FULLY_ALLOCATED';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM allocations a
    WHERE a.economic_event_id = p_event_id
      AND a.organization_id <> v_org
  ) THEN
    RAISE EXCEPTION 'TENANT_BOUNDARY_VIOLATION';
  END IF;

  -- Approval and period-close checks belong here/service transaction.

  UPDATE economic_events
  SET status = 'POSTED', posted_at = now()
  WHERE id = p_event_id;

  INSERT INTO event_outbox (
    id, organization_id, event_type, event_version,
    aggregate_type, aggregate_id, occurred_at, payload
  ) VALUES (
    gen_random_uuid(), v_org, 'EconomicEvent.Posted', 1,
    'EconomicEvent', p_event_id, now(),
    jsonb_build_object(
      'economic_event_id', p_event_id,
      'amount', v_amount,
      'allocation_count', (SELECT count(*) FROM allocations WHERE economic_event_id = p_event_id)
    )
  );
END;
$$;

-- Required companion controls for production:
-- 1. trigger preventing UPDATE/DELETE of POSTED economic_events except controlled reversal metadata
-- 2. trigger preventing allocation mutation after event POSTED
-- 3. financial period check
-- 4. approval check
-- 5. deterministic UUIDv7 implementation/application generation
