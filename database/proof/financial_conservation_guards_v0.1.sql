-- OSG financial conservation guards v0.1
-- DEV PROOF ONLY. Review against schema v0.95 before promotion.

-- ================================================================
-- PAYMENT ALLOCATION CONSERVATION
-- ================================================================

create or replace function osg_assert_payment_not_overallocated(p_payment_id uuid)
returns void language plpgsql as $$
declare
  v_amount numeric(14,2);
  v_allocated numeric(14,2);
begin
  select amount into v_amount
  from payment
  where id = p_payment_id
  for update;

  if v_amount is null then
    raise exception 'OSG_PAYMENT_NOT_FOUND';
  end if;

  select coalesce(sum(amount),0) into v_allocated
  from payment_allocation
  where payment_id = p_payment_id;

  if v_allocated > v_amount then
    raise exception 'OSG_PAYMENT_OVERALLOCATED payment=% amount=% allocated=%', p_payment_id, v_amount, v_allocated;
  end if;
end $$;

-- Recommended use: application transaction calls after each allocation batch.
-- Alternative after proof: deferred constraint trigger.

-- ================================================================
-- SETTLEMENT CONSERVATION
-- ================================================================

create or replace function osg_assert_settlement_not_overapplied(p_settlement_id uuid)
returns void language plpgsql as $$
declare
  v_amount numeric(14,2);
  v_applied numeric(14,2);
begin
  select amount into v_amount
  from settlement_entry
  where id = p_settlement_id
  for update;

  if v_amount is null then
    raise exception 'OSG_SETTLEMENT_NOT_FOUND';
  end if;

  select coalesce(sum(amount),0) into v_applied
  from settlement_application
  where settlement_entry_id = p_settlement_id;

  if v_applied > v_amount then
    raise exception 'OSG_SETTLEMENT_OVER_APPLIED settlement=% amount=% applied=%', p_settlement_id, v_amount, v_applied;
  end if;
end $$;

-- ================================================================
-- CHARGE COVERAGE HELPER
-- ================================================================

create or replace function osg_charge_applied_amount(p_charge_id uuid)
returns numeric language sql stable as $$
  select coalesce(sum(pa.amount),0)::numeric
  from payment_allocation pa
  join payment p on p.id = pa.payment_id
  where pa.charge_id = p_charge_id
    and p.status in ('CONFIRMED','PARTIALLY_REFUNDED');
$$;

-- This is a read helper only. Charge-level overcoverage/refund semantics require
-- commerce service rules because discounts/reversals/refunds can alter the
-- effective charge balance.

-- ================================================================
-- REQUIRED CONCURRENT TEST
-- ================================================================
-- Two DB connections must attempt to allocate the remaining payment/settlement
-- balance simultaneously. The `FOR UPDATE` lock must serialize the check.
-- A safe application use-case should insert/update and assert within the same
-- transaction while holding the parent row lock.
