# OSG — Commercial Snapshot Contract v0.1

Status: pre-freeze contract
Data: 2026-09-14

## 1. Cel

Zachować dokładne warunki handlowe obowiązujące w momencie sprzedaży, niezależnie od późniejszych zmian cennika, polityk anulacji, prowizji czy konfiguracji produktu.

## 2. Zasada

Current configuration opisuje ofertę dzisiaj.
CommercialSnapshot opisuje to, co zostało uzgodnione wtedy.

Historyczna Reservation nie może zależeć wyłącznie od aktualnego RatePlan/Service/Policy.

## 3. Snapshot scope

Dla Reservation/ReservationItem zapisujemy co najmniej:
- source/channel
- currency
- arrival/departure
- UnitType booked
- assigned Unit jeśli istnieje
- guest-count pricing assumptions
- accommodation rate breakdown
- discounts
- fees
- tax assumptions/references
- cancellation policy version/content reference
- deposit/prepayment terms
- package/rate-plan version
- commission expectation if known
- source timestamp/version

## 4. Price breakdown

Preferowany granularny snapshot per stay date/charge component zamiast jednego `total_price`, jeśli źródło dostarcza szczegóły.

Jednocześnie external quoted total może być zachowany do reconciliation.

## 5. CancellationPolicySnapshot

Snapshot musi pozwolić odtworzyć:
- deadline windows
- refundable/non-refundable amounts/procenty
- no-show treatment
- special exceptions jeśli występowały

Nie wystarczy wskazać `policy_id`, jeśli treść polityki może się zmienić.

## 6. Service purchase snapshot

ServiceBooking zachowuje:
- service version/name at sale
- quantity/duration
- price
- resource requirement policy where material
- cancellation terms

Zmiana aktualnego Service nie modyfikuje istniejącego ServiceBooking.

## 7. Package

Package sale dekomponuje się na składniki, ale przechowuje też package snapshot, aby można było wyjaśnić ofertę przedstawioną gościowi.

## 8. Channel commission

CommissionRule jest oczekiwaną konfiguracją.
Reservation może posiadać commission snapshot/estimate.
Rzeczywisty koszt prowizji pozostaje osobnym EconomicEvent na podstawie rozliczenia.

## 9. Modification

Jeżeli potwierdzona Reservation zmienia warunki handlowe:
- nie nadpisujemy niejawnie starego snapshotu,
- tworzymy nową wersję/adjustment snapshot z reason/source,
- zachowujemy lineage poprzednich warunków.

## 10. Invariants

COM-SNAP-001 — current rate change nie zmienia historycznej Reservation.
COM-SNAP-002 — current cancellation policy change nie zmienia praw starej Reservation.
COM-SNAP-003 — accepted modification zachowuje previous commercial version.
COM-SNAP-004 — actual OTA commission może różnić się od snapshot estimate i jest rozliczana osobno.
COM-SNAP-005 — quoted total musi być rekoncyliowalny z granular charges/snapshot albo różnica musi być jawna.

## 11. Explainability

System powinien odpowiedzieć:
`Dlaczego ten gość zapłacił 750 zł, skoro dzisiejsza cena tej nocy to 900 zł?`

Odpowiedź wynika z CommercialSnapshot, nie z aktualnego Rate.