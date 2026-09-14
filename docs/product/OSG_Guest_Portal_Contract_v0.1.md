# OSG — Guest Portal Contract v0.1

Status: product contract
Data: 2026-09-14

## 1. Cel

Portal gościa ma ograniczyć telefony, Messenger i ręczne ustalenia, a jednocześnie zwiększać sprzedaż dodatków bez obciążania operatora.

## 2. Scope Release 1

Guest może zobaczyć:
- własną rezerwację/pobyt,
- jednostkę,
- daty,
- saldo/płatność w dozwolonym zakresie,
- podstawowe instrukcje,
- planowany check-in/out,
- zakupione usługi,
- dostępne dodatki,
- status własnych requestów.

Guest może:
- podać planowaną godzinę przyjazdu,
- uzupełnić wymagane informacje,
- dokupić Service,
- wybrać dostępny slot Resource,
- wysłać wiadomość/request,
- zaakceptować wymagane warunki,
- dokonać płatności przez provider flow.

## 3. Guest nie może

- widzieć danych innych gości,
- widzieć Financial Truth/Unit profitability,
- dowolnie edytować potwierdzonej rezerwacji,
- omijać polityk capacity/cancellation,
- samodzielnie oznaczać płatności jako opłacone.

## 4. Portal access

Portal session jest ograniczona do konkretnego Guest/Reservation/Stay scope.
Preferowane mechanizmy: magic link / authenticated guest session; exact implementation później.

## 5. Sections

### Your Stay
Property, Unit, dates, guests, arrival status.

### Before Arrival
forms, ETA, instructions, outstanding actions.

### Experiences
Service catalog → availability → booking → charge/payment.

### Payments
Folio summary i payment actions bez ujawniania wewnętrznej księgowości.

### Messages
Historia dozwolonej komunikacji.

### During Stay
instructions, WiFi/info, service requests, incident/report issue.

### Checkout
instructions, balance, optional late checkout, feedback.

## 6. Upsell rules

Portal pokazuje tylko Service:
- active,
- available dla property/stay dates,
- zgodne z capacity/resource,
- zgodne z policy (np. minimalny lead time).

## 7. Automation examples

Reservation.Confirmed → portal invitation.
ETA missing before arrival threshold → reminder.
Service.Booked → confirmation + preparation workflow.
Stay.CheckedOut → feedback request.

## 8. Privacy

Portal używa minimum danych. Nie pokazuje wewnętrznych notes/operator commentary.

## 9. KPI

- portal activation rate
- self-service completion rate
- calls/messages avoided proxy
- upsell conversion
- upsell revenue per stay
- pre-arrival form completion

## 10. Product principle

Portal nie ma być mini-PMS-em dla gościa. Ma skracać drogę od potrzeby gościa do poprawnie wykonanej akcji.