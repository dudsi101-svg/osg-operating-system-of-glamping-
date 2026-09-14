# OSG — M7 Metric Dictionary v0.1

Status: roboczy
Data: 2026-09-14

Każda metryka posiada wersję, source facts, numerator, denominator, filtry i grain.

## OSG_OCCUPANCY_V1
sold_sellable_unit_nights / sellable_unit_nights

Wyklucza noce z poprawnie obowiązującym AvailabilityBlock powodującym non-sellable status.

## OSG_PHYSICAL_OCCUPANCY_V1
occupied_unit_nights / physical_unit_nights

Służy do analizy rzeczywistego wykorzystania fizycznej bazy.

## OSG_ADR_V1
recognized_accommodation_revenue / sold_unit_nights

## OSG_REVPAR_V1
recognized_accommodation_revenue / sellable_unit_nights

## OSG_TREVPAR_V1
recognized_total_property_revenue / sellable_unit_nights

## OSG_ALOS_V1
completed_stay_nights / completed_stays

## OSG_DIRECT_BOOKING_SHARE_V1
direct_confirmed_reservations / all_confirmed_reservations
oraz osobna wersja revenue-weighted.

## OSG_OTA_COST_V1
recognized_ota_commissions + attributable_channel_fees

## OSG_STAY_CM_V1
stay_recognized_revenue - stay_direct_variable_costs

## OSG_UNIT_OPERATING_MARGIN_V1
unit_allocated_revenue - unit_direct_cost - unit_allocated_shared_opex

## OSG_CAPEX_PER_UNIT_V1
capex_allocated_to_unit / selected_period

## OSG_MAINTENANCE_COST_PER_UNIT_V1
maintenance_opex_allocated_to_unit / selected_period

## OSG_REPEAT_GUEST_RATE_V1
returning_guest_completed_stays / eligible_completed_stays

## OSG_UPSELL_PER_BOOKING_V1
service_and_addon_revenue / eligible_reservations

## OSG_BREAK_EVEN_OCCUPANCY_V1
fixed_operating_costs / contribution_per_available_unit_night / sellable_capacity

Wymaga jawnych założeń i nie może być przedstawiana bez wersji modelu.

## OSG_DATA_CONFIDENCE_V1
udział wartości kluczowych faktów opartych na VERIFIED + SYSTEM_DERIVED vs ESTIMATED/MANUAL/UNKNOWN.

## Zasada explainability

Każdy KPI musi prowadzić do source facts i mieć funkcję "Why this number?".
