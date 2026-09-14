# OSG — Explainability Contract v0.1

Status: pre-freeze candidate
Date: 2026-09-15

## 1. Principle

Every material number shown by OSG should answer: **Why this number?**

Explainability is a functional requirement, not a UI decoration.

## 2. Drill-down chain

### Economic result
KPI
→ classification totals
→ Allocations
→ EconomicEvents
→ FinancialDocumentLine / Charge
→ FinancialDocument / Stay / Service
→ File/source/import where applicable

### Cash
Cash KPI
→ MoneyAccount
→ CashMovement
→ bank/provider external reference
→ ReconciliationLink
→ related Payment/Document/EconomicEvent where matched

### Occupancy / RevPAR
KPI
→ UnitNightFacts
→ Unit
→ StaySegment for occupied nights
→ AvailabilityBlock for non-sellable nights
→ PropertyStayPolicy version used for the date

### Settlement
Balance
→ SettlementEntry
→ source Allocation/EconomicEvent
→ paid_by / economic_bearer
→ SettlementApplications
→ CashMovement used for repayment

## 3. Explain payload

Minimum response:
- metric code/version
- result value
- formula
- period/grain
- source fact counts
- included components
- excluded components
- confidence
- warnings/anomalies
- links/IDs for deeper drilldown

## 4. No false precision

When significant amounts are ESTIMATED/MANUAL/UNKNOWN, explanation must surface that fact.

Example:
> Economic operating result: 29,250 PLN. 91.8% of included value is VERIFIED or SYSTEM_DERIVED; 8.2% is ESTIMATED/MANUAL.

## 5. Reproducibility

Explanation must identify:
- metric version,
- AllocationRule version where used,
- PropertyStayPolicy version where relevant,
- pricing/policy snapshot where relevant,
- report `as_of` timestamp.

## 6. AI behavior

AI may summarize explanation, but must not omit material uncertainty or convert opportunity-cost estimates into actual accounting/economic loss.

When the user asks "dlaczego?", AI should prefer this source chain over speculative causal narratives.

## 7. Privacy

Explainability respects permissions. A Housekeeping user may receive operational cause without financial or guest PII details that the role cannot access.
