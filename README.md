# OSG — Operating System of Glamping

Centralne źródło prawdy dla projektu OSG: operacyjnego i finansowego systemu zarządzania glampingiem.

## Status

Projekt znajduje się na etapie modelowania domeny i dokumentacji fundamentów. Kod aplikacji nie jest jeszcze rozwijany.

## Cel produktu

OSG ma połączyć w jednym modelu:

- nieruchomości, jednostki, zasoby i aktywa,
- rezerwacje, pobyty, usługi i doświadczenia,
- operacje, turnover, zadania, incydenty i serwis,
- należności, płatności, przepływy pieniężne i prawdę ekonomiczną,
- audyt, zdarzenia domenowe, integracje i metryki.

## Zasady rdzenia

1. Plan, zobowiązanie i wykonanie są osobnymi faktami.
2. Charge, Payment i CashMovement nie są tym samym.
3. Dane pochodne nie są źródłem prawdy.
4. Zaksięgowane fakty finansowe korygujemy przez odwrócenie i nowy zapis, nie przez ciche nadpisanie.
5. Organization stanowi granicę izolacji danych.
6. Historia operacyjna i ekonomiczna musi pozostać audytowalna.

## Dokumentacja

- [Checkpointy](docs/checkpoints/)
- [Decyzje architektoniczne](docs/decisions/)
- [Model danych](docs/data-model/)
- [Reguły biznesowe](docs/business-rules/)
- [Metryki](docs/metrics/)

Pierwszy checkpoint: [OSG Core Data Model v1.3](docs/checkpoints/OSG_02_Core_Data_Model_Checkpoint_v1.3.md).

## Kolejność prac

- M1 — Core Data Model: checkpoint v1.3
- M2 — Relationship Map
- M3 — Business Rules Catalog
- M4 — Domain Events
- M5 — Financial Truth

## Kierunek techniczny — decyzje wstępne

Docelowo rozważany jest monorepo z PWA, warstwą API i PostgreSQL. Szczegóły pozostają decyzjami architektonicznymi i nie oznaczają rozpoczęcia implementacji.
