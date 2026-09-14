# Reguły biznesowe

Ten katalog będzie zawierał katalog reguł OSG niezależny od interfejsu użytkownika i szczegółów implementacji.

## Szablon reguły

Każda reguła powinna określać:

- identyfikator i nazwę,
- domenę i właściciela,
- warunek wejściowy,
- dozwolone działanie lub zakaz,
- skutek i ewentualne zdarzenie domenowe,
- sposób egzekwowania: baza, API, proces lub kontrola ręczna,
- poziom krytyczności,
- przykłady pozytywne i negatywne.

## Pierwsze obszary

- izolacja Organization,
- nakładanie pobytów i rezerwacji zasobów,
- przejścia stanów Reservation, Stay, Task i Incident,
- posting oraz reversal faktów finansowych,
- payment allocation i reconciliation,
- automatyczne tworzenie turnoveru i zadań,
- wpływ incydentu na dostępność jednostki.

Pełny katalog powstanie w etapie M3.
