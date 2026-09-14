# OSG — Maintenance & Asset Lifecycle v0.1

Status: kandydat implementacyjny
Data: 2026-09-14

## 1. Cel

Połączyć Asset, Incident, WorkOrder, downtime i koszty tak, aby OSG umiał odpowiedzieć nie tylko `co się zepsuło?`, ale również `ile to nas kosztuje i czy naprawa nadal ma sens?`.

## 2. Asset lifecycle

PLANNED → ORDERED → INSTALLED → ACTIVE → DEGRADED → FAILED → REPAIRED/ACTIVE → RETIRED

Status jest historią zdarzeń, nie jedynym opisem całego życia Asset.

## 3. Maintenance types

REACTIVE
PREVENTIVE
INSPECTION
WARRANTY
UPGRADE
SAFETY

## 4. Preventive plan

MaintenancePlan:
- asset_id/resource_id
- task template
- interval calendar/usage
- next_due_at
- tolerance window
- criticality

Plan generuje Task/WorkOrder, ale wykonanie jest osobnym faktem.

## 5. Incident chain

Incident.Reported
→ triage
→ optional AvailabilityBlock
→ Task/WorkOrder
→ WorkLog
→ FinancialDocument/EconomicEvent
→ Asset maintenance history
→ inspection
→ resolved/unblocked

## 6. Downtime

Downtime nie jest wyłącznie Incident duration.
Rejestrujemy okres realnej niedostępności Asset/Resource/Unit.
Możliwy jest Incident otwarty bez pełnego downtime oraz downtime po technicznym rozwiązaniu do czasu inspekcji.

## 7. Cost of ownership

Asset TCO może agregować:
- acquisition CAPEX
- installation CAPEX
- maintenance OPEX
- replacement parts
- external service
- estimated lost revenue (oznaczone jako estimation)

Nie mieszamy lost revenue z rzeczywistym kosztem.

## 8. Replace vs repair support

OSG może później sugerować wymianę na podstawie:
- repair frequency
- cumulative maintenance cost
- downtime
- age
- warranty
- energy/operating cost
- guest impact

AI recommendation nie zmienia automatycznie Asset lifecycle.

## 9. Criticality

LOW
MEDIUM
HIGH
CRITICAL

Przykład: dekoracyjna lampa vs pompa jacuzzi vs ogrzewanie Unit mogą mieć inną krytyczność i SLA.

## 10. Warranty

WorkOrder/Incident może zostać oznaczony jako warranty claim. Koszt brutto usługi i odzysk/refund są osobnymi faktami Financial Truth.

## 11. Metrics

- MTBF
- MTTR
- downtime hours
- maintenance cost / asset
- maintenance cost / unit
- incidents / 100 occupied nights
- preventive compliance
- repeat failure rate

## 12. Invariants

MAINT-001 — Asset retirement nie usuwa historii.
MAINT-002 — WorkOrder actual cost nie zastępuje Financial Truth.
MAINT-003 — AvailabilityBlock powiązany z awarią zachowuje source Incident.
MAINT-004 — preventive Task completion wymaga WorkLog, jeśli plan tego wymaga.
MAINT-005 — warranty recovery jest osobnym economic/cash fact.