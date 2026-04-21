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
- **Additive only where possible.** Module D is a brand-new module (no
  collision risk); import + PDF surfaces don't modify existing schemas.

## Cross-cutting decisions

Locked in 2026-04-20 unless noted.

1. **Module D scope — bundled.** One `module_d_clean_water.sql` covering both
   NPDES process wastewater and stormwater (matches Module B's Title V + CAA
   pattern). Internally grouped with clear section headers.
2. **Module D frontend — bespoke pages.** Primary records (permits,
   discharge points, sample events, SWPPPs) get list/detail/form pages
   matching Modules A–C. Configuration tables (parameters, limits, sectors)
   stay admin-only read-through for MVP.
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

Extend `docs/ontology/ehs-ontology-v3.1.ttl` → `ehs-ontology-v3.2.ttl`.
Pattern mirrors the existing CAA coverage (Module B's ontology depth).

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

Single PR: `docs/ontology/ehs-ontology-v3.2.ttl` + a short changelog in
`docs/ontology/CHANGELOG.md` explaining what v3.2 adds.

---

## Phase 1 — Module D: Clean Water Act SQL + backend

### Schema

Promote + merge the two archive files into `module_d_clean_water.sql`,
load-ordered after Module B (depends on permits + establishments).

**Primary tables:**

- `npdes_permits` — individual/general permit metadata, effective/expiration
  dates, authorized discharges, limits summary. FK to `establishments`.
- `discharge_points` — outfall id, type (process wastewater / stormwater /
  combined), receiving body, lat/lon, FK to permit.
- `ww_monitoring_locations` — sampling points. FK to discharge_point (nullable
  for internal process monitoring).
- `ww_parameters` — seed table of common parameters (BOD, TSS, pH, oil &
  grease, metals, priority pollutants). Three dozen rows; non-editable seed.
- `ww_permit_limits` — permit_id + parameter_id + limit (daily max / monthly
  avg) + units. Supports categorical + narrative limits.
- `ww_sample_events` — a discrete sampling event at one location, with
  date/time, collector, method.
- `ww_sample_results` — event + parameter + result + qualifier + reporting
  limit + method. One row per parameter per event.
- `sw_swpps` — SWPPP document metadata per establishment (revision number,
  effective date, next review, responsible staff).
- `sw_bmps` — BMP catalog per SWPPP (structural vs non-structural,
  description, inspection cadence).
- `sw_outfall_benchmarks` — benchmark monitoring values per outfall per
  sector (e.g., SIC 2812, 3471).

### Seed data

- `ww_parameters`: 40 CFR 423 priority pollutants + conventional pollutants.
- `sw_industrial_sectors`: SIC → stormwater general permit sector mapping
  (about 30 rows from the EPA Multi-Sector General Permit).

### Go repository + routes

Follow the Module B pattern:
- `internal/repository/clean_water.go` with `NPDESPermitInput`,
  `DischargePointInput`, `SampleEventInput`, `SampleResultInput`,
  `SWPPPInput`, `BMPInput`.
- `POST/PUT/DELETE /api/npdes-permits{/:id}` + `/revoke`.
- `POST/PUT/DELETE /api/discharge-points{/:id}` + `/decommission` +
  `/reactivate`.
- `POST/PUT/DELETE /api/ww-sample-events{/:id}` + `/finalize`.
- `POST /api/ww-sample-results` + `DELETE /api/ww-sample-results/{id}`.
- `POST/PUT/DELETE /api/sw-swpps{/:id}`.
- `POST/PUT/DELETE /api/sw-bmps{/:id}`.
- List routes via `entityRoutes(...)` for each.

### Frontend

Match Module B's depth:
- **NPDES Permits** — list/detail/form, status actions (revoke).
- **Discharge Points** — list/detail/form, status actions
  (decommission/reactivate), `EntitySelector` for npdes_permit.
- **Sample Events + Results** — sample events list + detail; Results entered
  via a modal on the event detail page (bulk-friendly grid: one parameter per
  row with result + qualifier).
- **SWPPPs** — list/detail/form. BMPs managed via a modal on SWPPP detail.
- Sidebar: new **💧 Clean Water** group containing the four primary entries
  (or one "Clean Water" icon pointing to a tabbed landing page — decide in
  Phase 1 build).

### Tests

- Repository: CRUD + audit parity with Module B's tests.
- Server: E2E via httptest covering the create-permit → add discharge-point
  → add sample-event → add sample-results path.
- Seed data: migration test confirms `ww_parameters` has ≥30 rows.

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

1. **Phase 0** — Ontology v3.2 review + PR. One work unit.
2. **Phase 1** — Module D SQL + Go repo + API + frontend. Biggest unit
   (3–4 work units). Parallelizable only at the frontend-page level once
   the backend lands.
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
- [ ] **Parameter lookup: flat `ww_parameters` vs typed
  `water_pollutants` / `water_pollutant_types` split.** Module B uses the
  split pattern for air pollutants. Revisit while writing the schema in
  Phase 1 — easier to decide with the seed data in front of us.
