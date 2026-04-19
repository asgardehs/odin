# Schema Builder — Full Plan (2026-04-19)

Implements the Schema Builder described in
[`docs/odin/schema-builder`](https://asgardehs.github.io/docs/odin/schema-builder/):
runtime DDL on SQLite so admins can design their own tables, fields, and
relationships without a code deploy.

## Principles

- **Custom tables live beside pre-built modules, not on top of them.** Every
  user-defined table is prefixed `cx_`. Pre-built tables (`incidents`,
  `chemicals`, …) are never altered at runtime. If a user wants an extra
  attribute on an incident, they build a custom table and link it via a
  relation — the core domain model stays stable.
- **Metadata-driven UI.** One `GenericRecordList` + `GenericRecordForm` +
  `GenericRecordDetail` render every custom table from the metadata in
  `_custom_fields` / `_custom_relations`. No per-table React pages.
- **Additive DDL only.** New tables and new columns can be added; nothing is
  renamed, moved, or dropped at runtime. Removal is soft-delete via
  `is_active = 0` in metadata — the SQLite column/table stays. This keeps the
  audit trail coherent and avoids the usual runtime-DDL footguns.
- **Admin-only for schema; role-based for records.** Only admins can create
  tables, add fields, deactivate fields. Regular users read and write rows in
  the tables admins have built.
- **Full audit parity.** Every row mutation on a `cx_` table flows through
  `audit.Store` with `module = cx_{table_name}`. Admins see the same Activity
  section on custom-table detail pages that they do on pre-built modules.

## Cross-cutting decisions

Answered 2026-04-19 before drafting this plan.

1. **Who can build schemas?** Admin-only. Regular users read/write rows in
   the tables admins have built, but cannot alter the schema.
2. **Full-table deletion.** Soft-delete the metadata row and orphan the
   SQLite table. No `DROP TABLE` at runtime. An admin-run compaction tool
   (out of scope) can drop orphaned tables later if disk becomes a concern.
3. **Renames.** Not supported. If an admin wants a different field or table
   name, the flow is deactivate + create new. Rationale: renames invalidate
   audit history and prior export formats; forcing a new identifier keeps
   the trail readable.
4. **Audit trail on custom-table rows.** Yes — every create/update/delete on
   a `cx_*` table records an `audit.Entry` with `module = cx_{table_name}`.
   DDL changes are recorded separately in `_custom_table_versions` and also
   mirrored into the git audit log with `module = schema`.
5. **Extending pre-built tables.** Not allowed. Admins who want an extra
   attribute on, say, `incidents` build a custom table with a `relation`
   field targeting `incidents`. The pre-built schema stays frozen; custom
   tables may be single-column + relation and that's fine.
6. **Sidebar layout.** Pre-built modules stay in the main sidebar as today.
   A collapsible **"Custom Tables"** group appears below them once ≥1
   active custom table exists; hidden entirely when empty. Entries ordered
   alphabetically by display name for MVP; `display_order` column is
   reserved in metadata for pinning/reordering later.
7. **Schema import/export between establishments.** Backlog — tracked in
   `TODO.md`. Not in this plan's scope.

---

## Phase 0 — Metadata + validator + DDL executor

Backend foundation with no HTTP routes and no UI. Everything else depends
on this compiling and passing tests.

### Migrations

Four metadata tables, each with the standard `id`, `created_at`,
`updated_at` columns. All names use a leading underscore (reserved for
system tables; no collision risk with `cx_*`).

- **`_custom_tables`** — one row per custom table.
  - `name` TEXT UNIQUE NOT NULL (post-`cx_` portion, matches table regex)
  - `display_name` TEXT NOT NULL
  - `description` TEXT
  - `icon` TEXT (frontend icon key, optional)
  - `display_order` INTEGER (reserved; default 0)
  - `is_active` INTEGER DEFAULT 1
- **`_custom_fields`** — one row per field per table.
  - `custom_table_id` INTEGER NOT NULL → `_custom_tables.id`
  - `name` TEXT NOT NULL
  - `display_name` TEXT NOT NULL
  - `field_type` TEXT NOT NULL (`text`, `number`, `decimal`, `date`,
    `datetime`, `boolean`, `select`, `relation`)
  - `is_required` INTEGER DEFAULT 0
  - `default_value` TEXT
  - `config` TEXT (JSON — type-specific; see schema-builder doc)
  - `display_order` INTEGER DEFAULT 0
  - `is_active` INTEGER DEFAULT 1
  - UNIQUE(`custom_table_id`, `name`)
- **`_custom_relations`** — one row per relation between tables.
  - `source_table_id` INTEGER NOT NULL → `_custom_tables.id`
  - `source_field_id` INTEGER NOT NULL → `_custom_fields.id` (the
    `relation`-type field holding the FK value)
  - `target_table_name` TEXT NOT NULL (either `cx_foo` or a
    whitelisted pre-built table)
  - `display_field` TEXT NOT NULL (column name on the target used for the
    dropdown label)
  - `relation_type` TEXT NOT NULL (`belongs_to`, `has_many`,
    `many_to_many` — MVP: `belongs_to` only; latter two reserved)
  - `is_active` INTEGER DEFAULT 1
- **`_custom_table_versions`** — DDL history.
  - `custom_table_id` INTEGER NOT NULL
  - `change_type` TEXT NOT NULL (`create_table`, `add_field`,
    `deactivate_field`, `add_relation`, `deactivate_relation`,
    `deactivate_table`)
  - `change_payload` TEXT NOT NULL (JSON describing the change)
  - `changed_by` TEXT NOT NULL (admin username)
  - `changed_at` DATETIME DEFAULT current_timestamp

### Validator (`internal/schemabuilder/validator.go`)

- Table name regex: `^[a-z][a-z0-9_]{1,58}$` — stored without the `cx_`
  prefix in metadata, prefix is applied at DDL time.
- Field name regex: `^[a-z][a-z0-9_]{1,62}$`.
- Reserved field names (auto-added, cannot be user-defined):
  `id`, `establishment_id`, `created_at`, `updated_at`.
- Table name must not collide with any pre-built table (hardcoded list
  from `internal/database/migrations`) or any existing `cx_*` table.
- Field type must be one of the eight known types.
- Relation `target_table_name` must be a `cx_*` that exists OR one of the
  whitelisted pre-built targets: `establishments`, `employees`,
  `incidents`, `chemicals`, `training_courses`, `training_completions`,
  `storage_locations`, `work_areas`.
- `display_field` on relations must be a real column on the target table
  (enforced at write time by introspecting the target's metadata or
  pre-built schema map).

### DDL executor (`internal/schemabuilder/executor.go`)

- `CreateTable(m CustomTableInput) (int64, error)` — insert metadata rows,
  then execute `CREATE TABLE cx_{name} (id INTEGER PRIMARY KEY,
  establishment_id INTEGER, created_at DATETIME DEFAULT current_timestamp,
  updated_at DATETIME DEFAULT current_timestamp)` + index on
  `establishment_id`.
- `AddField(tableID int64, f CustomFieldInput) (int64, error)` — insert
  metadata row, then `ALTER TABLE cx_{name} ADD COLUMN {field} {sqlite_type}`.
  SQLite type picked from the field-type table in the schema-builder doc.
- `DeactivateField(fieldID int64)` — metadata only (`is_active = 0`).
  Column remains.
- `AddRelation(r CustomRelationInput) (int64, error)` — insert metadata
  row; no DDL (the FK column already exists from `AddField` for the
  `relation`-type field). Target existence + display_field validated.
- `DeactivateTable(tableID int64)` — metadata only.
- Every DDL action records a row in `_custom_table_versions` inside the
  same transaction.
- Transactional: metadata write + DDL must both succeed or both roll
  back. SQLite DDL is transactional so this is straightforward.

### Query builder (`internal/schemabuilder/query.go`)

Safe parameterized queries for custom tables. Column names are validated
against metadata (never user input → SQL) and interpolated as literals;
all values are bound parameters.

```go
func (qb *QueryBuilder) Select(tableID int64, opts SelectOpts) (sql string, args []any, err error)
func (qb *QueryBuilder) Insert(tableID int64, values map[string]any) (sql string, args []any, err error)
func (qb *QueryBuilder) Update(tableID int64, id int64, values map[string]any) (sql string, args []any, err error)
func (qb *QueryBuilder) Delete(tableID int64, id int64) (sql string, args []any, err error)
```

- `SelectOpts` carries paging, search (full-text on `text`-type fields),
  filter by `establishment_id`, and optional JOINs for relations so the
  list can display the relation's `display_field` instead of the raw id.
- `Insert`/`Update` filter unknown keys; the caller cannot sneak
  columns that aren't in metadata.

### Tests

- Validator: happy path per field type; reserved-word rejection;
  collision rejection; regex rejection; relation target validation.
- Executor: create table → verify SQLite table exists with auto-cols;
  add field → verify ALTER ran; deactivate field → verify metadata
  flipped, column still present; version rows written.
- Query builder: injection attempt in column name rejected; JOIN
  generated correctly for a relation; pagination args.

---

## Phase 1 — Schema management API + record CRUD + audit hook

HTTP routes exposing Phase 0. All schema routes admin-only; record routes
follow existing role rules (read = any authed, write = non-readonly,
destructive = admin).

### Schema routes (admin-only)

- `POST   /api/schema/tables`
- `GET    /api/schema/tables`
- `GET    /api/schema/tables/{id}`                     (includes fields + relations)
- `POST   /api/schema/tables/{id}/deactivate`
- `POST   /api/schema/tables/{id}/fields`
- `POST   /api/schema/tables/{id}/fields/{fid}/deactivate`
- `POST   /api/schema/tables/{id}/relations`
- `POST   /api/schema/tables/{id}/relations/{rid}/deactivate`
- `GET    /api/schema/tables/{id}/versions`             (history)

### Record routes

Generic over any active `cx_*` table, keyed by metadata id or slug.

- `GET    /api/records/{tableSlug}`           (list, search, paginate)
- `GET    /api/records/{tableSlug}/{id}`
- `POST   /api/records/{tableSlug}`
- `PUT    /api/records/{tableSlug}/{id}`
- `DELETE /api/records/{tableSlug}/{id}`

Slug is the table name without the `cx_` prefix; resolves to a
`customTable` at request time. Unknown or inactive slug → 404.

### Audit integration

- Every successful `POST`/`PUT`/`DELETE` on a record route records an
  `audit.Entry` with `module = cx_{name}`, `entity_id = {id}`, and a
  before/after diff (same as pre-built modules).
- Every successful schema mutation records an `audit.Entry` with
  `module = schema`, `entity_id = {custom_table_id}`, and
  `summary` describing the DDL change (mirrors the
  `_custom_table_versions` row so the git trail stays authoritative).

### Tests

- End-to-end via `httptest`: create table → add field → add row →
  fetch row → update → delete. Verify audit entries at each step.
- Non-admin hits a schema route → 403.
- Inactive table → list + get return 404.
- Row delete on inactive table → 404 (can't mutate orphaned data
  through the public API; compaction tool is a separate story).

---

## Phase 2 — Generic RecordList + RecordForm + RecordDetail

One set of React components that render any custom table from its
metadata. Reuses the Phase 0 primitives from the data-entry phase
(`FormField`, `EntitySelector`, `Modal`, `SectionCard`, etc.).

### Components

- **`<GenericRecordList tableSlug>`** — mirrors the pre-built list pages:
  header with title + "+ New" + search input, table with columns
  driven by metadata (first 5 active fields, plus relation
  `display_field` for any `relation` field), pagination.
- **`<GenericRecordForm tableSlug recordId?>`** — iterates active
  fields in `display_order` and emits the right `<FormField>` per
  `field_type`. Relation fields use `<EntitySelector>` with `entity`
  set to the target table's API slug. Required indicators, unsaved
  guard, Save / Save-and-new / Cancel.
- **`<GenericRecordDetail tableSlug recordId>`** — one `<Section>`
  grouping all active fields (custom tables don't have natural sub-
  sections the way pre-built modules do). Below it: the standard
  "Record" section with created/updated and the admin-only
  `<AuditHistory module="cx_{name}" entityId={id}>` block already
  shipped in the previous phase.

### Routes

- `/custom/{tableSlug}`            — list
- `/custom/{tableSlug}/new`        — create
- `/custom/{tableSlug}/:id`        — detail
- `/custom/{tableSlug}/:id/edit`   — edit

Route params don't need per-table registration; a single set of
components matches `/custom/:slug/*`.

### Tests

Smoke only in Phase 2 — exercise in Phase 4 once the full flow is
wired end-to-end.

---

## Phase 3 — Table Designer UI

Admin-only. The workspace where custom tables are built.

### Pages

- **`/admin/schema`** — list of all custom tables (active + inactive),
  with inline status and a "+ New table" button. Inactive tables show
  a "Reactivate" button (flips `is_active = 1` on the metadata row;
  SQLite table is unchanged so data is still there).
- **`/admin/schema/new`** — table metadata form (display name → derives
  `name` as `snake_case`, editable; description; icon picker).
- **`/admin/schema/:id`** — the designer. Left panel: fields list with
  drag-to-reorder, inline required toggle, inline deactivate. Right
  panel: live preview of `<GenericRecordForm>` rendered from the
  current in-flight metadata. Below: relations panel (source field,
  target table dropdown, display field).

### Components

- **`<FieldEditor>`** — modal or inline drawer for configuring a field.
  Renders a type-specific config editor (select options list, min/max
  for numeric, `multiline` toggle for text, target-table picker for
  relation).
- **`<SchemaDiffConfirm>`** — on Save, compares the current designer
  state to the last-saved server state and shows the admin exactly
  which fields are being added and which are being deactivated before
  committing. Irreversible actions get called out; adds are grouped
  separately from deactivations.
- **`<VersionHistory tableId>`** — collapsible list of prior DDL
  changes from `_custom_table_versions` (lower half of the designer).

### Tests

Component tests where useful (diff rendering, field-type config
editors). Most of the confidence comes from the Phase 4 smoke test.

---

## Phase 4 — Sidebar integration + polish + smoke test

### Sidebar

- **`<CustomTablesGroup>`** in `Shell.tsx`. Fetches
  `GET /api/schema/tables?active=1` once on mount; renders a
  collapsible group under the pre-built modules. Entries ordered by
  `display_name`. Hidden entirely when the list is empty.
- When an admin deactivates a table from the designer, the sidebar
  refetches.

### Polish

- Schema-builder strings in an errors map (consistent 400/403/404 text
  matching the rest of the app).
- Empty-state illustration on `/admin/schema` ("No custom tables yet —
  start with + New table") and on `/custom/{slug}` when a table has
  no rows.
- Designer: warn before navigating away with unsaved field changes
  (reuse `useUnsavedGuard`).

### Smoke test

Manual, end-to-end, as admin:

1. Create a custom table `equipment_checkouts` with fields: `item_name`
   (text, required), `returned_by` (relation → `employees`),
   `checkout_date` (date), `notes` (text, multiline).
2. Verify it appears under Custom Tables in the sidebar.
3. Add a row. Verify the `returned_by` dropdown lists employees and
   stores the id.
4. Open the detail page. Expand the Activity section — should show the
   `create` entry on `cx_equipment_checkouts`.
5. Edit the row. Verify an `update` entry appears with a before/after
   diff.
6. Back in the designer, deactivate the `notes` field. Confirm the
   diff preview. Save.
7. Reload the custom-table list. Field is gone from the UI; SQLite
   column is still there (verify via `sqlite3` on the DB).
8. Deactivate the whole table. Verify it disappears from the sidebar
   and that `/custom/equipment_checkouts` returns 404.
9. Reactivate from `/admin/schema`. Verify the sidebar entry returns
   and that previously-entered rows are still readable.

Only mark the phase shipped when all 9 steps pass.

---

## Suggested build order

Each phase is self-contained. Phases 0 and 1 are backend-heavy; 2 and
3 are frontend-heavy; 4 ties it all together. Roughly one work unit
per phase for the backend phases, ~1.5–2 units for Phase 3.

1. **Phase 0** — metadata + validator + executor + query builder
2. **Phase 1** — API routes + audit hook
3. **Phase 2** — generic record UI (list / form / detail)
4. **Phase 3** — Table Designer UI
5. **Phase 4** — sidebar + polish + smoke

## Out of scope

- Schema import/export between establishments (tracked in `TODO.md`)
- Rename of tables or fields (explicit decision — see cross-cutting)
- `many_to_many` and `has_many` relation types (metadata reserves them;
  MVP ships `belongs_to` only)
- Background data migration when a field is deactivated (data stays;
  compaction is a future tool)
- Admin-set `display_order` / pinning on the sidebar (column reserved,
  UI deferred)
