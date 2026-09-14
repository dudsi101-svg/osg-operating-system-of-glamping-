# OSG — M8 Integration Contracts v0.1

Status: roboczy
Data: 2026-09-14

## 1. Cel

Oddzielić OSG Core od konkretnych dostawców PMS/OTA/banku/płatności/księgowości.

## 2. Adapter pattern

External System → Adapter → Canonical Contract → OSG Domain

Każdy adapter odpowiada za mapowanie z formatu dostawcy do kanonicznego kontraktu OSG.

## 3. Typy integracji

RESERVATION_SOURCE
CHANNEL_MANAGER
PAYMENT_PROVIDER
BANK
ACCOUNTING
MESSAGING
IDENTITY
FILE/OCR
ANALYTICS_EXPORT

## 4. Integration entity

- id
- organization_id
- provider
- integration_type
- status
- property_scope
- credentials_reference
- sync_mode
- last_success_at
- last_failure_at

Sekrety nie są przechowywane w zwykłych rekordach domenowych.

## 5. ExternalRecord

Zachowuje surowy rekord wejściowy lub bezpieczny snapshot:
- integration_id
- external_type
- external_id
- received_at
- payload_hash
- payload/location
- processing_status

## 6. ExternalReference

Mapuje zewnętrzne ID do OSG:
unique(integration_id, external_type, external_id)

## 7. Canonical reservation contract

Minimalnie:
- external reservation id
- source/channel
- property
- booked_at
- arrival/departure
- guest identity/reference
- guest counts
- booked unit type
- assigned unit if provided
- pricing snapshot
- commission snapshot if provided
- commercial status
- payment signals
- source updated_at

## 8. Field ownership

Każde pole synchronizowane posiada policy:
EXTERNAL_OWNED
OSG_OWNED
MERGE
MANUAL_OVERRIDE_LOCK

## 9. Conflict handling

Conflict.Detected zamiast cichego wyboru wartości, jeżeli:
- dwie wartości są materialnie różne
- nie istnieje jednoznaczna ownership policy
- zmiana może wpłynąć na pobyt/finanse

## 10. Idempotency

Inbound event key:
integration_id + external_event_id
albo stabilny payload fingerprint, jeśli dostawca nie daje event id.

## 11. Sync modes

WEBHOOK_PRIMARY
POLLING
MANUAL_IMPORT
BATCH_FILE

Polling nie jest używany, jeśli webhook jest wiarygodny i kompletny, ale reconciliation polling może nadal istnieć.

## 12. Failure strategy

Transient technical → retry with backoff
Business conflict → blocked/conflict queue
Invalid payload → rejected + DataQualityIssue
Credential failure → integration degraded/disabled alert

## 13. Bank contract

Bank import tworzy CashMovement candidate/fact.
Bank nie klasyfikuje automatycznie ekonomicznego znaczenia.

## 14. Accounting contract

Accounting export/import nie staje się właścicielem OSG Economic Truth.
Może dostarczać dokumenty, status księgowania, konta i dane podatkowe.

## 15. Reservation source priority

Do czasu discovery konkretnego PMS:
- external reservation commercial facts: source system
- operational Stay facts: OSG
- economic allocation: OSG
- property master data: OSG

## 16. Observability

Każda integracja posiada:
- sync health
- lag
- records received
- records failed
- conflicts
- last successful checkpoint
