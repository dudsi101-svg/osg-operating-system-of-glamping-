# Glamping Nad Stawem — Reference Dataset v0.1

Status: testowy / syntetyczny
Data: 2026-09-14

## Cel

Zestaw referencyjny do testowania modelu OSG bez używania rzeczywistych danych gości i rzeczywistych transakcji. Kwoty i osoby gości są syntetyczne.

## Property

- Property: Glamping Nad Stawem
- Location: Krzesimów, woj. lubelskie
- Currency: PLN
- Timezone: Europe/Warsaw

## Units

| Code | Name | Type | Capacity |
|---|---|---|---:|
| FOR01 | Forest | Dome | 6 |
| BOH01 | Boho | Dome | 4 |
| LOF01 | Loft | Dome | 4 |
| OST01 | Ostoja | Treehouse | 4 |
| AUR01 | Aura | Wooden House | 6 |

## Resources

| Code | Resource | Booking mode | Capacity |
|---|---|---|---:|
| SAU01 | Sauna | SLOT | 6 |
| JAC01 | Jacuzzi | SLOT | 8 |
| BAL01 | Balia | SLOT | 6 |
| BOAT01 | Łódka | DURATION | 4 |
| ROOM01 | Sala warsztatowa | SLOT | 20 |

## Assets — próbka

- AST-JAC-PUMP-01 — pompa jacuzzi
- AST-JAC-FILTER-01 — filtr jacuzzi
- AST-FOR-AC-01 — klimatyzacja Forest
- AST-SAU-HEATER-01 — piec sauny

## Synthetic Guests

- GST-001 — Anna Testowa
- GST-002 — Marek Przykład
- GST-003 — Ewa Modelowa

## Reservations

### RES-2026-TEST-001
- guest: GST-001
- channel: Direct
- unit: Forest
- arrival: 2026-09-18
- departure: 2026-09-21
- adults: 2
- accommodation charge: 1 950 PLN
- payment: 1 950 PLN

### RES-2026-TEST-002
- guest: GST-002
- channel: Booking.com
- unit: Ostoja
- arrival: 2026-09-19
- departure: 2026-09-21
- accommodation charge: 2 000 PLN
- OTA commission: 300 PLN
- bank payout: 1 700 PLN

### RES-2026-TEST-003
- guest: GST-003
- channel: Direct
- unit: Forest
- arrival: 2026-09-24
- departure: 2026-09-27
- scenario: relocation after first night due to incident
- segment 1: Forest
- segment 2: Ostoja

## Service bookings

### SVCB-001
- stay: RES-2026-TEST-001
- service: Sauna 90 min
- resource: SAU01
- booked: 2026-09-19 18:00–19:30
- buffer: 30 min before / 15 min after
- charge: 120 PLN

### SVCB-002
- stay: RES-2026-TEST-001
- service: Jacuzzi 90 min
- resource: JAC01
- charge: 150 PLN

## Operating incidents

### INC-001
- unit: Forest
- asset: AST-FOR-AC-01
- severity: HIGH
- problem: failure requiring guest relocation
- creates AvailabilityBlock
- creates maintenance task
- creates WorkOrder

## Synthetic expenses

### EXP-001 — operator paid
- amount: 430 PLN
- category: cleaning supplies
- paid_by: Kuba
- economic_bearer: Glamping Nad Stawem
- classification: OPEX
- expected SettlementEntry: 430 PLN payable to Kuba

### EXP-002 — mixed vehicle expense
- document total: 8 000 PLN
- GNS allocation: 1 600 PLN OPEX
- non-business allocation: 6 400 PLN

### EXP-003 — mixed CAPEX/OPEX invoice
- construction materials: 5 000 PLN CAPEX
- pool chemicals: 800 PLN OPEX
- tools: 700 PLN pending classification

## Shared expense

### EXP-004 — electricity
- amount: 5 000 PLN
- allocation type: SHARED
- rule candidate: occupied nights + usage metering when available

## Expected outputs

Model powinien policzyć i rozróżnić:
- revenue booked,
- revenue recognized,
- bank cash received,
- OTA cost,
- Stay Contribution Margin,
- settlement balance,
- CAPEX vs OPEX,
- unit-level operating margin,
- blocked vs sellable nights,
- data confidence.

## Zasada

Ten dataset jest syntetyczny. Nie może zostać pomylony z produkcyjnymi danymi Glampingu Nad Stawem.