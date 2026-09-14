# OSG — Revenue Engine v0.1

Status: foundation contract
Data: 2026-09-14

## 1. Cel

Zbudować warstwę pomiaru i decyzji cenowych bez przedwczesnego automatyzowania cen przez AI.

## 2. Fazy

R1 MEASURE — poprawne occupancy, ADR, RevPAR, pace, channel cost.
R2 SUGGEST — deterministyczne pricing rules i rekomendacje.
R3 PREDICT — forecast/popyt.
R4 OPTIMIZE — dynamic pricing automation z guardrails.

Release 1 obejmuje głównie R1.

## 3. Rate concepts

RatePlan — warunki handlowe.
BaseRate — punkt odniesienia.
PublishedRate — cena rzeczywiście udostępniona kanałowi.
BookedRateSnapshot — cena i warunki w momencie sprzedaży.
SuggestedRate — rekomendacja, nigdy historyczna prawda sprzedaży.

## 4. Dimensions

Cena może zależeć od:
- property/unit type
- date
- day of week
- season
- lead time
- length of stay
- occupancy
- channel
- package/rate plan
- event/holiday flag

## 5. Booking pace

Snapshoty lub odtwarzalne fakty mają umożliwić pytania:
- ile nocy było sprzedanych D-30/D-14/D-7,
- jak szybko sprzedają się weekendy,
- jaki lead time ma dany UnitType/channel.

## 6. Pickup

Pickup = zmiana booked unit nights/revenue między dwoma punktami czasu dla tego samego stay-date range.

## 7. Channel economics

Revenue Engine nie porównuje kanałów wyłącznie po gross ADR.
Uwzględnia co najmniej:
- commission
- payment/channel fees
- cancellation/no-show profile
- optional acquisition cost
- contribution margin.

## 8. Pricing rule v1

Deterministyczna reguła może mieć:
conditions → adjustment → guardrails.

Przykład:
weekend + occupancy_30d > 80% → suggest +8%

Suggestion nie publikuje ceny automatycznie bez osobnego workflow.

## 9. Guardrails przyszłego dynamic pricing

- min_rate
- max_rate
- max daily change
- owner approval threshold
- blackout/fixed dates
- package constraints
- channel parity policy if applicable

## 10. Forecast separation

Booked Revenue = faktyczne zobowiązania.
Forecast Revenue = model.
Potential Revenue = scenario.
Nie mieszamy ich w jednej kolumnie.

## 11. Metrics

- occupancy
- ADR
- RevPAR
- TRevPAR
- booking pace
- pickup
- lead time
- ALOS
- direct share
- OTA cost
- channel contribution margin
- cancellation rate

## 12. AI boundary

AI może wyjaśniać i rekomendować. Dopiero po odpowiedniej historii danych może wpływać na SuggestedRate. PublishedRate pozostaje kontrolowaną akcją z audytem.

## 13. Data readiness gate for AI pricing

Przed użyciem predykcyjnego pricing wymagamy:
- odpowiedniej długości historii,
- poprawnej sellable capacity,
- stabilnego channel mapping,
- wiarygodnych rates snapshots,
- znanej sezonowości/eventów,
- jakości danych powyżej ustalonego progu.