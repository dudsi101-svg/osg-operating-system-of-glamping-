# OSG — M5 Financial Truth Specification v0.1

Status: roboczy zaawansowany
Data: 2026-09-14

## 1. Cel

Financial Truth Engine ma utrzymywać równolegle kilka prawd finansowych bez ich mieszania:
- accounting truth
- cash truth
- operating truth
- economic truth
- investment truth

## 2. Cztery podstawowe fakty

### FinancialDocument
Dokument księgowy/źródłowy. Nie przesądza o ekonomicznej kwalifikacji.

### CashMovement
Rzeczywisty ruch pieniędzy pomiędzy MoneyAccounts.

### EconomicEvent
Biznesowe znaczenie ekonomiczne zdarzenia.

### Allocation
Przypisanie EconomicEvent do wymiarów biznesowych.

## 3. Zasada niezależności

Brak FinancialDocument nie wyklucza CashMovement.
Brak CashMovement nie wyklucza EconomicEvent.
FinancialDocument nie tworzy automatycznie OPEX/CAPEX.
CashMovement nie tworzy automatycznie kosztu/przychodu.

## 4. EconomicEvent types v0.1

REVENUE
OPEX
CAPEX
OTA_COMMISSION
PAYMENT_FEE
REFUND
TAX
OWNER_CONTRIBUTION
OWNER_WITHDRAWAL
TRANSFER
SETTLEMENT
WRITE_OFF
ROUNDING
ADJUSTMENT

## 5. Lifecycle

DRAFT → REVIEWED → POSTED → REVERSED

POSTED jest immutable.
Korekta tworzy reversal + corrected event.

## 6. Allocation

Posted EconomicEvent musi być w pełni zaalokowany.

Allocation fields:
- economic_event_id
- amount
- property_id
- unit_id optional
- stay_id optional
- resource_id optional
- asset_id optional
- service_id optional
- channel_id optional
- investment_project_id optional
- cost_center_id optional
- paid_by_party_id optional
- economic_bearer_party_id optional
- allocation_type
- classification CAPEX/OPEX/NON_BUSINESS/OTHER
- confidence
- allocation_method
- rationale

## 7. Allocation types

DIRECT — jednoznaczny koszt/przychód obiektu/wymiaru.
SHARED — koszt wspólny wymagający reguły podziału.
OVERHEAD — koszt ogólny organizacji/property.
NON_BUSINESS — nie powinien wpływać na ekonomiczny wynik OSG property.

## 8. Confidence

VERIFIED
SYSTEM_DERIVED
ESTIMATED
MANUAL
UNKNOWN

Każdy ESTIMATED/MANUAL musi posiadać rationale.

## 9. Shared Allocation Rules

Dopuszczalne basis:
- EQUAL
- REVENUE_SHARE
- OCCUPIED_NIGHTS
- AVAILABLE_NIGHTS
- AREA_M2
- GUEST_NIGHTS
- USAGE_METER
- MANUAL_PERCENTAGE
- CUSTOM_VERSIONED_RULE

Reguła musi być wersjonowana i odtwarzalna historycznie.

## 10. Settlements

SettlementEntry powstaje, gdy economic bearer i rzeczywisty payer są różni.

Przykład:
Kuba płaci 430 PLN za koszt w 100% należący do glampingu.
System tworzy należność 430 PLN na rzecz Kuby.

Saldo settlement jest projekcją wpisów i zastosowanych rozliczeń.

## 11. Reconciliation

ReconciliationLink łączy fakty, ale ich nie scala.

Przykłady:
FinancialDocument ↔ CashMovement
FinancialDocumentLine ↔ EconomicEvent
Payment ↔ CashMovement
SettlementApplication ↔ CashMovement

Status:
UNMATCHED
PARTIAL
MATCHED
CONFLICT
IGNORED

## 12. Recognition dates

OSG rozdziela:
- document_date
- service_date
- cash_date
- economic_date
- posting_date

Raport ekonomiczny korzysta z economic_date.
Cash report korzysta z cash_date.

## 13. Period close

Okres może być:
OPEN
SOFT_CLOSED
HARD_CLOSED

SOFT_CLOSED — zmiany wymagają approval.
HARD_CLOSED — brak modyfikacji; korekty przez adjustment/reversal w dozwolonym okresie lub controlled reopen.

## 14. P&L hierarchy

Revenue
- direct variable costs
= Contribution Margin
- shared operating costs
- overhead
= Economic Operating Result

CAPEX prezentowany osobno.
Cash result prezentowany osobno.
Accounting result prezentowany osobno.

## 15. Stay Contribution Margin

Stay Revenue
- OTA commissions
- payment fees
- direct housekeeping
- direct consumables
- direct service costs
- other direct variable costs
= Stay Contribution Margin

## 16. Unit Economics

Allocated Revenue
- Direct Variable Cost
= Unit Contribution Margin
- Allocated Shared OPEX
= Unit Operating Margin

CAPEX nie jest mieszany z bieżącym Unit Operating Margin.

## 17. Approval principles

Approval wymagany co najmniej dla:
- manual/estimated allocation powyżej konfigurowalnego progu
- changes to posted-period adjustments
- NON_BUSINESS reclassification o dużej wartości
- CAPEX bez InvestmentProject powyżej progu
- settlement manual correction

## 18. Explainability

Każdy wynik ekonomiczny musi pozwalać zejść:
KPI → aggregate → allocations → economic events → documents/cash/source.

## 19. Data Quality controls

DQ examples:
- posted event not fully allocated
- cash movement unreconciled above SLA
- CAPEX missing project above threshold
- estimated allocation without rationale
- payment confirmed without expected reconciliation path
- settlement aging above threshold

## 20. Open decisions

- exact approval thresholds
- CAPEX small asset threshold
- period-close schedule
- rules for tax/VAT view
- treatment of depreciation in managerial view
