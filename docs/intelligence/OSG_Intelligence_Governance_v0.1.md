# OSG — Intelligence Governance v0.1

Status: foundation contract
Data: 2026-09-14

## 1. Cel

Wprowadzić AI do OSG jako warstwę interpretacji i rekomendacji nad uporządkowanymi danymi, bez oddawania modelowi swobodnej kontroli nad krytycznymi faktami biznesowymi.

## 2. Hierarchia

DATA TRUTH
→ DETERMINISTIC RULES
→ AUTOMATION
→ ANALYTICS
→ AI INTERPRETATION
→ AI RECOMMENDATION
→ CONTROLLED AI ACTION

Nie odwracamy tej kolejności.

## 3. AI access

AI korzysta z:
- Semantic Layer,
- dozwolonych domain queries,
- controlled command API,
- dokumentacji i lineage.

Brak unrestricted SQL/DB write.

## 4. AI action classes

A0 READ/EXPLAIN — bez zapisu.
A1 LOW-RISK PROPOSAL — tworzy sugestię/draft.
A2 LOW-RISK ACTION — może wykonać po permission/policy.
A3 HIGH-RISK ACTION — wymaga approval lub człowieka.
A4 FORBIDDEN AUTONOMOUS — brak autonomicznego wykonania w danej wersji systemu.

## 5. Examples

A0:
- wyjaśnij spadek marży,
- porównaj Unit economics,
- znajdź anomalie.

A1:
- zaproponuj cenę,
- zaproponuj klasyfikację faktury,
- zaproponuj odpowiedź gościowi.

A2:
- utwórz low-risk Task z zaakceptowanego workflow,
- wygeneruj raport.

A3:
- zmień economic allocation,
- opublikuj istotną zmianę ceny,
- wykonaj refund,
- zamknij okres.

A4 Release 1:
- autonomiczny transfer pieniędzy,
- autonomiczne usuwanie danych,
- samodzielne high-risk approvals,
- cicha zmiana posted financial facts.

## 6. Explainability

AI recommendation przechowuje:
- input context references,
- metric versions,
- confidence/data quality,
- rationale summary,
- proposed action,
- model/system version where applicable.

Nie przechowujemy pełnego ukrytego chain-of-thought; przechowujemy audytowalne uzasadnienie biznesowe.

## 7. Data quality

Jeżeli wynik opiera się na estimated/manual/unknown data, AI musi to ujawnić użytkownikowi i obniżyć confidence rekomendacji.

## 8. Guardrails

Każda AI write action przechodzi przez ten sam:
- authorization,
- validation,
- business rules,
- approval,
- audit
co akcja człowieka.

## 9. Prompt injection / external content

Dane z wiadomości gości, dokumentów i integracji są traktowane jako dane, nie instrukcje systemowe dla AI. Narzędzia wykonawcze są ograniczone allowlistą i scope.

## 10. Recommendation lifecycle

GENERATED → REVIEWED → ACCEPTED/REJECTED → EXECUTED (opcjonalnie)

Recommendation nie jest faktem biznesowym dopóki kontrolowana akcja nie zostanie wykonana.

## 11. Future intelligence

- anomaly detection
- demand forecast
- predictive maintenance
- pricing suggestions
- investment scenarios
- operational bottleneck detection

Każdy model predykcyjny wymaga oddzielnego readiness gate i walidacji.