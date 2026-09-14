# OSG — Source of Truth Matrix v0.1

Status: roboczy
Data: 2026-09-14

| Obszar | Owner system v1 | OSG rola | Konflikt |
|---|---|---|---|
| Property master data | OSG | authoritative | external cannot overwrite without explicit policy |
| Unit / Resource / Asset | OSG | authoritative | manual review |
| Reservation commercial facts | PMS/source system until takeover | mirror + normalize | source wins for externally-owned fields |
| Stay actual execution | OSG | authoritative | operator/audit decides |
| Guest CRM canonical profile | OSG | authoritative after merge | merge workflow |
| Charges/Folio | OSG | authoritative | controlled correction |
| Payment provider status | provider | verified source | reconcile into OSG |
| Bank movement | bank | verified source | immutable imported fact |
| Financial document content | source document/accounting import | source evidence | verification workflow |
| EconomicEvent | OSG | authoritative | posted correction only |
| Allocation | OSG | authoritative | approval workflow |
| Settlement | OSG | authoritative | derived + controlled adjustments |
| Tasks/Turnover/Incident | OSG | authoritative | operator/audit |
| Rate published externally | PMS/channel manager | external truth | OSG may mirror/suggest |
| Suggested rate | OSG | advisory | never confused with published rate |
| KPI | OSG Analytics | derived | recomputable from facts |
| AI answer | OSG Intelligence | non-authoritative interpretation | must cite facts/metric definitions |

## Field ownership modes

- EXTERNAL_OWNED
- OSG_OWNED
- MERGE
- MANUAL_OVERRIDE_LOCK
- DERIVED

## Reguła

Nie istnieje „ogólna prawda systemu”. Prawda jest przypisana do konkretnego typu faktu i jego właściciela.