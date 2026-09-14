# ADR-001 — Relational Core / PostgreSQL

Status: Accepted
Date: 2026-09-14

## Context
OSG ma odwzorowywać silnie powiązany model biznesowy: obiekty, jednostki, rezerwacje, pobyty, usługi, operacje, dokumenty, przepływy pieniężne, zdarzenia ekonomiczne, alokacje i audyt.

## Decision
Rdzeń danych OSG będzie relacyjny i projektowany pod PostgreSQL.

JSON może być używany pomocniczo dla rozszerzeń, surowych danych integracyjnych i metadanych, ale nie jako substytut głównych relacji biznesowych.

Krytyczne relacje będą egzekwowane przez jawne foreign keys i constraints.

## Consequences
- wysoka integralność danych,
- czytelne relacje i możliwość audytu,
- dobre podstawy pod analitykę,
- migracje schematu muszą być wersjonowane,
- część modelu wymaga większej dyscypliny niż schematy dokumentowe.

## Rejected alternatives
- document database jako główny store,
- jeden elastyczny JSON na większość obiektów,
- EAV jako podstawowy model domenowy.
