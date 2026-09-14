# OSG — Information Architecture v0.1

Status: roboczy
Data: 2026-09-14

## Cel

Przełożyć model domenowy na przyszłą strukturę aplikacji bez uzależniania danych od ekranów.

## Główna nawigacja

1. Command Center
2. Calendar & Stays
3. Operations
4. Property
5. Experiences
6. Guests
7. Finance
8. Revenue & Analytics
9. Maintenance
10. Integrations
11. Settings

## Command Center

Nie posiada własnych faktów. Składa projekcję z:
- arrivals/departures
- turnover readiness
- service schedule
- incidents
- critical data-quality issues
- cash/settlement alerts
- occupancy/revenue snapshot

## Calendar & Stays

Widoki:
- timeline units
- reservation list
- arrivals
- departures
- stay details
- folio snapshot

## Operations

Widoki:
- Today
- turnovers
- tasks
- incidents
- workload
- stock alerts later

Operator powinien dostać odpowiedź na: co robić teraz, co jest blokowane, co grozi gościowi/pobytowi.

## Property

Widoki:
- units
- resources
- assets
- availability blocks
- unit economics drilldown
- maintenance history

## Experiences

- service catalog
- service schedule
- resource calendar
- package catalog
- service margin

## Guests

- guest profile
- history of stays
- communication timeline
- preferences/consents
- repeat guest indicators

## Finance

Podział obowiązkowy:
- Overview
- Documents
- Cash
- Economic Events
- Allocations
- Settlements
- CAPEX
- Reconciliation
- Data Quality

Nie tworzymy jednego ekranu „Transakcje”, który miesza te pojęcia.

## Revenue & Analytics

- occupancy
- ADR/RevPAR/TRevPAR
- channel performance
- booking pace later
- stay contribution margin
- unit operating margin
- data confidence
- Why this number?

## Maintenance

- incidents
- assets
- work orders
- downtime
- maintenance cost

## Progressive disclosure

Operator widzi prosty interfejs. Szczegółowa semantyka finansowa i audyt są dostępne głębiej dla ról wymagających tych danych.

## Mobile priority

Mobile-first dla:
- Today
- arrivals/departures
- turnover
- tasks
- incident reporting
- service schedule

Desktop-first może pozostać dla:
- allocation/reconciliation
- analytics
- configuration
- audit

## UX invariant

UI nie może sugerować, że dwie różne domenowo wartości są tym samym. Przykład: "wpływ na konto" i "przychód" muszą mieć odrębne etykiety.