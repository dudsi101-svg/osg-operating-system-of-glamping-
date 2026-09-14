# OSG — Data Quality Scoring v0.1

Status: kandydat implementacyjny
Data: 2026-09-14

## 1. Cel

Nie każda liczba w OSG ma ten sam poziom wiarygodności. System powinien mierzyć jakość danych i pokazywać niepewność, zamiast udawać fałszywą precyzję.

## 2. Dimensions

COMPLETENESS — czy wymagane dane istnieją?
CONSISTENCY — czy dane nie są sprzeczne?
PROVENANCE — czy znamy źródło?
RECONCILIATION — czy fakty zostały uzgodnione?
CONFIDENCE — verified/system-derived vs estimated/manual/unknown.
FRESHNESS — czy dane są aktualne?

## 3. QualityIssue severity

INFO
LOW
MEDIUM
HIGH
CRITICAL

## 4. Example issues

- Reservation bez Channel
- Payment CONFIRMED bez reconciliation po SLA
- CashMovement bez klasyfikacji ekonomicznej po SLA
- EconomicEvent POSTED z manual allocation niskiej confidence
- Asset incident bez Asset link
- Stay checked out bez Turnover
- external sync stale

## 5. Scoring principle

OSG nie zapisuje jednej arbitralnej liczby 0–100 jako źródła prawdy. Score jest projekcją wersjonowanej reguły nad otwartymi issue/faktami.

Przykład widoku:
Data Health = 92/100
- Completeness 98
- Reconciliation 84
- Provenance 95
- Freshness 100

## 6. Financial confidence

Raport finansowy pokazuje udział wartości:
VERIFIED
SYSTEM_DERIVED
ESTIMATED
MANUAL
UNKNOWN

Przykład:
Economic result = 31 420 PLN
Data confidence: 91%
6% wartości opiera się na estimated allocations
3% pozostaje manual/unreconciled

## 7. Blocking rules

Niektóre issues mogą blokować workflow:
- unbalanced EconomicEvent blocks POSTING
- cross-tenant conflict blocks write
- missing required approval blocks posting

Inne nie blokują, ale ostrzegają:
- missing marketing source
- non-critical stale metadata

## 8. SLA

Każdy issue type może mieć resolution SLA i escalation policy.

## 9. AI use

AI musi uwzględniać quality/confidence w odpowiedziach analitycznych. Nie powinno przedstawiać ESTIMATED wyniku jako verified fact.

## 10. Explainability

Każdy score/health badge musi dać się rozwinąć do konkretnych issue i source facts.