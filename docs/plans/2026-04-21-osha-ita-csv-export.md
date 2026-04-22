# Phase 4 (revised): OSHA ITA CSV export — Full Plan (2026-04-21)

Replaces the old Phase 4 ("Fillable PDFs") in
`2026-04-20-module-d-csv-import-pdf-forms.md`. User located OSHA's
official Injury Tracking Application (ITA) CSV templates, which
obsolete the PDF-fill approach: OSHA accepts the same data directly as
two CSV uploads to the ITA portal.

Reference templates (committed under `osha_300/`):
- `ita_template_form_300-301_csv_data.csv` — 24 columns, one row per
  recordable incident. Merges the old Form 300 (log) and Form 301
  (incident report) into one detail CSV.
- `osha_ita_summary_data_csv_template-revised.csv` — 28 columns, one
  row per establishment+year. Replaces Form 300A.

---

## Principles

- **Ontology is the source of truth.** ITA is a reporting surface, not a
  new domain — but the new fields it needs (EIN, establishment size and
  type, 4th narrative, ITA outcome + case-type taxonomies) belong in the
  ontology first. No SQL column lands until the concept is in
  `ehs-ontology-v3.3.ttl` and HermiT validates clean.
- **Existing domain is mostly sufficient.** Module C's `establishments`,
  `employees`, `incidents`, `severity_levels`, and `case_classifications`
  already cover ~70% of the ITA columns. Phase 4 is an additive extension,
  not a replacement.
- **Translation from Odin taxonomy to ITA taxonomy is declarative.** Odin's
  existing `severity_code` and `case_classification` codes do not match
  ITA enum codes 1-to-1. The mapping lives in SKOS triples in the ontology
  and in `ita_*_mapping` lookup tables in SQL — never hardcoded in Go or
  exporter templates. A user who reclassifies a local severity should be
  able to adjust the mapping without a code change.
- **Pure Go for CSV on both sides.** `encoding/csv` for emit, same reader
  we already use for import. No new runtime dependencies.
- **ITA is first-class, not an export-only afterthought.** The same CSV
  shapes feed the importer framework (Phase 2+3) so users can round-trip:
  export → edit in Excel → re-import. Optional sub-phase 4d; the plumbing
  is already in place from earlier phases.
- **Core routing is untouched.** Repository shapes grow (new columns),
  form UIs grow (new fields), a new `/api/osha/ita/*` route group is
  added. No changes to existing module routes, the schema builder, the
  importer engine, or auth plumbing.

---

## Cross-cutting decisions

Locked 2026-04-21 unless noted.

1. **Ontology-first sequencing.** v3.2 → v3.3 TTL + HermiT validation +
   CHANGELOG entry lands **before** any SQL work. Matches the Phase 0/1
   cadence proven on Module D.
2. **Enum strategy.** ITA has three small, closed enums (establishment
   size, establishment type, treatment facility type) and two larger
   taxonomies (incident outcome, incident type). All five land as
   SKOS concept schemes in v3.3 and as seeded lookup tables in SQL.
   Odin's existing `severity_code` and `case_classification` codes get
   `skos:exactMatch` or `skos:broadMatch` links to ITA codes.
3. **"Company" vs "establishment".** ITA's Summary CSV distinguishes
   `company_name` (parent legal entity) from `establishment_name` (the
   specific facility). Odin currently has `establishments.name` but no
   company-level entity. Add `establishments.company_name` as a free-text
   column for MVP; a real `companies` table is a future refactor when
   multi-facility company roll-ups become a UI concern.
4. **Narrative fields.** ITA splits the incident narrative 4 ways:
   `nar_before_incident`, `nar_what_happened`, `nar_injury_illness`,
   `nar_object_substance`. Odin has the first three (`activity_description`,
   `incident_description`, `object_or_substance`) but lacks the fourth.
   Add `incidents.injury_illness_description`. Do NOT concat existing
   fields to fake the 4th — breaks round-trip and degrades source data.
5. **Migration-on-existing-DB gap** persists from Phase 1. For 4a we
   continue the dev-nuke-and-resplat pattern for local work, and bundle
   all outstanding `ALTER TABLE ADD COLUMN` upgrades (pollutant_type_code
   from Phase 1, plus 10 new columns from Phase 4) into one "pre-prod
   migration runner" ticket tracked separately.
6. **Export scope = two CSVs, nothing else.** No ITA JSON, no direct API
   submission to OSHA's portal, no PDF fallback. Users download the CSVs
   and upload them via OSHA's web UI. Direct submission is a future item.
7. **Audit trail.** Every export writes one `audit.Entry` with
   `module = "osha_ita"`, `entity_id = {establishment_id}-{year}-{kind}`,
   and a summary describing row count + year + establishment.
8. **ITA year-over-year.** Every export is scoped to
   `(establishment_id, year)`. An establishment that files for multiple
   years produces one CSV per year. Summary-level rows never live in the
   DB; they're computed on demand from the incidents table.

---

## Phase 4a.1 — Ontology v3.3 (source of truth)

**Plan lives in the ontology repo**, not here. See
`third_party/ehs-ontology/docs/plans/2026-04-21-ontology-v3.3.md`
(Phase 1) for the full class / property / SKOS-mapping spec, HermiT
and scenario-test requirements, and deliverables.

Odin-side work for this sub-phase is limited to:

- After v3.3 merges to `main` in `asgardehs/ehs-ontology`, bump the
  submodule pointer at `third_party/ehs-ontology/` in a separate
  odin commit.
- Don't edit files inside `third_party/ehs-ontology/` directly from
  odin's working tree — all TTL edits happen in the ontology repo.

---

## Phase 4a.2 — SQL schema

Extend `docs/database-design/sql/module_c_osha300.sql` with the
additive changes below. Guard every `ALTER TABLE` with the
`pragma_table_info` idempotency check already implemented for the
`CREATE TABLE IF NOT EXISTS` pattern; stub out as a SQL comment for now
and handle ALTER safety in the migration runner ticket.

### New columns

**`establishments`** (4 new):
- `ein TEXT`
- `company_name TEXT`
- `size_code TEXT REFERENCES ita_establishment_sizes(code)`
- `establishment_type_code TEXT REFERENCES ita_establishment_types(code)`

**`incidents`** (6 new):
- `days_away_from_work INTEGER`
- `days_restricted_or_transferred INTEGER`
- `date_of_death TEXT`  — YYYY-MM-DD, nullable
- `treatment_facility_type_code TEXT REFERENCES ita_treatment_facility_types(code)`
- `time_unknown INTEGER DEFAULT 0`
- `injury_illness_description TEXT`

### New lookup tables (SKOS → SQL)

- `ita_establishment_sizes(code, name, description)`
- `ita_establishment_types(code, name, description)`
- `ita_treatment_facility_types(code, name, description)`

### New mapping tables

- `ita_outcome_mapping(severity_code, ita_outcome_code)` — PK
  `severity_code`. Seeded from the v3.3 SKOS exactMatch triples.
- `ita_case_type_mapping(case_classification_code, ita_case_type_code)`
  — PK `case_classification_code`.

### New view (CSV emit source)

- `v_osha_ita_detail` — joins `incidents` + `employees` +
  `establishments` + the two mapping tables. Emits columns in ITA order
  with the ITA column names. Exporter reads this view directly — no
  business logic in Go.
- `v_osha_ita_summary` — aggregates `incidents` by establishment + year.
  Emits the 28 summary columns. `no_injuries_illnesses` computed as a
  flag from row count.

### Deliverable

- Updated `module_c_osha300.sql` with the above changes, tagged with
  `-- Added: v3.3 (ITA CSV export)` comments for searchability.
- Fresh install loads clean. Existing DB rollup left to the migration-
  runner ticket.

---

## Phase 4a.3 — Repository + form field plumbing

Purely plumbing — no new module, no new routes.

### Go repository

- `internal/repository/establishment.go` — add 4 fields to
  `Establishment` struct + column list.
- `internal/repository/incident.go` — add 6 fields to `Incident` struct
  + column list.

### Frontend

- `frontend/src/pages/modules/EstablishmentForm.tsx` — new section
  "OSHA Reporting" with EIN, company name, size dropdown, type dropdown.
- `frontend/src/pages/modules/IncidentForm.tsx` — new section "ITA
  fields" with days-away, days-restricted, date of death, treatment
  facility type, time unknown checkbox, injury/illness description.
- Types mirror the Go structs in `frontend/src/types/*.ts`.

### Tests

- Go: round-trip read-after-write on both tables for the new columns.
- Frontend: tsc clean. No new component tests — additive fields.

---

## Phase 4b — Exporter + HTTP routes

### Go

- `internal/osha_ita/` package:
  - `exporter.go` — `ExportDetail(db, establishmentID, year)
    (io.Reader, error)` and `ExportSummary(db, establishmentID, year)
    (io.Reader, error)`. Both read the matching view and stream CSV via
    `encoding/csv`.
  - `exporter_test.go` — fixtures for one establishment with 3 incidents
    covering 3 distinct severity/case combinations. Assert CSV row count,
    column order, correct enum translation, aggregated summary counts.

### New routes (admin-only, audit-logged)

- `GET /api/osha/ita/detail.csv?establishment_id=N&year=YYYY`
- `GET /api/osha/ita/summary.csv?establishment_id=N&year=YYYY`
- `GET /api/osha/ita/preview?establishment_id=N&year=YYYY` — JSON
  preview: row counts + column header list, no body. Drives the UI's
  pre-download confirmation.

Audit entries written via `audit.Record` with `module = "osha_ita"`.

### Tests

- `TestExportDetailShape` — known fixture → exact-bytes CSV equality.
- `TestExportSummaryAggregation` — 3 incidents → correct totals.
- `TestExportNoRowsEmitsFlagAndZeros` — establishment with zero
  incidents emits `no_injuries_illnesses=Y` and zero totals per ITA spec.
- `TestExportRejectsNonAdmin` — 403 for non-admin.
- `TestExportAuditEntry` — one entry per export.

---

## Phase 4c — UI

### New page

- `frontend/src/pages/osha-ita/ExportPage.tsx` at route `/osha-ita`
  (sidebar: 📤 OSHA ITA, admin-only entry). Layout:
  - Year picker (default = current calendar year)
  - Establishment picker (reuse `EntitySelector`)
  - Preview panel — row counts + "no injuries/illnesses" flag
  - Two download buttons: "Download Detail CSV" + "Download Summary CSV"
  - Short help block with link to OSHA's ITA portal

### Sidebar entry

- Added to `Shell.tsx` under an Admin section or promoted next to
  Incidents. Grouping TBD at build time.

### Tests

- tsc clean.
- Browser smoke: seed 3 incidents in a fresh DB, export both CSVs, diff
  against a committed golden file under `frontend/src/pages/osha-ita/
  __fixtures__/`.

---

## Phase 4d (optional) — Import ITA CSVs back

Piggy-backs on Phase 2 / 3. Two new mappers in `internal/importer/`:

- `osha_ita_detail.go` — target table `incidents` + `employees` (upsert
  by case_number; employees by employee_number + establishment).
- `osha_ita_summary.go` — target: no-op at the row level, instead
  updates `establishments.annual_avg_employees` + `total_hours_worked`
  for the `year_filing_for` column and records the totals in an audit
  entry. (Summary rows aren't stored per se.)

Registered via the usual `init()` pattern. No new routes, no new UI —
users pick "OSHA ITA Detail" / "OSHA ITA Summary" in the existing
`/admin/import` module dropdown.

Rationale: round-tripping means a user who gets ITA data back from an
acquisition (or migrates from another EHS tool) can land it in Odin
without re-typing.

Deferred if Phase 4a/b/c runs long. Small enough to pick up in a
follow-up session.

---

## Phase 4e (optional) — Mimir TURTLE graph viewer

**Plan lives in the ontology repo**, not here. See
`third_party/ehs-ontology/docs/plans/2026-04-21-ontology-v3.3.md`
(Phase 2) for the full Mimir spec: stack (Python + rdflib + FastAPI
+ Cytoscape.js), repo layout (sibling repo `asgardehs/mimir`
submoduled into `ehs-ontology` at `tools/mimir/`), MVP features,
and sequencing.

No odin-side work — Mimir lives entirely outside this repo.
Optional, doesn't block any other Phase 4 sub-phase.

---

## Out of scope

- **Direct OSHA ITA portal submission.** Users still download the CSVs
  and upload them via OSHA's web UI. API submission is a future item
  and requires OSHA API credentials + agreement processing that isn't
  in scope here.
- **Historical year fills via ITA template.** If a user needs to backfill
  2022 data, they use Phase 4d (import ITA detail CSV) — we don't build
  a bespoke multi-year re-entry UI.
- **OSHA 300 printable log rendering.** If an auditor wants a
  printable Form 300 for on-site posting, that stays on the PDF-fill
  backlog (future, separate from this plan).
- **Companies table.** `company_name` is a free-text column on
  `establishments` for MVP. A real `companies` entity with roll-up
  views is a future refactor.
- **State-plan variations.** Some OSHA State Plans (California,
  Michigan, etc.) add extra fields on top of federal ITA. MVP targets
  federal ITA only.

---

## Open decisions (resolved 2026-04-21)

- [x] **Sidebar placement.** Admin-only entry — compliance folks only.
  The sidebar is already crowded, so broader sidebar-refactor work is
  tracked separately in `TODO.md`; don't let ITA placement drive that
  refactor. If the Admin section gets a sub-grouping in the refactor,
  ITA lives there.
- [x] **Golden-file maintenance.** Exact-bytes golden. Accept the tax
  that ITA template changes trigger a golden refresh — ITA publishes
  column order and doesn't reorder mid-year, and exact-bytes catches
  regressions a structural assert would silently miss. If OSHA ever
  starts reordering, swap to a semantic-diff helper (parse both CSVs
  as record sets, compare as ordered maps) — ~50 LOC, tracked as a
  future enhancement, not needed for MVP.
- [x] **`size_code` — store explicitly.** OSHA has bumped the ITA
  thresholds historically; a stored value is auditable and survives
  threshold changes in the ontology. Keeps the reporting-year value
  frozen at the time the user ran the export.
- [x] **`year_filing_for` — user picks every time.** No inference, no
  defaults. Transfers filing-period liability to the user, which is
  where it belongs. The field is mandatory on the export page; the
  establishment picker doesn't reveal the download buttons until a
  year is selected.
- [x] **Empty-year behavior — let it export.** An establishment with
  zero incidents for the selected year still has to file the summary
  (OSHA 1904.41 covers establishments ≥ 20 employees regardless of
  incident count). `no_injuries_illnesses="Y"` on the summary row;
  totals all zero; `change_reason` blank. Detail CSV for an empty year
  contains only the header row.

---

## Suggested build order

1. **4a.1** ontology v3.3 + HermiT + CHANGELOG + README bump.
2. **4a.2** SQL additions (columns + lookup + mapping + 2 views) +
   seed data for the five ITA enums + mapping seed from v3.3 SKOS
   triples.
3. **4a.3** Repository + form field plumbing. Browser-smoke establish
   + incident creates round-trip the new fields.
4. **4b** Exporter + routes + tests.
5. **4c** ExportPage UI + sidebar entry + browser smoke (golden CSV).
6. **(optional) 4d** Importer mappers for round-trip.

Each sub-phase should ship as its own commit following the existing
cadence (`sql(module_c): Phase 4a.2 — …`, etc.), pushed at the end of
the sub-phase.
