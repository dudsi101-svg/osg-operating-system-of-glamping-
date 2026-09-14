# ADR-001: PostgreSQL jako główna baza danych OSG

- **Status:** Accepted
- **Data:** 2026-09-14
- **Obszar:** Data architecture

## Kontekst

OSG łączy dane operacyjne, handlowe i finansowe o wielu relacjach, wymaganiach integralności oraz potrzebie audytu. Model obejmuje m.in. organizacje, obiekty, jednostki, pobyty, zasoby, naliczenia, płatności, przepływy pieniężne, zdarzenia ekonomiczne i alokacje.

## Decyzja

PostgreSQL będzie główną relacyjną bazą danych OSG.

Logika biznesowa pozostanie własnością warstwy API. Baza będzie egzekwować integralność, relacje, transakcje, ograniczenia i izolację tenantów. Dane pochodne mogą być materializowane dla wydajności, ale pozostają przeliczalne z faktów źródłowych.

Na start dopuszcza się zarządzany PostgreSQL, np. Supabase Postgres, bez uzależniania domeny OSG od niestandardowych funkcji dostawcy.

## Uzasadnienie

- silne transakcje i spójność danych finansowych,
- constraints, klucze obce i typy potrzebne do ochrony modelu,
- dojrzałe indeksowanie i zapytania analityczne,
- wsparcie JSONB dla kontrolowanych rozszerzeń,
- możliwość wdrożenia Row Level Security,
- szeroki ekosystem, migracje i przenośność między dostawcami.

## Konsekwencje

### Pozytywne

- jednoznaczne relacje i audytowalne korekty,
- bezpieczna rekonsyliacja i alokacje,
- możliwość rozwijania raportów bez tworzenia drugiego źródła prawdy,
- gotowość na wiele obiektów i organizacji.

### Koszty i ryzyka

- potrzebne będą rygorystyczne migracje i wersjonowanie schematu,
- model relacyjny wymaga wcześniejszego doprecyzowania kardynalności,
- RLS nie zastępuje autoryzacji w API,
- projekcje analityczne wymagają kontroli świeżości.

## Alternatywy

- Dokumentowa baza NoSQL — odrzucona jako główne źródło prawdy z powodu złożonych relacji i wymagań integralności.
- Arkusze — dopuszczalne wyłącznie jako źródło importu lub widok roboczy, nie jako system ewidencyjny.
- Pełny event store — odrzucony na start; zdarzenia domenowe uzupełniają relacyjny model stanu.

## Guardrails

- Dane każdej Organization muszą pozostać izolowane.
- Fakty finansowe po zaksięgowaniu nie są cicho nadpisywane.
- Frontend nie omija API przy wykonywaniu logiki biznesowej.
- Rozszerzenia JSONB nie mogą zastępować podstawowych pól i relacji domenowych.
