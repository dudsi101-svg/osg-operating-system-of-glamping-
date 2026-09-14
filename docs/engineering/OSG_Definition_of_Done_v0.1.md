# OSG — Engineering Definition of Done v0.1

Status: obowiązujący kandydat
Data: 2026-09-14

## 1. Każda zmiana

- ma jasno określony owner/write scope,
- ma powiązanie z issue/task,
- nie łamie canonical domain contracts,
- posiada test adekwatny do ryzyka,
- ma stabilne error semantics,
- przechodzi tenant-scope review,
- nie wprowadza sekretów do repo,
- aktualizuje docs, jeśli zmienia semantykę.

## 2. Domain change

Done dopiero gdy:
- invariants są opisane/testowane,
- state transition jest legalny,
- cross-domain impact jest przeanalizowany,
- event/API contract jest zaktualizowany,
- affected-domain reviewer może odtworzyć decyzję.

## 3. Database change

- migration forward path istnieje,
- rollback/repair strategy jest określona,
- constraint/index impact oceniony,
- tenant isolation zachowana,
- migration działa na czystej DB i aktualnej DEV DB,
- seed/reference data nadal działa.

## 4. Financial change

- conservation tests,
- immutability tests,
- closed-period behavior,
- approval behavior,
- audit/event evidence,
- explainability/lineage.

Brak któregoś z powyższych = nie Done.

## 5. Integration change

- idempotency test,
- duplicate delivery test,
- invalid payload test,
- retry semantics,
- conflict handling,
- observability metrics/logs,
- provenance preserved.

## 6. UI change

- nie duplikuje domain rules,
- loading/error/empty states,
- permission-denied state,
- mobile behavior dla odpowiednich ról,
- accessibility baseline,
- stable API contract.

## 7. Automation

- trigger i conditions wersjonowane,
- idempotent action,
- retry policy,
- failed state visible,
- audit/automation history,
- manual recovery path.

## 8. AI feature

- action class A0–A4 określona,
- permission scope,
- quality/confidence propagation,
- no unrestricted DB write,
- audit/rationale summary,
- human approval dla high-risk.

## 9. P0 gate

Zmiana dotykająca P0 invariant nie może zostać uznana za Done tylko na podstawie unit testu. Wymaga integration/DB proof odpowiedniego do invariant.

## 10. Release Done

Release jest Done dopiero gdy:
- CI green,
- migrations verified,
- backup/restore check dla release class jeśli wymagane,
- critical workflows smoke-tested,
- no open P0,
- known P1 documented,
- release notes/checkpoint updated.