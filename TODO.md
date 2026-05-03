# Odin — Backlog

Post-plan / post-release items preserved from `docs/plans/2026-04-19-data-entry.md`.
Not in scope for the current phase; tracked here so they don't get lost.

## Future enhancements (post-plan backlog)

Ideas we want to preserve but are explicitly not in scope for this plan.

- **NAICS / SIC code lookup helper on the Establishment form.** Currently the
  user types raw codes into free-text inputs. For EHS professionals new to the
  field, this is easy to get wrong. Integrate an NAICS lookup (NAICS Association
  API or the Census Bureau's NAICS data; evaluate license + API stability before
  committing) so the user can search by keyword ("electroplating" → 332813) and
  pick. The matching 4-digit SIC can be inferred from the 6-digit NAICS via a
  lookup table or the same API. Value: reduces data-entry errors and lowers the
  learning curve for first-time EHS managers. Implementation notes: same
  `EntitySelector`-style popup but backed by a remote API instead of a local
  list; cache results since these codes don't change often.

- **SDS PDF storage on Chemicals.** Every chemical on the inventory should have
  its Safety Data Sheet attached — it's the source of truth for the GHS flags,
  physical properties, and PPE already captured in the form, and OSHA 29 CFR
  1910.1200(g) requires SDSs be "readily accessible" to employees. Need to add:
  - Backend: new `chemical_documents` table (or reuse a generic `attachments`
    table) keyed by `chemical_id`, storing `filename`, `mime_type`,
    `size_bytes`, `uploaded_by`, `uploaded_at`, plus the file itself. For a
    single-tenant desktop app like Odin, filesystem under
    `ODIN_DATA_DIR/chemical_sds/{chemical_id}/` is simplest; SQLite BLOB works
    but bloats backups.
  - Endpoints: `POST /api/chemicals/{id}/documents` (multipart upload),
    `GET /api/chemicals/{id}/documents` (list),
    `GET /api/chemicals/{id}/documents/{docId}` (stream with
    Content-Disposition), `DELETE /api/chemicals/{id}/documents/{docId}`.
    Admin-only for delete.
  - Frontend: a Documents section on Chemical detail with drop zone + list +
    preview link. Bonus — inline PDF viewer (embed pdf.js) so users don't have
    to download to read, but MVP can just open in new tab.
  - Versioning: store each new upload as a new row with `superseded_at` on the
    old one rather than overwriting — SDSs get revised and the history matters
    for OSHA recordkeeping.
  - Future tie-ins: auto-populate chemical flags from SDS text extraction
    (Section 2 GHS classification, Section 9 physical properties) — would save
    significant data entry. Could live behind a feature flag initially.

- **Schema import/export between establishments.** Once the Schema Builder
  ships, admins should be able to export a custom table's definition
  (metadata rows from `_custom_tables`, `_custom_fields`,
  `_custom_relations`) to a portable file and import it into another
  establishment's Odin instance. Format: JSON with a version field and a
  stable shape that survives minor metadata additions. Flow: export
  button on the designer page → download `.odin-schema.json`; import
  button on `/admin/schema` → file picker → diff preview → apply.
  Data rows are *not* exported — schema only. Keeps establishments from
  drifting when the same custom table is wanted in multiple places.
  Not in scope for the initial Schema Builder phase.

- **Clickable Inspection Findings — read-only detail modal.** Today findings
  are listed on the Inspection detail page but can't be opened. A user should
  be able to click a row and see the full record (description, citation,
  immediate action + by-whom, closure notes, etc.) in a read-only modal —
  the list row truncates description at 120 chars, which is fine for the
  summary view but not for review. Keep it read-only for now; "edit finding"
  can follow the same pattern as the other detail → edit transitions. Low
  effort: reuse `Modal` + `Field`/`Section`, open on row click, close on
  escape/backdrop. Close button already-open close-finding flow stays on
  its own "Close" button to keep destructive/state-changing actions explicit.

- **New Incidents** under *Classification & Severity* Case Classification Code and Body Part Code change to drop down selection menu.

_ **Inspections** Create a tool similar to Schema Builder, to allow for users to create custom Inspections beyond what we supplied. House access to the module on the Inspections screen.

- **New Audits** We supply a Integrated audit check box, but not a way for the user to select what ISO Frameworks are Integrated. 

_**Export** Design Export Function for Admins to be able to Export records to xlsx, json, or csv.

## OSHA ITA exporter — pre-ship hardening (from 2026-04-26 review)

External review of the v_osha_ita_detail / v_osha_ita_summary pipeline turned up
a cluster of items that are invisible until a real ITA upload fails. Grouped
here so they get fixed together before first submission. All citations are
current as of 2026-04-26.

- **Date format — verify ISO vs MM/DD/YYYY against a real ITA upload.** The
  detail view at `docs/database-design/sql/views/osha_ita.sql:39,46,47,60`
  emits `incident_date`, `date_of_birth`, `date_hired`, `date_of_death` as
  raw column values (ISO `YYYY-MM-DD`). OSHA's ITA template historically
  expects `MM/DD/YYYY`. The supplied template at
  `osha_300/ita_template_form_300-301_csv_data.csv` is header-only and
  doesn't disambiguate. Step 1: do a sandbox upload with one ISO row and
  one MM/DD row to see what their parser accepts in 2026. Step 2: if ISO
  is rejected, wrap each date column in `strftime('%m/%d/%Y', ...)` in the
  view. Add a test asserting the chosen format so a future view edit can't
  silently regress it.

- **Time format — confirm HH:MM (24-hour) and add an export-time guard.**
  `osha_ita.sql:52-53` passes `time_employee_began_work` and `incident_time`
  through unchanged. The schema comment at
  `docs/database-design/sql/module_c_osha300.sql:284` says "HH:MM (24-hour)"
  but nothing enforces it. Fix: add a CHECK constraint on the incidents
  table (`incident_time GLOB '[0-2][0-9]:[0-5][0-9]'` or similar), and an
  assertion in the time-input component that rejects AM/PM and seconds at
  the form layer. Test should seed a non-empty time value and assert the
  exact string that comes out the other end.

- **`sex = "X"` may be rejected by the ITA parser.** The fixture at
  `internal/osha_ita/exporter_test.go:71` seeds an "X" employee and the
  test at line 181 asserts it round-trips. `osha_ita.sql:48` is a raw
  `emp.gender AS sex` with no translation. OSHA's ITA enum has historically
  been `M`/`F`/blank; non-binary support has been on their roadmap but not
  confirmed landed. Two-step fix: (1) verify against a real upload whether
  `X` is accepted today; (2) if not, add an `ita_gender_mapping` SKOS-style
  lookup that translates internal gender codes to ITA-acceptable values
  (`X` → blank for now, `M`/`F` pass-through), keeping rich gender data
  inside Odin while exporting only what ITA accepts. Pattern matches the
  existing `ita_outcome_mapping` / `ita_case_type_mapping` tables.

- **Date of death silently empties for fatalities.** The fatality fixture
  at `exporter_test.go:101` seeds `severity = "FATALITY"` but no
  `date_of_death`, and the test never asserts that column. The view emits
  `incident_outcome = "Death"` with a blank `date_of_death`, which ITA
  almost certainly rejects. Fix at the form layer: when `severity_code =
  'FATALITY'` is selected on the IncidentForm, make `date_of_death`
  required and validate it is on or after `incident_date` (death can occur
  days after the event, so `COALESCE(date_of_death, incident_date)` in the
  view would be subtly wrong). Add a CHECK constraint on the incidents
  table to enforce the same invariant at write time, and update the
  fatality fixture to seed a real `date_of_death` so the test exercises
  the populated path. Add a separate test that submitting FATALITY without
  `date_of_death` is rejected.

- **180-day caps not enforced on `dafw_num_away` / `djtr_num_tr`.** OSHA
  caps both at 180 days per 1904.7(b)(3)(v) and 1904.7(b)(4)(iii). The
  view at `osha_ita.sql:43-44` emits raw values; schema comments at
  `module_c_osha300.sql:309-310` document the cap but nothing enforces
  it. Per the plan's "business logic in SQL" principle, clamp at the
  view: `MIN(180, i.days_away_from_work) AS dafw_num_away` and same for
  `djtr_num_tr`. Also add a CHECK constraint at the table level so bad
  data can't even be written (`days_away_from_work IS NULL OR
  days_away_from_work BETWEEN 0 AND 180`). The form should warn (not
  silently truncate) when a user types > 180 so they understand the cap
  is being applied. Test with a 200-day fixture and assert the CSV emits
  180.

- **`type_of_incident` LEFT JOIN can emit empty strings.** `osha_ita.sql:77-80`
  LEFT JOINs `ita_case_type_mapping` and `ita_incident_types`. A recordable
  incident whose `case_classification_code` is missing from the mapping
  table emits an empty `type_of_incident` — the worst failure mode (CSV
  passes shape checks, ITA rejects on content). Fix: change to INNER JOIN
  so a missing mapping drops the row from the export and surfaces as a
  count delta in `Preview`. Add a coverage test in
  `internal/database/deltas_test.go` (or a new mappings test) that asserts
  every active `case_classifications.code` has a row in
  `ita_case_type_mapping`, so the gap is caught at CI time rather than
  export time.

- **Switch from structural to exact-bytes golden test.** The plan at
  `docs/plans/2026-04-21-osha-ita-csv-export.md:317-319` locked in
  exact-bytes golden testing ("ITA template changes trigger a golden
  refresh — exact-bytes catches regressions a structural assert would
  silently miss"). The actual tests in `internal/osha_ita/exporter_test.go`
  do per-column structural asserts. Add a `TestExportDetail_GoldenBytes`
  and `TestExportSummary_GoldenBytes` that read a committed CSV from
  `internal/osha_ita/testdata/` and compare bytes. Keep the structural
  tests for diagnostic specificity when the golden diff fails. Document
  the regenerate command (`go test -run GoldenBytes -update`).

- **Test gaps around column aliasing and narrative fields.** Current tests
  in `internal/osha_ita/exporter_test.go` never assert that:
  (1) the `location_description → incident_location` alias at view line 40
  round-trips correctly,
  (2) the four narrative columns read from the right source columns —
  `nar_before_incident ← activity_description` (line 56),
  `nar_what_happened ← incident_description` (line 57),
  `nar_injury_illness ← injury_illness_description` (line 58),
  `nar_object_substance ← object_or_substance` (line 59).
  The fixture only seeds `incident_description`, so a future swap of any
  of these aliases would pass the existing tests. Fix: extend the fixture
  to seed distinct sentinel strings for all four narrative columns plus
  `location_description`, then assert each appears in the expected output
  column. Cheap and high-value — catches the most likely refactor footgun.

- **`treatment_in_patient` collapses NULL → "N" — fine for ITA, plan around
  it for the printed 300 log.** `osha_ita.sql:50-51` does
  `CASE WHEN was_hospitalized = 1 THEN 'Y' ELSE 'N' END`, which conflates
  "we know the employee was not hospitalized" with "we don't know yet."
  OSHA ITA accepts Y/N only, so this is correct for the ITA export. Not a
  bug today; flagged here as a constraint to remember when the printable
  300 log lands — that view should distinguish unknown from known-false,
  which means the underlying column needs to stay nullable (it currently
  is) and the 300-log view needs three-state logic (`Y` / `N` / blank) at
  render time.

- **Sidebar refactor.** The left-nav list has grown past a comfortable read
  as modules have landed — 13 main entries + 4 Clean Water entries + 3
  Admin entries today, and Phase 4 (OSHA ITA) + the reporting pipeline will
  add more. Options to explore:
  - Promote functional groupings (Compliance / Operations / Admin) with
    collapsible sections — matches the Clean Water group pattern.
  - Keep the common modules flat and move lower-traffic items (Admin,
    specialty reports like OSHA ITA) into a secondary nav / overflow menu.
  - Command palette (⌘K) for power users, so sidebar only carries
    frequently-clicked entries.
  Revisit before the initial release; not urgent while module count is
  growing fast. Flagged during Phase 4 planning (2026-04-21).
