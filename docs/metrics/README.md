# Metryki

Ten katalog definiuje metryki OSG wraz z formułą, ziarnem, źródłami, filtrami, właścicielem i regułami jakości danych.

## Zasada nadrzędna

Metryka jest projekcją faktów, a nie niezależnym źródłem prawdy. Każdy wynik musi dać się prześledzić do danych źródłowych i wersji definicji.

## Kandydaci v1

| Metryka | Ziarno | Rdzeń definicji |
|---|---|---|
| Occupancy | Property / Unit / dzień | sprzedane unit nights / sellable unit nights |
| ADR | pobyt lub unit night | accommodation revenue / sold unit nights |
| RevPAR | Property / dzień | accommodation revenue / sellable unit nights |
| Stay Contribution Margin | Stay | przychód pobytu minus bezpośrednie koszty zmienne |
| Unit Operating Margin | Unit / okres | marża kontrybucyjna minus zaalokowane koszty operacyjne |
| Turnover lead time | Turnover | completed_at minus available_from |
| Resource utilization | Resource / okres | rzeczywiste wykorzystanie / dostępny czas |
| Reconciliation coverage | okres | wartość dopasowana / wartość wymagająca uzgodnienia |
| Estimated allocation share | okres | kwota szacunkowa / kwota wszystkich alokacji |

## Guardrails

- Physical Capacity i Sellable Capacity nie są zamienne.
- CAPEX nie obniża bieżącej marży operacyjnej.
- Lost Revenue Opportunity jest szacunkiem, nie księgową stratą.
- Płatność i wpływ bankowy nie mogą być liczone podwójnie.
