# Module D + CSV / Excel Import + OSHA Fillable PDFs — Full Plan (2026-04-20)

Three semi-independent tracks bundled into one plan so they can be sequenced
sensibly (ontology → schema → import paths → forms export). Each phase is
self-contained; stop points between phases are clean.

## Principles

- **Ontology is the source of truth.** Module D's SQL follows an explicit
  ontology extension (v3.2 — CWA / Water domain), not the other way around.
  No table lands until the concept is in `ehs-ontology-v3.2.ttl`.
- **CSV stays pure Go; Excel uses ratatoskr.** CSV is trivially handled by
  `encoding/csv` and doesn't justify a Python runtime. Excel benefits from
  pandas' handling of the real-world mess — that's where ratatoskr earns
  its ~50 MB payload.
- **Generic import pipeline, per-module mapping.** One column-mapping layer
  (headers → target fields), one preview/validate/commit flow, reused across
  every module. Per-module specifics live in a mapping registry, not in
  duplicated Go code.
- **Fillable PDFs are pure Go.** `pdfcpu` fills OSHA's AcroForm PDFs
  directly from Go structs. No Python needed for this path.
- **Additive plus relocation for Module D.** Original premise was "brand-new
  module, no collision risk." Audit (2026-04-21) surfaced that most CWA
  machinery already exists inside `module_industrial_waste_streams.sql`
  and that `permits` / `permit_types` is already a generic shared-table
  structure with CWA permit types pre-seeded. Module D is therefore a
  **consolidation** (relocate `ww_*` tables into `module_d_clean_water.sql`)
  plus a **gap fill** (4 genuinely new tables: discharge points, SWPPPs,
  BMPs, outfall benchmarks), not a greenfield build. NPDES permits reuse
  the generic `permits` table. Import + PDF surfaces still don't modify
  existing schemas.

## Cross-cutting decisions

Locked in 2026-04-20 unless noted.

1. **Module D scope — bundled + middle path (revised 2026-04-21).** One
   `module_d_clean_water.sql` covering both NPDES process wastewater and
   stormwater, but scoped to CWA-distinctive content only. Generic `permits`
   / `permit_types` and the cascade tables (conditions, limits, monitoring
   requirements, reporting, deviations, modifications, compliance calendar)
   stay in `module_permits_licenses.sql`. Water-specific monitoring tables
   relocate from `module_industrial_waste_streams.sql` into the new file.
   See the Phase 1 "Reality check" block for the full audit.
2. **Module D frontend — mix of bespoke + reuse (revised 2026-04-21).**
   Discharge Points, Sample Events, and SWPPPs get fresh list/detail/form
   pages. NPDES permits **reuse the existing** `PermitList/Detail/Form`
   pages with a new filter view keyed on `permit_type_id IN (10, 11, 12,
   13)`. Configuration tables (parameters, limits, sectors) stay admin-only
   read-through for MVP.
3. **Import — file upload location.** Multipart upload to a new
   `/api/import/csv` endpoint (and later `/api/import/xlsx`) streaming to a
   temp file under `ODIN_DATA_DIR/imports/{uuid}/` with a 30-minute TTL.
   Admin-only for MVP.
4. **Import — preview vs commit lifecycle.** _Pending._ Two-step upload →
   review → commit is settled; the only open piece is whether a
   "commit valid rows only" checkbox is exposed, or whether the user must
   fix the source file before commit. Comes back for tightening before
   Phase 2 starts.
5. **Ratatoskr — ready.** Forked into `asgardehs/ratatoskr` with the
   sloppy-code fix landed. Reload-surviving extraction available via
   `python.NewEmbeddedPythonInCacheDir("odin")` — pins to
   `~/.cache/odin/python-<hash>/`, one-time extraction per installed version.
   Docs live in the repo + `/home/adam/media/projects/asgard/ratatoskr/`.
   No ratatoskr-side work blocks this plan.
6. **OSHA PDFs — user splits the forms package.** The upstream
   `OSHA-RK-Forms-Package.pdf` gets split by the user into three files:
   `300.pdf`, `300A.pdf`, `301.pdf`. Odin commits these under
   `embed/forms/osha/` so the binary ships with everything it needs to fill.
   Means no in-Go PDF splitting step — introspection just reads three
   small PDFs.
7. **PDF output — download only.** Filename convention:
   `OSHA-300_{establishment_slug}_{year}.pdf`. In-browser PDF viewer is
   post-MVP and will be added alongside the SDS-on-Chemicals component so
   both surfaces share one pdf.js dependency.
8. **Audit trail.** Imports and PDF exports both record `audit.Entry` with
   `module = "imports"` / `module = "forms"`, `entity_id = {token or form}`,
   and a summary describing rows or record sets touched.

---

## Phase 0 — Ontology v3.2: Clean Water Act domain

Extend `third_party/ehs-ontology/ehs-ontology-v3.1.ttl` → `ehs-ontology-v3.2.ttl`.
Pattern mirrors the existing CAA coverage (Module B's ontology depth).

### Progress (2026-04-20 — in-flight, local commits only)

**Landed in local commit `b2819cd` (not yet pushed):**

- Archived v3.1 → `third_party/ehs-ontology/.archive/ehs-ontology-v3.1.ttl`; new file
  `ehs-ontology-v3.2.ttl` is live.
- Bumped `owl:versionInfo` to 3.2 in both header blocks; updated
  `dcterms:date`; appended a v3.2 additions list to the header rdfs:comment.
- 12 new CWA classes in 4 blocks:
  - **Water pollutant taxonomy** (5): `WaterPollutant` →
    `ConventionalPollutant` / `PriorityPollutant` / `NonConventionalPollutant`
    → `WholeEffluentToxicity`.
  - **Physical water infrastructure** (3): `DischargePoint`,
    `StormwaterOutfall` (subClassOf `DischargePoint`), `MonitoringLocation`.
  - **Water control equipment** (2): `WaterControlDevice` (new umbrella,
    broader than air's `ControlDevice`); `WastewaterTreatmentUnit` now a
    subClassOf `WaterControlDevice`.
  - **Stormwater planning** (2): `SWPPP`, `BestManagementPractice`.
- Restructured the file to free up the letter D for CWA: previous
  "MODULE D: EMPLOYEE INCIDENT MANAGEMENT" section renamed to
  "OPERATIONAL: EMPLOYEE INCIDENT MANAGEMENT" (content unchanged).
  Fixed the one stale "(Module D)" reference in
  `ehs:alignsWithRecordingCriteria`'s definition.

**Next when we resume:**

1. **Regulatory-program classes** — three classes, mirrors the shape of
   Module B's `TitleVPermit` / `FESOP`:
   - `ehs:NPDESPermit` (subClassOf `ehs:Permit`)
   - `ehs:PretreatmentStandard` (40 CFR 403 categorical)
   - `ehs:POTWDischargePermit` (indirect-discharge, local authority)
2. **Object properties** — six relations tying the new classes together:
   - `ehs:dischargesTo` (EmissionUnit → DischargePoint)
   - `ehs:monitoredAt` (DischargePoint → MonitoringLocation)
   - `ehs:sampledFor` (MonitoringLocation → WaterPollutant)
   - `ehs:subjectToPermit` (DischargePoint → NPDESPermit /
     POTWDischargePermit)
   - `ehs:coveredBy` (StormwaterOutfall → SWPPP)
   - `ehs:implements` (SWPPP → BestManagementPractice)
3. **Reconciliation pass** — narrow `ehs:WaterwayProximity` to site
   geography; add cross-references in `ehs:ReleaseToEnvironment` /
   `ehs:ChemicalIncident` to the new `NPDESPermit` chain.
4. **User side:** Adam is double-checking the compliance law book
   (specifically the SPCC context referenced in `WaterControlDevice` and
   the oil-release → Section 311 notification chain).
5. Once Phase 0 is done we squash/push the v3.2 commits together and
   move to Phase 1 (`module_d_clean_water.sql`).

### New classes

- **`ehs:WaterPollutant`** (subClassOf `ehs:Pollutant`) — pollutant regulated
  under CWA.
  - **`ehs:ConventionalPollutant`** — BOD, TSS, pH, oil & grease, fecal
    coliform (CWA §304(a)(4)).
  - **`ehs:PriorityPollutant`** — 126 EPA priority toxic pollutants
    (40 CFR 423, App A).
  - **`ehs:NonConventionalPollutant`** — everything else (nutrients,
    dissolved metals, etc.).
- **`ehs:DischargePoint`** — physical outfall where regulated discharge
  leaves the facility. Internal outfalls + external outfalls.
- **`ehs:MonitoringLocation`** — sampling point (may or may not equal a
  discharge point). Used for compliance sampling and internal process
  monitoring.
- **`ehs:WastewaterTreatmentUnit`** — treatment process component (clarifier,
  biological reactor, filter press, neutralization tank). Analogue of
  `ehs:EmissionUnit`.
- **`ehs:StormwaterOutfall`** (subClassOf `ehs:DischargePoint`) — outfall
  subject to stormwater regulation; ties to industrial-activity sectors and
  benchmark monitoring.
- **`ehs:SWPPP`** — Stormwater Pollution Prevention Plan. Document-level
  concept binding outfalls, BMPs, and inspection cadence.
- **`ehs:BestManagementPractice`** (BMP) — structural/non-structural control
  measure required by SWPPP or NPDES permit.

### New regulatory-program classes

- **`ehs:NPDESPermit`** (subClassOf `ehs:Permit`) — individual or general
  permit issued under CWA §402.
- **`ehs:PretreatmentStandard`** — 40 CFR 403 categorical standards for
  discharges to POTWs.
- **`ehs:POTWDischargePermit`** — indirect-discharge permit issued by the
  local publicly-owned treatment works.

### New relations

- `ehs:dischargesTo` — EmissionUnit → DischargePoint (wastewater side).
- `ehs:monitoredAt` — DischargePoint → MonitoringLocation.
- `ehs:sampledFor` — MonitoringLocation → WaterPollutant (which parameters
  apply).
- `ehs:subjectToPermit` — DischargePoint → NPDESPermit / POTWDischargePermit.
- `ehs:coveredBy` — StormwaterOutfall → SWPPP.
- `ehs:implements` — SWPPP → BestManagementPractice.

### Reconciliation

- Existing `ehs:WaterwayProximity` stays as a hazard-factor class; narrow its
  definition to "site geography" rather than "CWA scope."
- Existing CWA mentions in `ehs:ReleaseToEnvironment` / `ehs:ChemicalIncident`
  get cross-references to the new `ehs:NPDESPermit` chain.

### Deliverable

Single PR: `third_party/ehs-ontology/ehs-ontology-v3.2.ttl` + a short changelog in
`third_party/ehs-ontology/CHANGELOG.md` explaining what v3.2 adds.

---

## Phase 1 — Module D: Clean Water Act SQL + backend

### Reality check (audit landed 2026-04-21)

Before writing new SQL, a scope audit uncovered that most of what this phase
originally planned as "new" already exists in the schema — just spread across
two unrelated files and with no Go/frontend wiring. The rewritten phase
adopts the **middle path** from that review:

- **Generic `permits` pattern stays.** `module_permits_licenses.sql` already
  defines a generic `permits` + `permit_types` structure with `NPDES_INDIVIDUAL`
  (id 10), `NPDES_GENERAL` (11), `NPDES_STORMWATER` (12), `PRETREATMENT` (13),
  and `GWDP` (14) pre-seeded and stamped `regulatory_framework_code =
  'CWA_Framework'`. NPDES permits live as rows in that shared table with
  `permit_type_id` as discriminator. This aligns with the v3.2 ontology's
  `ehs:NPDESPermit ⊂ ehs:Permit` pattern — shared-table polymorphism.
  **No `npdes_permits` table is created.** NPDES benefits from the generic
  permit_conditions / permit_limits / permit_monitoring_requirements /
  permit_reporting_requirements / permit_report_submissions /
  permit_deviations / permit_modifications / compliance_calendar cascade
  that Title V already uses.
- **CWA-distinctive machinery consolidates into `module_d_clean_water.sql`.**
  Tables that belong to Module D in the ontology but currently live in
  `module_industrial_waste_streams.sql` get relocated. Four genuinely new
  tables (discharge points, SWPPPs, BMPs, outfall benchmarks) close the
  remaining gaps.
- **No Go/frontend wiring exists yet** for any `ww_*` table, so the relocation
  has no runtime callers to update.
- **Relocation is idempotent.** `CREATE TABLE IF NOT EXISTS` plus the
  `_migrations` tracking table in `internal/database/migrate.go` means fresh
  installs load the new file cleanly and existing dev DBs skip it (tables
  already exist). No data migration needed.

### Schema

Create `docs/database-design/sql/module_d_clean_water.sql`, load-ordered
after `module_permits_licenses.sql` and `module_industrial_waste_streams.sql`
in `internal/database/migrate.go`'s `moduleOrder` slice.

**Relocated from `module_industrial_waste_streams.sql` (existing; move as-is
then reconcile against v3.2 ontology):**

- `ww_monitoring_locations` — compliance sampling points; already FKs to
  `permits(id)` and `establishments(id)`.
- `ww_parameters` — water pollutant reference table; verify coverage against
  40 CFR 423 Appendix A + conventional pollutants.
- `ww_monitoring_requirements` — per-permit parameter/frequency matrix.
- `ww_sampling_events` — discrete sampling events.
- `ww_sample_results` — one row per parameter per event.
- `ww_flow_measurements` — flow-rate data supporting mass-loading
  calculations.
- `ww_equipment` / `ww_equipment_calibrations` — field and lab instruments.
- `ww_labs` / `ww_lab_submissions` — contract lab tracking.

The relocation removes these from `module_industrial_waste_streams.sql`,
shrinking that file to its original RCRA/hazardous-waste/manifest focus.

**New tables (fill the ontology-identified gaps):**

- `discharge_points` — physical outfall: id, type (process wastewater /
  stormwater / combined), receiving waterbody, lat/lon, FK to establishment,
  FK to permit (generic `permits(id)` — typically an NPDES row). Closes the
  existing dangling `outfall_id` FK hints in `permit_limits` and
  `permit_monitoring_requirements`.
- `sw_swpps` — SWPPP document metadata per establishment: revision number,
  effective date, next review, responsible staff, source file path.
- `sw_bmps` — BMP catalog per SWPPP: structural vs non-structural,
  description, inspection cadence, responsible role.
- `sw_outfall_benchmarks` — MSGP sector benchmark values per parameter,
  joined to `discharge_points` via outfall and to `ww_parameters` via
  parameter.

**Ontology reconciliation pass (during relocation):**

- Confirm `ww_parameters` rows cover the v3.2 `ehs:WaterPollutant` taxonomy
  (conventional / priority / non-conventional / WET). Add the pollutant-type
  discriminator column if missing.
- Confirm FK from the new `discharge_points` to `ww_monitoring_locations`
  is bidirectional-queryable (or add the reverse FK on
  `ww_monitoring_locations` if cleaner).
- Confirm `sw_swpps.establishment_id` + `sw_bmps.swppp_id` match the
  `coveredBy` / `implements` relations.

### Seed data

- `ww_parameters`: 40 CFR 423 Appendix A priority pollutants (~126) +
  conventional pollutants (BOD, TSS, pH, oil & grease, fecal coliform) +
  common non-conventional (nutrients, chloride, sulfate, TDS, WET). Tag each
  row with the `ehs:WaterPollutant` subclass (conventional / priority /
  non-conventional / WET).
- `sw_industrial_sectors`: SIC → MSGP sector mapping (~30 rows from the EPA
  2021 Multi-Sector General Permit).

### Go repository + routes

- `internal/repository/clean_water.go` — **no** `NPDESPermitInput`; NPDES
  reuses the existing `PermitInput` in `permit.go`. The new inputs are:
  - `DischargePointInput` (+ `/decommission` + `/reactivate` actions)
  - `WaterSampleEventInput` (+ `/finalize` action)
  - `WaterSampleResultInput`
  - `SWPPPInput`
  - `BMPInput`
- Routes via the existing `entityRoutes(...)` helper:
  - `POST/PUT/DELETE /api/discharge-points{/:id}` + `/decommission` +
    `/reactivate`
  - `POST/PUT/DELETE /api/ww-sample-events{/:id}` + `/finalize`
  - `POST /api/ww-sample-results` + `DELETE /api/ww-sample-results/{id}`
  - `POST/PUT/DELETE /api/swpps{/:id}`
  - `POST/PUT/DELETE /api/bmps{/:id}`

### Frontend

- **NPDES Permits** — reuse the existing `PermitList/Detail/Form` pages;
  filter by `permit_type_id IN (10, 11, 12, 13)` via a new list view.
  No new page components for permits themselves.
- **Discharge Points** — new list/detail/form with status actions and an
  `EntitySelector` for the governing `permits` row.
- **Water Sample Events + Results** — new list/detail. Results entered via
  a modal on the event detail page (bulk-friendly grid: one parameter per
  row with result + qualifier).
- **SWPPPs** — new list/detail/form. BMPs managed via a modal on SWPPP
  detail.
- Sidebar: new **💧 Clean Water** group. Decision on four entries vs tabbed
  landing page still deferred to build time (see open decision below).

### Tests

- `internal/database/migrate_test.go` — verify `module_d_clean_water.sql`
  loads after the permits + industrial-waste modules; confirm no duplicate
  `CREATE TABLE` collisions with pre-existing installs.
- Repository: CRUD + audit parity with Module B's tests for the 5 new
  entity types.
- Server: E2E via `httptest` covering
  `create NPDES permit → add discharge point → add sample event → add
  sample results` and `create SWPPP → add BMPs → link to stormwater
  outfall` paths.
- Seed data: migration test confirms `ww_parameters` has ≥100 rows
  (126 priority + ~5 conventional + ~10 non-conventional).

---

## Phase 2 — CSV import (pure Go)

A generic pipeline usable by any module; the first module wired up is
Employees (high-value bulk-entry target for new Odin customers).

### Architecture

- **`internal/importer`** package. `Importer` interface with one method per
  module: `MapRow(raw map[string]string) (any, []ValidationError)`. Generic
  engine calls each mapper, validates, and commits.
- **Mapping registry** — `internal/importer/registry.go` keyed by module
  slug (`employees`, `chemicals`, `incidents`, `training/completions`, `ppe/items`).
- **Preview token lifecycle** — upload stores the parsed rows +
  file-header-to-field mapping in a `_imports` metadata table keyed by a UUID
  with a 30-minute TTL. Commit references the token and either commits all
  or commits valid-only.

### Routes (admin-only)

- `POST /api/import/csv/{module}` — multipart upload, returns
  `{ token, headers, mapping_suggestions, rows_preview, validation_errors }`.
- `PUT /api/import/csv/{module}/{token}/mapping` — user-edited column mapping.
- `POST /api/import/csv/{module}/{token}/commit` — optional
  `?skip_invalid=1` query param.
- `GET /api/import/csv/{module}/{token}` — status + full validation report.
- `DELETE /api/import/csv/{module}/{token}` — discard.

### Frontend

- New admin page `/admin/import` — module picker + drop zone.
- After upload: column-mapping UI (source header → target field dropdown,
  with fuzzy-match suggestions), validation panel (row + column +
  message, sortable), commit button (with "commit valid rows only"
  checkbox).
- Import progress + result summary on commit.

### Modules wired in Phase 2

1. Employees (richest real-world need).
2. Chemicals.
3. Training completions.

Others follow the same pattern; add later without framework changes.

### Tests

- Registry: each mapper round-trips a synthetic CSV through preview + commit.
- Validation: rejects rows with bad FKs, bad dates, missing required fields.
- Audit: every commit records an `audit.Entry` with module = `imports` and
  a summary like `"Imported 47 rows into employees (3 skipped)"`.

---

## Phase 3 — Excel import via ratatoskr

Layers on Phase 2: same preview/commit API surface, different parsing
backend.

### Ratatoskr integration

Fork already landed at `asgardehs/ratatoskr` with reload-surviving
extraction. Odin's side of the integration:

- Add `github.com/asgardehs/ratatoskr/python` as a dependency.
- Pin pandas + openpyxl + xlrd versions (add to ratatoskr's pip requirements
  if not already present; otherwise call `pip install` at first run under
  the cache dir).
- `internal/ratatoskr` Go package initializes exactly once:
  ```go
  ep, err := python.NewEmbeddedPythonInCacheDir("odin")
  ```
  First launch extracts to `~/.cache/odin/python-<hash>/`; subsequent
  launches no-op. The `*EmbeddedPython` handle is stashed on the `Server`
  struct alongside `db`, `audit`, etc.
- Exposes `ratatoskr.ParseXLSX(bytes []byte) ([]map[string]any, error)` — a
  thin wrapper that shells out to a vendored Python script
  (`internal/ratatoskr/scripts/parse_xlsx.py`) and decodes the JSON result.

### New routes

- `POST /api/import/xlsx/{module}` — same response shape as CSV preview.
- Commit path is shared with Phase 2 (both produce the same intermediate
  row-map representation).

### Frontend

- Drop zone accepts `.csv`, `.xlsx`, `.xls`. File extension drives backend
  path selection. UI is otherwise identical to Phase 2.

### Tests

- Parse fixture `.xlsx` files covering: plain grid, merged cells, formulas,
  embedded numbers-as-text, date formats, multiple sheets (take first).
- Confirm ratatoskr startup cost: measure p99 parse of a 10k-row workbook;
  expected < 2s after warm-up.

### Out of scope (Phase 3)

- Writing `.xlsx` files back out (export). Tracked in backlog.
- Multi-sheet selection UI. MVP takes the first sheet only; log a warning if
  there are more.

---

## Phase 4 — Fillable PDFs (OSHA 300 / 300A / 301)

pdfcpu fills AcroForm fields from a Go `map[string]string`. One-shot per
form; no bespoke rendering engine.

### Discovery step (one-time, committed as test data)

- User splits the upstream forms package into three files committed to
  `embed/forms/osha/{300,300A,301}.pdf`.
- Script: `cmd/osha-form-introspect/main.go` reads each of the three PDFs
  via pdfcpu, dumps field names + types + page numbers to
  `internal/forms/osha/{300,300A,301}_fields.json`.
- The three field-map JSON files get committed so we know the exact names
  the mapping layer targets.

### Mapping layer

- `internal/forms/osha` package:
  - `FillForm300(year int, est Establishment, incidents []IncidentSummary) ([]byte, error)` — returns filled PDF bytes.
  - `FillForm300A(year int, est Establishment, summary YearlySummary) ([]byte, error)`.
  - `FillForm301(inc Incident, investigation Investigation, treatment Treatment) ([]byte, error)`.
- Mapping constants: `Form300FieldNames`, etc. Top-of-file so changes are
  visible.

### Routes

- `GET /api/forms/osha300?establishment_id=X&year=Y` — streams filled PDF
  with `Content-Disposition: attachment`.
- `GET /api/forms/osha300a?establishment_id=X&year=Y`.
- `GET /api/forms/osha301?incident_id=Z`.

### Frontend

- Download buttons:
  - `/incidents` list page: "Export OSHA 300 Log" (year + facility picker).
  - `/establishments/:id` detail page: "Export OSHA 300A Summary" (year
    picker).
  - `/incidents/:id` detail page: "Export OSHA 301 Form".

### Tests

- For each form: fill with a known-state fixture, extract fields back out
  via pdfcpu, assert round-trip equality on every mapped field.
- Audit: every form export writes `module = "forms"`, entity_id = form
  type, summary with date range + count.

---

## Out of scope

- **Round-trip edit of imported rows.** Imports create new rows only; editing
  existing rows via import is a separate feature.
- **Export to CSV/Excel.** MVP is inbound only. Export backlog item.
- **Electronic OSHA submission (ITA portal).** PDF export is the MVP. Direct
  API submission to OSHA's Injury Tracking Application is a future item.
- **PDF rendering of non-OSHA forms.** Module D permit applications,
  emission inventories, etc. are all potential future candidates but not in
  this plan.
- **Multi-sheet XLSX selection.** MVP takes the first sheet; tracked in
  backlog.

## Suggested build order

1. **Phase 0** — Ontology v3.2 review + PR. One work unit. **Done
   2026-04-21, commit `5598c8d`.**
2. **Phase 1** — Module D SQL relocation + gap-fill + Go repo + API +
   frontend. ~2–3 work units (revised down from 3–4 after the audit;
   NPDES permit pages reuse existing Permit pages, and ~9 `ww_*` tables
   relocate rather than requiring fresh design). Parallelizable at the
   frontend-page level once the SQL and Go layers land.
3. **Phase 2** — CSV import (framework + employees + chemicals + training).
   ~2 work units.
4. **Phase 4** — OSHA PDFs. ~1.5 work units (introspect + three fills + UI
   wiring).
5. **Phase 3** — Excel via ratatoskr. Last because it depends on the fork
   landing in the Asgard org; can be moved earlier once ratatoskr exists.

## Open decisions for tightening before we start

- [ ] **Import: "commit valid rows only" checkbox or force source fixes?**
  (Cross-cutting decision #4 — UX + data-quality implications.) Fix before
  Phase 2 starts.
- [ ] **OSHA PDFs: generate on-the-fly vs cache per establishment+year.**
  Cache helps repeat downloads but adds invalidation complexity. Revisit
  before Phase 4 starts.
- [ ] **Clean Water sidebar shape: one grouped entry or four entries?**
  Four items (NPDES Permits, Discharge Points, Sample Events, SWPPPs) is a
  lot for the sidebar. Options: one "💧 Clean Water" entry that opens a
  tabbed landing page, or a subdivided group like the Custom Tables group
  we shipped in schema-builder Phase 4. Defer to Phase 1 build-time when
  the UI shape is clearer.
- [x] **Parameter lookup: flat `ww_parameters` vs typed
  `water_pollutants` / `water_pollutant_types` split.** _Resolved
  2026-04-21:_ keep `ww_parameters` flat (the table already exists in
  `module_industrial_waste_streams.sql`) and add a pollutant-type
  discriminator column during the Phase 1 relocation. This matches the
  v3.2 `ehs:WaterPollutant` taxonomy (conventional / priority /
  non-conventional / WET) without duplicating the reference-table
  machinery Module B needs because air pollutants can belong to multiple
  types simultaneously (HAP + VOC), which is not true of water pollutants.
