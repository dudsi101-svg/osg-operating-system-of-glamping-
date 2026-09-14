# OSG — Communication & Notification Contract v0.1

Status: foundation contract
Data: 2026-09-14

## 1. Cel

Rozdzielić komunikację z gościem od wewnętrznych powiadomień operacyjnych i nie zbudować przypadkiem drugiego Messengera wewnątrz OSG.

## 2. Concepts

Conversation — kontekst komunikacji Guest/Reservation/Stay.
Message — faktyczna wiadomość inbound/outbound.
MessageTemplate — wersjonowany wzorzec komunikatu.
Notification — wewnętrzne powiadomienie OSG do User/Role.
CommunicationConsent — zgoda/preference wymagająca historii.

## 3. Message channels

EMAIL
SMS
WHATSAPP / compatible provider
PORTAL
INTERNAL_NOTE (nie wysyłane do gościa)
OTHER

Direction:
INBOUND / OUTBOUND.

## 4. Message history

Po wysłaniu treść wiadomości jest snapshotem. Zmiana MessageTemplate nie może zmienić historycznej wiadomości.

## 5. Automation examples

Reservation.Confirmed → confirmation + portal invite.
Arrival approaching + ETA missing → reminder.
Service.Booked → service confirmation.
Turnover at risk → internal Notification, nie guest Message.
Stay.CheckedOut → feedback request.

## 6. Notification model

Notification zawiera:
- target user/role/scope
- severity
- category
- subject entity
- action/deep link
- created_at
- acknowledged/read status
- expiry optional

## 7. Severity

INFO
ACTION_REQUIRED
WARNING
CRITICAL

Powiadomienie CRITICAL powinno być rzadkie i powiązane z realnym bezpieczeństwem/guest-impact/system failure.

## 8. Deduplication

Automatyczne wiadomości/powiadomienia muszą mieć deduplication key. Retry wysyłki nie może generować wielu identycznych komunikatów.

## 9. Preferences

User notification preference może określać kanał dla kategorii, ale nie może wyłączyć obowiązkowych krytycznych alertów bezpieczeństwa, jeśli polityka organizacji tego wymaga.

## 10. Guest consent

Operational communication potrzebna do realizacji pobytu jest oddzielona od marketing communication. Marketing templates nie korzystają z braku sprzeciwu jako domyślnej zgody, jeśli wymagana jest jawna podstawa.

## 11. Delivery status

QUEUED
SENT
DELIVERED (jeśli provider potwierdza)
FAILED
BOUNCED
READ (tylko kanały wspierające)

Delivery status nie jest tym samym co business acknowledgment.

## 12. Internal notes

InternalNote/INTERNAL Message nie może być automatycznie udostępnione Guest Portal. Sensitive notes wymagają ograniczonego permission scope.

## 13. AI

AI może przygotować draft odpowiedzi. Automatyczne wysyłanie jest osobną action class/policy. Treść inbound jest traktowana jako dane, nie instrukcja systemowa dla AI.

## 14. KPI

- delivery failure rate
- response time
- self-service resolution
- reminder completion conversion
- duplicate-send incidents

## 15. Release 1

Priorytet: portal/email + wewnętrzne notifications. Nie budujemy pełnego omnichannel inbox przed potwierdzeniem realnych potrzeb/integracji.