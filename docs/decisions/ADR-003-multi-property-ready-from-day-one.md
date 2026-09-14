# ADR-003 — Multi-property ready from day one

Status: Accepted
Date: 2026-09-14

## Context
Pierwszym wdrożeniem OSG jest Glamping Nad Stawem, ale rdzeń produktu nie może być zakodowany pod jeden obiekt ani konkretne osoby.

## Decision
Model danych będzie od początku przygotowany na:
- wiele Properties w jednej Organization,
- izolację danych na poziomie Organization,
- role i uprawnienia zależne od scope,
- konfigurację obiektu zamiast hardcodowania nazw jednostek i osób.

Pierwsza implementacja pozostaje single-property operacyjnie, ale model nie będzie wymagał późniejszej przebudowy w celu dodania kolejnego obiektu.

## Consequences
- każdy rekord domenowy posiada poprawny kontekst Organization/Property,
- relacje cross-organization są domyślnie zabronione,
- wdrożenie pierwszego obiektu pozostaje proste,
- niewielki wzrost złożoności modelu teraz ogranicza koszt migracji później.

## Rejected alternatives
- zakodowanie Forest/Boho/Michał/Kuba w rdzeniu,
- dopiero późniejsza migracja z single-property do multi-property.
