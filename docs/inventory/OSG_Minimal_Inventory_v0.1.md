# OSG — Minimal Inventory v0.1

Status: Release 1 supporting module
Data: 2026-09-14

## 1. Cel

Zapewnić operatorowi kontrolę nad krytycznymi materiałami eksploatacyjnymi bez budowania pełnego systemu magazynowego ERP.

## 2. Encje

InventoryItem
InventoryLocation
StockMovement
ReorderRule
Optional ConsumptionLink

## 3. InventoryItem

Przykłady:
- ręczniki
- drewno
- chemia
- środki czystości
- kawa
- kosmetyki

Pola:
- unit of measure
- active
- track_mode COUNTED / ESTIMATED / NON_TRACKED
- category

## 4. StockMovement

RECEIPT
CONSUMPTION
TRANSFER
ADJUSTMENT
WASTE
RETURN

Aktualny stan jest sumą ruchów, nie ręcznie utrzymywaną niezależną prawdą.

## 5. Reorder

ReorderRule może używać:
- min_quantity
- target_quantity
- lead time
- location

Warning w Operations Center pojawia się poniżej progu.

## 6. Consumption

Nie wymagamy ewidencji każdej sztuki. Consumption może być:
- dokładne,
- batch/turnover template,
- szacunkowe.

Confidence jest jawne, jeśli dane trafiają do kosztów analitycznych.

## 7. Financial connection

Zakup InventoryItem → FinancialDocument/EconomicEvent.
StockMovement sam nie tworzy automatycznie cash cost.
Zużycie może wspierać alokację variable cost, jeśli polityka jest skonfigurowana.

## 8. Release 1 boundary

IN:
- krytyczne materiały,
- receipts/consumption/adjustment,
- reorder alerts,
- optional consumption per Turnover/Stay.

OUT:
- pełne zamówienia zakupowe,
- supplier procurement workflow,
- valuation methods FIFO/LIFO,
- księgowa gospodarka magazynowa.

## 9. Invariants

INV-001 — StockMovement jest append-oriented; korekta przez adjustment/reversal.
INV-002 — transfer tworzy spójne -/+ między locations.
INV-003 — manual adjustment wymaga reason.
INV-004 — stock level nie jest źródłem prawdy niezależnym od movements.
INV-005 — negative stock może być warning lub forbidden zależnie od item policy.