# Data Entry UI — Full Plan (2026-04-19)

## Principles

- **Pages for primary records, modals for sub-records.** Create/edit of any top-level entity is a dedicated page. Sub-records (things that only make sense in the context of a parent — inventory snapshots on a chemical, corrective actions on an incident, completions on a training course) open as modals from the parent's detail page.
- **Single-page forms with visual section groups.** No wizards or multi-step flows. Long forms (incidents, chemicals) get grouped sections with headings, not tabs or steps.
- **Routes:** `/module/new` and `/module/:id/edit` alongside the existing `/module` (list) and `/module/:id` (detail).
- **Roles:** create/edit gated by non-readonly role. Most destructive actions (delete, deactivate, close) admin-only.
- **Save UX:** Save returns to detail page. "Save and add another" on create forms where repetitive entry is common (employees, chemicals, training completions). Unsaved-changes guard on edit pages.

## Decisions already made

- Admin-only for change-password, regenerate-recovery-key, user management (compliance).
- Use existing Nótt/Dagr palette. Section headings in `--color-purple`.
- Form inputs already have house style in `Account.tsx` and `Login.tsx` — extract to shared component in Phase 0.

---

## Phase 0 — Shared infrastructure

Ship these before any module UI. Everything in Phase 1+ depends on them.

### Components

1. **`<FormField>`** — label, input/select/textarea/date, error message, required indicator. Wraps the existing input styling. One component, discriminated union on `type`.
2. **`<Modal>`** — overlay with backdrop, ESC-to-close, click-outside-to-close with guard if form is dirty. Header + body + footer slots.
3. **`<EntitySelector>`** — searchable async dropdown. Hits `GET /api/{entity}?q=...` (may need a search param added — investigate). Takes `entity` (e.g. `employees`), `value` (id), `onChange`, `renderLabel(row)`. Caches results per query.
4. **`<SectionCard>`** — the purple-heading rounded card used on Account detail. Pull it out now.
5. **`<FormActions>`** — Save / Cancel / (optional) Save-and-new button group, with loading/disabled states.
6. **`<StatusBadge>`** — color-coded pill for `status` fields (active/inactive/closed/expired/etc).
7. **`<ConfirmDialog>`** — yes/no confirmation (pattern from recovery-key regen).

### Hooks & utilities

- **`useUnsavedGuard(dirty)`** — browser beforeunload + in-app navigation warning.
- **`useEntityMutation(method, url)`** — thin wrapper around `api.post/put/delete` with loading/error state.
- **Date utilities** — the SQL schema uses `TEXT` dates; normalize to `YYYY-MM-DD` for `<input type="date">` and pass through as string.

### Backend gaps to close

- **Search param on list endpoints.** `EntitySelector` needs `?q=` on at minimum `/api/establishments`, `/api/employees`, `/api/chemicals`. The `entityRoutes` helper in `internal/server/api.go` will need a small extension, or use a dedicated `/api/{entity}/search`. Decide before Phase 1.
- **Reactivate endpoints.** Every entity with a `deactivate` action is one-way right now. Add matching `POST /api/{entity}/{id}/reactivate` for: employees, chemicals (undiscontinue), waste-streams, users, establishments, ppe/items (unretire), ppe/assignments (if needed), permits (unrevoke — maybe not applicable), incidents (unclose — maybe not). Decide per-entity whether reactivation is meaningful or whether some terminal states should stay terminal.

---

## Phase 1 — Foundation

Everything FKs to these, so they come first.

### 1. Establishments
**Page form fields:** name*, street_address, city, state, zip, naics_code, sic_code, peak_employees, annual_avg_employees, is_active (toggle).
**Sections:** Identity • Address • Workforce Counts.
**Status actions:** deactivate (not reversible via UI — could add reactivate later).
**Endpoints:** `POST /api/establishments`, `PUT /api/establishments/{id}`, `DELETE /api/establishments/{id}`.
**Sub-records:** none at create-time. Linked records (employees, permits, etc.) surface on detail page as count cards.

### 2. Employees
**Page form fields:** establishment_id*, employee_number, first_name*, last_name*, job_title, department, date_hired, is_active.
**Sections:** Identity • Employment.
**Status actions:** deactivate via `POST /api/employees/{id}/deactivate`.
**Endpoints:** `POST/PUT/DELETE /api/employees{/:id}`.
**Sub-records on detail page (modals):**
- Log training completion → `POST /api/training/completions`
- Assign training course → `POST /api/training/assignments`

### 3. Users admin (admin-only page, `/admin/users`)
**List:** all users with role, status, last login. Deactivate/reactivate buttons.
**Create form:** username*, display_name, password*, role (admin|user|readonly), is_active.
**Edit form:** display_name, role, is_active. (Password change via Account page for self; admin can use the existing `POST /api/users/{id}/password` via a modal.)
**Endpoints:** `POST/PUT /api/users{/:id}`, `POST /api/users/{id}/deactivate`, `POST /api/users/{id}/password`.
**Navigation:** new route; link from sidebar when role === admin.

---

## Phase 2 — Primary compliance records

### 4. Chemicals
**Page form fields:** establishment_id*, primary_cas_number, product_name*, manufacturer, physical_state, is_ehs, is_sara_313, is_pbt, is_active.
**Sections:** Product Identity • Regulatory Flags • Physical Properties.
**Status actions:** discontinue via `POST /api/chemicals/{id}/discontinue`.
**Endpoints:** `POST/PUT/DELETE /api/chemicals{/:id}`.
**Sub-records (modal on chemical detail):** *Deferred — see Deferred modules section. Requires backend Create/Delete + a `storage_locations` module with seed data.*

### 5. Incidents
**Page form fields:** establishment_id*, case_number, employee_id (involved), incident_date*, incident_time, location_description, incident_description*, case_classification_code, severity_code, status.
**Sections:** Classification • When/Where • What Happened • People Involved.
**Status actions:** close via `POST /api/incidents/{id}/close`.
**Endpoints:** `POST/PUT/DELETE /api/incidents{/:id}`.
**Sub-records (modals on incident detail):**
- Add corrective action → `POST /api/corrective-actions` with `investigation_id` or `incident_id` (clarify FK).
- Complete/verify corrective action → action endpoints.

### 6. Permits
**Page form fields:** establishment_id*, permit_type_id, permit_number*, permit_name, issuing_agency_id, effective_date, expiration_date*, status.
**Sections:** Permit Identity • Validity • Issuing Authority.
**Status actions:** revoke via `POST /api/permits/{id}/revoke`.
**Endpoints:** `POST/PUT/DELETE /api/permits{/:id}`.
**Sub-records:** none at launch. Conditions/attachments future work.

### 7. Inspections
**Page form fields:** establishment_id*, inspection_type_id, inspection_number, scheduled_date, inspection_date, inspector_id, status, overall_result.
**Sections:** Scheduling • Outcome.
**Status actions:** complete via `POST /api/inspections/{id}/complete`.
**Endpoints:** `POST/PUT/DELETE /api/inspections{/:id}`.
**Sub-records (modal on inspection detail):**
- Add finding → `POST /api/inspection-findings`. Close finding → `POST /api/inspection-findings/{id}/close`.

---

## Phase 3 — Supporting modules

### 9. Training Courses
**Page form fields:** establishment_id*, course_code*, course_name*, description, duration_minutes, delivery_method, has_test, passing_score, validity_months, is_active.
**Sections:** Course Identity • Delivery • Assessment.
**Endpoints:** `POST/PUT/DELETE /api/training/courses{/:id}`.
**Sub-records (modals on course detail):**
- Log completion (bulk-entry friendly: employee + date + score) → `POST /api/training/completions`.
- Assign course to employees → `POST /api/training/assignments`.

### 10. PPE Items
**Page form fields:** establishment_id*, ppe_type_id*, serial_number, asset_tag, manufacturer, model, size, in_service_date, expiration_date, status, current_employee_id.
**Sections:** Item Identity • Manufacturer • Service Dates • Current Assignment.
**Status actions:** retire via `POST /api/ppe/items/{id}/retire`.
**Endpoints:** `POST/PUT/DELETE /api/ppe/items{/:id}`.
**Sub-records (modals on item detail):**
- Assign to employee → `POST /api/ppe/assignments`. Return → `POST /api/ppe/assignments/{id}/return`.
- Log inspection → `POST /api/ppe/inspections`.

### 11. Waste Streams
**Page form fields:** establishment_id*, stream_code*, stream_name*, waste_category, waste_stream_type_code, physical_form, is_active.
**Sections:** Stream Identity • Classification • Physical Form.
**Status actions:** deactivate via `POST /api/waste-streams/{id}/deactivate`.
**Endpoints:** `POST/PUT/DELETE /api/waste-streams{/:id}`.

---

## Deferred modules

Not in this plan's scope — come back when upstream work clears.

- **Audits.** Deferred pending feedback from ISO auditors. Backend is complete; frontend skipped for now. When the auditor feedback lands, audits becomes a full-module add (list/detail/create/edit page + findings modal + sidebar icon).
- **Emission Units.** Deferred pending legal review to confirm all required fields are captured. Backend is currently GET-only by design. When writes are added, the module gets create/edit UI in the pattern of the other 11.
- **Chemical Inventory snapshot modal.** Originally planned as a sub-record on chemical detail. Deferred because the whole dependency chain is missing: no repo Create/Delete methods, no POST route, and no seeded `storage_locations` (required FK). Lift: add `storage_locations` as its own primary module first (list/detail/create/edit), seed some, then come back and add the inventory modal. Backend GET for `/api/chemical-inventory` already exists so list-only views can ship earlier if needed.
- **Inspection Findings modal.** Originally planned as a sub-record on inspection detail. Backend POST/close/DELETE for `/api/inspection-findings` already exists and works, but the modal UI is deferred to keep Phase 2 focused on primary records. Small lift when we come back — just a Modal + FormField form calling the existing endpoints.

## Decisions locked in

- **Lookup tables (NAICS, inspection types, PPE types, waste stream types, standards, etc.)** — seeded only for now. `EntitySelector` reads them as-is. Admin UIs for editing these come in a later pass, not this plan.
- **Audit log viewing** — **admin-only** "Activity" tab on detail pages, reading from `GET /api/audit/{module}/{entityID}`. Non-admins don't see the tab.
- **Reactivate endpoints** — needed backend work. See Phase 0 backend gaps. UI exposes reactivate as a button alongside deactivate on admin-accessible entity detail pages.

## Cross-cutting open questions

1. **Soft delete vs hard delete** — DELETE endpoints exist for most entities. Should the UI prefer deactivate-and-hide over hard delete for anything with audit history? Recommendation: yes — reserve DELETE for records created in error.
2. **Establishment scoping** — when editing from a particular establishment's context, should lists/selectors auto-filter to that establishment? Or always show everything?
3. **Bulk operations** — any need for "import chemicals from CSV" or similar at launch, or is single-record entry fine for now?

## Future enhancements (post-plan backlog)

Ideas we want to preserve but are explicitly not in scope for this plan.

- **NAICS / SIC code lookup helper on the Establishment form.** Currently the user types raw codes into free-text inputs. For EHS professionals new to the field, this is easy to get wrong. Integrate an NAICS lookup (NAICS Association API or the Census Bureau's NAICS data; evaluate license + API stability before committing) so the user can search by keyword ("electroplating" → 332813) and pick. The matching 4-digit SIC can be inferred from the 6-digit NAICS via a lookup table or the same API. Value: reduces data-entry errors and lowers the learning curve for first-time EHS managers. Implementation notes: same `EntitySelector`-style popup but backed by a remote API instead of a local list; cache results since these codes don't change often.

- **SDS PDF storage on Chemicals.** Every chemical on the inventory should have its Safety Data Sheet attached — it's the source of truth for the GHS flags, physical properties, and PPE already captured in the form, and OSHA 29 CFR 1910.1200(g) requires SDSs be "readily accessible" to employees. Need to add:
  - Backend: new `chemical_documents` table (or reuse a generic `attachments` table) keyed by `chemical_id`, storing `filename`, `mime_type`, `size_bytes`, `uploaded_by`, `uploaded_at`, plus the file itself. For a single-tenant desktop app like Odin, filesystem under `ODIN_DATA_DIR/chemical_sds/{chemical_id}/` is simplest; SQLite BLOB works but bloats backups.
  - Endpoints: `POST /api/chemicals/{id}/documents` (multipart upload), `GET /api/chemicals/{id}/documents` (list), `GET /api/chemicals/{id}/documents/{docId}` (stream with Content-Disposition), `DELETE /api/chemicals/{id}/documents/{docId}`. Admin-only for delete.
  - Frontend: a Documents section on Chemical detail with drop zone + list + preview link. Bonus — inline PDF viewer (embed pdf.js) so users don't have to download to read, but MVP can just open in new tab.
  - Versioning: store each new upload as a new row with `superseded_at` on the old one rather than overwriting — SDSs get revised and the history matters for OSHA recordkeeping.
  - Future tie-ins: auto-populate chemical flags from SDS text extraction (Section 2 GHS classification, Section 9 physical properties) — would save significant data entry. Could live behind a feature flag initially.

## Suggested build order

Each module is roughly one work unit (page form + wire-up + smoke test). Sub-record modals add ~0.25 unit each.

1. Phase 0 infrastructure (includes backend: search params + reactivate endpoints)
2. Establishments + Employees (parallelizable after Phase 0)
3. Users admin
4. Chemicals + Chemical Inventory modal
5. Incidents + Corrective Actions modal
6. Permits
7. Inspections + Findings modal
8. Training + Completions/Assignments modals
9. PPE + Assignments/Inspections modals
10. Waste Streams
11. (Audit log "Activity" tab, admin-only — fits anywhere after Phase 0, probably best alongside a module build so the pattern is exercised)

**Deferred:** Audits, Emission Units. See Deferred Modules section.
