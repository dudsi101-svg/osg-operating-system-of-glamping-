# OSG — Checkpoint 04: PRE-FREEZE v0.96

Data: 2026-09-14
Status: CHECKPOINT READY

## 1. Executive state

OSG przeszedł z etapu czysto koncepcyjnego do **wykonywalnego kandydata modelu**.

Mamy obecnie:
- dojrzały podział domen,
- kanoniczny katalog encji,
- relacje i business invariants,
- Financial Truth Engine rozdzielający dokument/cash/economics/allocation,
- kontrakty operacyjne i produktowe,
- model zdarzeń/automatyzacji,
- tenant/security/approval model,
- Semantic Layer i AI governance,
- PostgreSQL schema candidate v0.95 + poprawki v0.96,
- 12 referencyjnych scenariuszy biznesowych/testowych,
- P0 proof plan i GitHub Issues wykonawcze.

Nie ma obecnie znanej nierozwiązanej **semantycznej** sprzeczności P0.

Schema v1.0 FINAL **nie jest jeszcze ogłoszony**, ponieważ wymagane są rzeczywiste testy PostgreSQL/concurrency/RLS/idempotency.

## 2. Najważniejsze decyzje rdzenia

1. PostgreSQL, relational-first.
2. UUIDv7 generowany w application/shared ID layer.
3. Organization jako granica tenant isolation.
4. Multi-property ready od początku, pierwszy deployment single-property.
5. Reservation != Stay.
6. UnitType != Unit.
7. Resource != Service != Asset.
8. Stay relocation = StaySegments, bez nadpisywania historii.
9. Charge != Payment != CashMovement.
10. FinancialDocument != CashMovement != EconomicEvent != Allocation.
11. CAPEX/OPEX klasyfikowane ekonomicznie na poziomie event/allocation, nie tylko faktury.
12. paid_by != economic_bearer; Settlement jest wynikiem różnicy.
13. Posted Financial Truth jest immutable poza reversal/correction.
14. Dashboard/KPI są projekcjami, nie źródłem prawdy.
15. Cross-domain coordination preferuje Domain Events.
16. Transactional outbox + idempotent consumers.
17. AI korzysta z Semantic/API layer i nie ma privileged bypass.
18. READ MANY / WRITE ONE dla agentów.

## 3. Schema candidate

Current load chain:
1. `osg_schema_v0.95_core.sql`
2. `osg_schema_v0.95_extensions.sql`
3. `osg_schema_v0.95_supporting.sql`
4. `osg_schema_v0.96_patch.sql`
5. `osg_schema_v0.96_financial_guard_patch.sql`
6. proof guards

Core posiada m.in.:
- composite tenant-aware FKs,
- exclusion constraint dla StaySegment overlap,
- exclusion constraint dla EXCLUSIVE Resource,
- Financial posting/immutability guards,
- DomainEvent / Outbox / Audit,
- approvals/data-quality scaffolding.

Capacity >1 Resource pozostaje kontrolowane transakcyjnie przez Resource lock + domain guard.

## 4. Reference implementation data

Master fixture odwzorowuje:
Forest, Boho, Loft, Ostoja, Aura,
Sauna, Jacuzzi, Balia, Łódka, Sala,
channels, services, cost centers, money accounts.

Nie zawiera realnego guest PII ani rzeczywistych danych bankowych.

## 5. 12 reference scenarios

01 Direct Forest stay + Sauna.
02 OTA gross 2000 / commission 300 / payout 1700.
03 Kuba-funded 430 OPEX → Settlement → repayment.
04 8000 accounting/cash cost → 1600 business OPEX + 6400 NON_BUSINESS.
05 One invoice → 5000 CAPEX + 1500 OPEX.
06 Incident Forest → block → conflict → relocation Forest→Ostoja.
07 Prepayment → cancellation → linked Charge reversal + full Refund.
08 Duplicate PMS event ×5 → one Reservation effect.
09 Shared electricity 5000 → versioned AREA_M2 allocations.
10 Late August invoice after HARD_CLOSE → September adjustment referencing August.
11 Resource capacity exact fill vs overflow negative test.
12 Turnover at risk → scheduler event → idempotent operator notification.

## 6. Gaps discovered and resolved through scenarios

- prior-period adjustment needed explicit related period → v0.96 patch,
- allocation INSERT after POSTED needed blocking → v0.96 financial guard,
- full refund required commercial Charge reversal, not only Refund,
- capacity >1 required transactional lock, not simple SQL exclusion,
- old seed/schema naming drift discovered → new v0.95 master seed,
- UUIDv4 proof vs UUIDv7 design mismatch → ADR-007.

## 7. Open P0 technical gates

Still require executable proof:
- StaySegment temporal overlap,
- Resource concurrency,
- atomic Financial posting,
- posted financial immutability under real DB execution,
- Settlement/payment conservation under concurrency,
- tenant isolation with realistic application DB role,
- integration/automation idempotency,
- clean load of complete schema + all scenarios.

GitHub Issues #1–#5 and #8 track them.

## 8. External discovery remaining

- actual PMS/channel flow — Issue #6,
- actual bank/cash import path — Issue #7.

These do not currently block Core freeze unless discovery reveals a missing business concept.

## 9. Product contracts already defined

- Command Center,
- Operations Center,
- Guest Portal,
- Owner/Finance Cockpit,
- role-based information architecture,
- Maintenance & Asset lifecycle,
- Revenue foundation,
- minimal Inventory,
- Communication/Notifications,
- Semantic Layer,
- Intelligence governance.

## 10. Current verdict

**GO:** DEV proof, clean PostgreSQL load, API scaffolding, integration tests, semantic query proofs.

**NO-GO:** production/live financial data, final migrations, live bank/PMS writes, Schema v1.0 FINAL, autonomous high-risk AI writes.

## 11. Next phase

1. Create semantic/reference SQL views for core management questions.
2. Prepare clean-load CI job specification.
3. Execute P0 proofs in real PostgreSQL when environment becomes available.
4. Fold successful v0.96 patches into canonical v1.0 schema.
5. Issue Schema v1.0 FINAL only after proof gates PASS.
