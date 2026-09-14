# OSG — M9 Data Lifecycle & Privacy v0.1

Status: roboczy
Data: 2026-09-14

## 1. Cel

Zapewnić minimalizację danych, kontrolę retencji, audyt i możliwość obsługi praw osób bez niszczenia wymaganej historii biznesowej.

## 2. Klasy danych

PUBLIC
INTERNAL
CONFIDENTIAL
PERSONAL
SENSITIVE_OPERATIONAL
FINANCIAL
SECURITY

## 3. Zasada minimalizacji

OSG nie zbiera pola "na wszelki wypadek".
Każde pole osobowe musi mieć określony cel biznesowy/operacyjny/prawny.

## 4. Guest identity

GuestProfile przechowuje minimalny trwały profil.
StayGuest może używać lżejszej reprezentacji, jeśli pełny CRM profile nie jest potrzebny.

## 5. Marketing

Marketing consent jest niezależny od danych wymaganych do realizacji pobytu.
Consent ma source, timestamp i wersję treści.

## 6. Retention model

Każda kategoria ma:
- retention_class
- retention_until
- legal_hold
- anonymization_policy

Dokładne okresy zostaną ustalone po analizie prawnej i księgowej; nie kodujemy arbitralnych terminów przed tym etapem.

## 7. Deletion vs anonymization

Dane wymagane dla finansów/audytu mogą pozostać, ale relacja z osobą może zostać ograniczona/anonymized tam, gdzie jest to dopuszczalne.

## 8. Attachments

Pliki otrzymują classification i retention class.
Zdjęcia incydentów i dokumenty gości nie dziedziczą automatycznie nieskończonej retencji.

## 9. Export / subject access

System powinien umożliwiać zebranie danych osoby z:
GuestProfile
Reservations
Stays
Messages
Consents
Payments/folios w dozwolonym zakresie
Audit references, jeśli prawnie właściwe

## 10. Sensitive notes

Free-text notes są ryzykowne.
Preferowane structured flags i ograniczona długość.
Sensitive notes wymagają ograniczonych permissions.

## 11. AI

Dane przekazywane AI podlegają temu samemu permission/privacy policy.
Prompt/log nie może bez potrzeby duplikować pełnych danych osobowych.
