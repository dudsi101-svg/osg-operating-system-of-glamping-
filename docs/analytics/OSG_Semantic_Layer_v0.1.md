# OSG — Semantic Layer v0.1

Status: kandydat implementacyjny
Data: 2026-09-14

## 1. Cel

Zbudować kontrolowaną warstwę znaczeniową pomiędzy relacyjnym Core a dashboardami, raportami i AI.

Semantic Layer odpowiada za jednoznaczne definicje biznesowe, a nie za przechowywanie surowych faktów.

## 2. Zasada

Raw tables → Domain Facts → Semantic Measures → Metrics → Views/API/AI

Dashboard ani AI nie powinny samodzielnie rekonstruować definicji KPI z przypadkowego zestawu tabel.

## 3. Dimensions

Canonical dimensions v0.1:
- Organization
- Property
- Unit / UnitType
- Resource
- Stay
- Guest segment
- Channel
- Service
- CostCenter
- Economic classification
- InvestmentProject
- Date / accounting/economic/cash date dimensions

## 4. Facts

Canonical facts:
- sellable_unit_night
- sold_unit_night
- stay_revenue
- service_revenue
- economic_event
- allocation
- cash_movement
- turnover
- incident_downtime
- resource_usage
- settlement

## 5. Measures

Examples:
- recognized_accommodation_revenue
- recognized_service_revenue
- direct_variable_cost
- shared_opex
- capex
- ota_cost
- guest_nights
- occupied_unit_nights
- sellable_unit_nights

## 6. Metric contract

Każda metric definition posiada:
- metric_id
- version
- name
- description
- grain
- measure expression
- required filters
- time semantics
- source facts
- confidence behavior
- owner
- deprecated_at optional

## 7. Time semantics

Semantic Layer musi jawnie rozróżniać:
- booking date
- stay date
- economic date
- cash date
- posting date

Zapytanie bez określonej semantyki czasu używa domyślnej polityki metryki, nie arbitralnej daty tabeli.

## 8. Financial views

Oddzielne semantic views:
ACCOUNTING_VIEW
CASH_VIEW
OPERATING_VIEW
ECONOMIC_VIEW
INVESTMENT_VIEW

Nie istnieje jedna magiczna kolumna `profit`.

## 9. AI access

AI otrzymuje narzędzia/queries na poziomie semantycznym, np.:
- get_economic_result(property, period)
- get_unit_operating_margin(unit, period)
- get_stay_contribution_margin(stay)
- get_occupancy(property, period, metric_version)
- explain_metric(metric_result_id)

## 10. Why this number?

Każdy wynik semantic query posiada lineage:
metric version → measures → source facts → entity ids.

## 11. Caching

Cache jest dopuszczalny dla derived views, ale cache key musi obejmować:
- organization
- property where relevant
- metric id/version
- filters
- time range
- data revision/checkpoint

## 12. Versioning

Zmiana definicji KPI tworzy nową wersję. Historyczne raporty mogą wskazywać używaną wersję.

## 13. Confidence propagation

Jeżeli source facts zawierają ESTIMATED/MANUAL/UNKNOWN, wynik analityczny propaguje quality metadata.

## 14. Release 1 semantic scope

- Occupancy
- ADR
- RevPAR
- TRevPAR
- Stay Contribution Margin
- Unit Operating Margin
- OTA Cost
- CAPEX by unit/project
- Settlement balances
- Data Confidence

## 15. Non-goal

Semantic Layer nie zastępuje transactional Core i nie może być miejscem ręcznej korekty faktów.