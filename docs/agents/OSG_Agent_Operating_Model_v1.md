# OSG — Agent Operating Model v1

Status: obowiązujący model pracy
Data: 2026-09-14

## 1. Cel

Zapewnić równoległą pracę wielu agentów AI bez konfliktów, duplikacji i utraty spójności architektury OSG.

## 2. Zasada nadrzędna

READ MANY / WRITE ONE.

Wiele agentów może równolegle czytać, analizować, testować i recenzować ten sam obszar. Tylko jeden agent może być właścicielem zapisu danego artefaktu lub domeny w tym samym czasie.

## 3. Hierarchia

### Chief Architect / Orchestrator
Odpowiada za architekturę całości, kolejność prac, konflikty międzydomenowe, checkpointy i decyzje L3/L4.

### Domain Leads
- Property Lead
- Stay Lead
- Operations Lead
- Finance Lead
- Experience Lead
- Revenue Lead
- Identity & Security Lead
- Integration Lead

Każdy Domain Lead ma własność nad swoim bounded context.

### Cross-domain roles
- Systems Integrator
- Consistency Auditor
- Security & Privacy Reviewer
- Data Quality Reviewer
- QA/Test Architect
- Documentation Librarian

Role przekrojowe recenzują i integrują, ale nie przejmują własności domeny bez jawnego handoffu.

## 4. Ownership

Każdy artefakt posiada:
- owner
- allowed reviewers
- affected domains
- dependency list
- write lock status

Krytyczne relacje biznesowe mają jednego właściciela semantycznego.

## 5. Task lifecycle

BACKLOG → READY → IN_PROGRESS → REVIEW → INTEGRATION → ACCEPTED → CHECKPOINTED

Dodatkowe stany:
BLOCKED, REJECTED, SUPERSEDED

## 6. Typy decyzji

L1 — lokalna domenowa: Domain Lead
L2 — międzydomenowa: owner + affected leads
L3 — architektoniczna: Chief Architect + ADR
L4 — produktowa/fundamentalna: Chief Architect + właściciel projektu

## 7. Branching

Branch opisuje pracę, nie agenta:
- agent/property/unit-availability
- agent/finance/allocation-model
- agent/stay/stay-segments

Agent nie scala własnej pracy bez niezależnego review dla zmian istotnych.

## 8. Cross-domain change

Zmiana dotykająca wielu domen musi zawierać:
- primary owner
- affected domains
- contract impact
- migration impact
- reviewers
- ADR, jeśli zmienia architekturę

## 9. Contracts

Domeny komunikują się przez jawne kontrakty:
- encje publiczne
- zdarzenia domenowe
- API contracts
- versioned schemas

Agent jednej domeny nie powinien edytować wewnętrznej logiki drugiej domeny, jeśli wystarczy użyć kontraktu.

## 10. Dependency graph

Każde zadanie deklaruje:
- depends_on
- blocks
- inputs
- outputs
- owner
- reviewers

Agent nie zgaduje brakującej semantyki zależności. Zadanie przechodzi w BLOCKED albo używa jawnego kontraktu roboczego oznaczonego jako provisional.

## 11. Checkpoint gate

Checkpoint powstaje dopiero po:
- domain review
- cross-domain review
- braku otwartych konfliktów P0/P1
- zapisaniu ADR dla decyzji L3
- zgodności z Business Rules
- aktualizacji dokumentacji

## 12. Priorytet konfliktów

1. bezpieczeństwo i integralność danych
2. spójność modelu domenowego
3. odwracalność decyzji
4. prostota operacyjna
5. wydajność
6. wygoda implementacji

## 13. Zakaz równoległego pisania

Dwa aktywne zadania nie mogą mieć nakładającego się write scope bez jawnego podziału plików/kontraktów.

## 14. Definition of Done dla pracy agenta

Praca nie jest zakończona, dopóki:
- output jest zapisany
- zależności są aktualne
- testowalne invariants są opisane
- wpływ cross-domain jest wskazany
- reviewer może odtworzyć decyzję bez rozmowy z autorem
