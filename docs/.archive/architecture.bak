---
title: 'Odin Architecture'
created: 2026-04-03
status: draft
---

# Odin Architecture

_The all-seeing overseer — compliance management for manufacturing._

## Overview

Odin is a desktop compliance/EHS application built with Wails v2, targeting
small manufacturing facilities that carry the same regulatory burden as large
enterprises but lack the IT budget for enterprise ERP modules. It ships as a
single binary per platform with an embedded SQLite database, requiring no server
infrastructure, no cloud account, and no IT department.

### Technical Stack

| Layer        | Technology                   |
| ------------ | ---------------------------- |
| Framework    | Wails v2.12.0                |
| Backend      | Go                           |
| Frontend     | Svelte + Tailwind CSS + Vite |
| Database     | SQLite (go-sqlite3, CGo)     |
| Distribution | Single binary via `go:embed` |

### MVP Modules

| Module          | Regulatory Coverage                                             |
| --------------- | --------------------------------------------------------------- |
| Incidents       | OSHA 300, 300A, 301                                             |
| Chemicals / SDS | OSHA HazCom, EPA Tier II (EPCRA 311/312), SARA 313/TRI          |
| Training        | Multi-regulatory (HazCom, Forklift, LOTO, Confined Space, etc.) |
| Schema Builder  | User-defined tables, fields, and relationships                  |

### Ecosystem

Odin is part of the Asgard ecosystem. The MVP is fully standalone, but the
architecture defines integration contracts for future connection via Bifrost:

| Tool    | Role                               | Integration                                       |
| ------- | ---------------------------------- | ------------------------------------------------- |
| Muninn  | Knowledge base + semantic search   | Odin serves as Muninn's web GUI                   |
| Huginn  | Markdown-to-PDF generator          | Odin sends compliance reports for PDF rendering   |
| Bifrost | Discovery daemon + Heimdall config | Odin registers as a service, reads unified config |

---

## 1. Project Structure

```
odin/
├── main.go                          # Wails entry, service wiring, options.App
├── app.go                           # App struct, OnStartup/OnShutdown hooks
├── go.mod / go.sum
├── wails.json                       # Wails project config
├── build/                           # Platform build assets (icons, manifests)
│
├── internal/
│   ├── database/
│   │   ├── db.go                    # DB wrapper: Open, Close, WAL, foreign keys
│   │   ├── migrate.go               # Migration runner with schema_version tracking
│   │   └── seed.go                  # Reference data seeding
│   │
│   ├── module/
│   │   ├── incidents/
│   │   │   ├── repository.go        # SQL queries
│   │   │   ├── service.go           # Business logic, case numbers, recordability
│   │   │   ├── models.go            # Incident, CorrectiveAction, OSHA300ASummary
│   │   │   ├── reports.go           # OSHA 300/300A/301 data assembly
│   │   │   └── schema.sql           # Module migration SQL (embedded)
│   │   │
│   │   ├── chemicals/
│   │   │   ├── repository.go
│   │   │   ├── service.go           # Tier II calcs, unit conversion
│   │   │   ├── models.go            # Chemical, SDSDocument, Inventory
│   │   │   ├── sara313.go           # Threshold calcs, Form A eligibility
│   │   │   ├── reports.go           # Tier II, TRI Form R/A data assembly
│   │   │   └── schema.sql
│   │   │
│   │   ├── training/
│   │   │   ├── repository.go
│   │   │   ├── service.go           # Requirement determination, expiration
│   │   │   ├── models.go            # Course, Completion, Assignment, GapResult
│   │   │   ├── reports.go           # Training matrix, gap analysis
│   │   │   └── schema.sql
│   │   │
│   │   └── registry.go             # Module registry: enabled modules per establishment
│   │
│   ├── schema/                      # Schema Builder engine
│   │   ├── meta.go                  # TableDef, FieldDef, RelationDef types
│   │   ├── repository.go           # CRUD for metadata tables
│   │   ├── executor.go             # DDL: CREATE TABLE, ALTER TABLE from metadata
│   │   ├── validator.go            # Name rules, type checking, FK integrity
│   │   ├── query.go                # Dynamic parameterized query builder
│   │   ├── service.go              # Orchestrates metadata + DDL + validation
│   │   └── schema.sql              # Schema Builder's own migration SQL
│   │
│   ├── audit/
│   │   ├── logger.go               # Records changes to audit_log
│   │   └── models.go               # AuditEntry
│   │
│   ├── establishment/
│   │   ├── repository.go           # Establishment + Employee CRUD
│   │   ├── service.go              # Facility switching
│   │   └── models.go
│   │
│   ├── report/
│   │   ├── engine.go               # Runs named queries, returns tabular data
│   │   ├── registry.go             # Maps report names to SQL views/queries
│   │   ├── export.go               # CSV, JSON export
│   │   └── models.go               # ReportDefinition, ReportResult
│   │
│   ├── integration/
│   │   ├── bifrost.go              # Registration, health, config read
│   │   ├── muninn.go               # Search, note CRUD, index requests
│   │   ├── huginn.go               # PDF render requests
│   │   └── discovery.go            # Detect installed ecosystem tools
│   │
│   └── platform/
│       ├── paths.go                # XDG / platform-specific data paths
│       └── backup.go               # DB backup to timestamped files
│
├── bindings/                        # Wails-bound structs (thin wrappers)
│   ├── app.go                       # Lifecycle, settings, establishment switching
│   ├── incidents.go                 # Wraps incidents.Service
│   ├── chemicals.go                 # Wraps chemicals.Service
│   ├── training.go                  # Wraps training.Service
│   ├── schema.go                    # Wraps schema.Service
│   ├── reports.go                   # Wraps report.Engine
│   └── integration.go              # Ecosystem tool status and actions
│
├── frontend/
│   ├── index.html
│   ├── package.json
│   ├── vite.config.ts
│   ├── svelte.config.js
│   ├── tailwind.config.js
│   ├── tsconfig.json
│   │
│   ├── src/
│   │   ├── main.ts                  # Svelte mount
│   │   ├── App.svelte               # Root: router + layout shell
│   │   ├── app.css                  # Tailwind base + custom tokens
│   │   │
│   │   ├── lib/
│   │   │   ├── api.ts               # Typed wrappers around wailsjs bindings
│   │   │   ├── events.ts            # Wails EventsOn/EventsEmit helpers
│   │   │   ├── stores/
│   │   │   │   ├── establishment.ts # Current establishment (writable)
│   │   │   │   ├── settings.ts      # App settings
│   │   │   │   └── modules.ts       # Enabled modules for current establishment
│   │   │   ├── types.ts             # Re-exports from wailsjs/go/models
│   │   │   └── utils.ts             # Date formatting, validation
│   │   │
│   │   ├── components/
│   │   │   ├── layout/
│   │   │   │   ├── Shell.svelte         # Sidebar + topbar + content area
│   │   │   │   ├── Sidebar.svelte       # Module nav, establishment selector
│   │   │   │   └── Topbar.svelte        # Breadcrumbs, search, notifications
│   │   │   │
│   │   │   ├── shared/
│   │   │   │   ├── DataTable.svelte     # Sortable, filterable, paginated
│   │   │   │   ├── FormField.svelte     # Label + input + error
│   │   │   │   ├── FormBuilder.svelte   # Renders forms from field definitions
│   │   │   │   ├── Modal.svelte
│   │   │   │   ├── ConfirmDialog.svelte
│   │   │   │   ├── StatusBadge.svelte
│   │   │   │   ├── DatePicker.svelte
│   │   │   │   ├── SearchInput.svelte
│   │   │   │   ├── Pagination.svelte
│   │   │   │   ├── Toast.svelte
│   │   │   │   └── EmptyState.svelte
│   │   │   │
│   │   │   └── reports/
│   │   │       ├── ReportViewer.svelte
│   │   │       └── ReportSelector.svelte
│   │   │
│   │   ├── pages/
│   │   │   ├── Dashboard.svelte
│   │   │   ├── Setup.svelte             # First-run wizard
│   │   │   ├── incidents/               # List, Detail, Form, OSHA300
│   │   │   ├── chemicals/              # List, Detail, Form, SDS, Inventory, TierII
│   │   │   ├── training/               # Matrix, Courses, Completion, GapAnalysis
│   │   │   ├── schema/                 # TableList, TableDesigner, RecordList, RecordForm
│   │   │   ├── employees/              # List, Detail, Form
│   │   │   ├── reports/                # Report browser and runner
│   │   │   ├── knowledge/              # Muninn GUI (when available)
│   │   │   └── settings/               # Settings, IntegrationStatus
│   │   │
│   │   └── router.ts                   # Client-side hash router
│   │
│   └── wailsjs/                        # Auto-generated by Wails
│       ├── go/bindings/                # TS stubs for each binding struct
│       └── runtime/
│
├── docs/
│   ├── architecture.md                 # This document
│   └── database-design/               # Existing schema docs and SQL
│
└── embed/
    └── migrations/                     # Embedded SQL migration files
        ├── 000_core.sql               # establishments, employees, settings, audit_log
        ├── 001_incidents.sql
        ├── 002_chemicals.sql
        ├── 002a_sara313.sql
        ├── 003_training.sql
        └── 100_schema_builder.sql
```

### Structural Decisions

**`internal/` vs `bindings/`**: All domain logic lives in `internal/`
(unexportable). The `bindings/` package contains thin Wails-bound structs whose
only job is to translate between the frontend calling convention and the
internal service layer. This keeps services testable without Wails and lets
binding methods handle Wails-specific concerns (context propagation, error
formatting) without polluting domain code.

**Module-per-directory**: Each compliance module under `internal/module/` is
self-contained with its own repository, service, models, reports, and migration
SQL. Adding a future module (waste, inspections, permits) means adding a new
directory and registering it — no existing code changes.

**`bindings/` is not under `internal/`**: Wails requires bound structs to be
accessible from `main.go`. Placing them at the project root level keeps them
importable while clearly separate from business logic.

---

## 2. Go Backend Architecture

### 2.1 Layer Responsibilities

```
┌──────────────────────────────────────────────────────────┐
│                    Wails Runtime                          │
│           (JS method calls → Go dispatch via IPC)        │
├──────────────────────────────────────────────────────────┤
│                   bindings/ layer                         │
│  Thin structs bound to Wails. One per UI concern.        │
│  Validates input shape. Calls service. Formats response.  │
├──────────────────────────────────────────────────────────┤
│                   service layer                           │
│  internal/module/*/service.go                             │
│  internal/schema/service.go                               │
│  Business rules, cross-module coordination, audit calls.  │
├──────────────────────────────────────────────────────────┤
│                  repository layer                         │
│  internal/module/*/repository.go                          │
│  Raw SQL queries. No business logic. Returns models.      │
├──────────────────────────────────────────────────────────┤
│                  database layer                           │
│  internal/database/db.go                                  │
│  Connection pool, WAL mode, migrations, embed.FS.         │
├──────────────────────────────────────────────────────────┤
│                     SQLite                                 │
└──────────────────────────────────────────────────────────┘
```

### 2.2 Database Access: Raw SQL

Following Muninn's pattern, Odin uses raw SQL via `database/sql` with
`github.com/mattn/go-sqlite3`. No ORM, no query builder for pre-built modules.

Reasons:

1. The existing schemas have 132 tables with complex views, triggers, and
   regulatory-specific queries. An ORM would fight these.
2. Compliance reporting queries (OSHA 300A summation, Tier II threshold
   calculation, training gap analysis) are view-based SQL that maps poorly to
   ORM patterns.
3. Consistency with Muninn and Huginn.

The one exception is the Schema Builder's dynamic queries (section 3), which
require a query builder since table structure is unknown at compile time.

**Connection setup** (mirrors Muninn's `internal/store/db.go`):

```go
// internal/database/db.go

type DB struct {
    *sql.DB
}

func Open(path string) (*DB, error) {
    dsn := fmt.Sprintf(
        "file:%s?_journal_mode=WAL&_foreign_keys=ON&_busy_timeout=5000&_synchronous=NORMAL",
        path,
    )
    db, err := sql.Open("sqlite3", dsn)
    if err != nil {
        return nil, err
    }
    db.SetMaxOpenConns(1)  // SQLite write serialization
    return &DB{db}, nil
}
```

WAL mode is essential — it allows the frontend to read while the backend writes,
which matters for a desktop app where the user browses data while background
tasks (audit logging, report generation) write.

### 2.3 Migration Strategy

Ordered migrations with version tracking, adapted for Odin's modular structure:

```go
// internal/database/migrate.go

type Migration struct {
    Version     int
    Module      string    // "core", "incidents", "chemicals", "training", "schema_builder"
    Description string
    SQL         string    // loaded from embed.FS
}
```

Migration files are embedded from `embed/migrations/*.sql`. The runner:

1. Creates `schema_version` table if absent
2. Runs each unexecuted migration in order within a transaction
3. Records version + module on success
4. Runs seed data (reference tables) after structural migrations

Ordering: core (000) runs first — establishes `establishments`, `employees`,
`settings`, `audit_log`. Then modules by number. Schema Builder (100) runs last.

```go
//go:embed all:embed/migrations
var migrations embed.FS
```

### 2.4 Wails Binding Pattern

Each binding struct receives services via constructor injection in `main.go`:

```go
// bindings/incidents.go

type IncidentBinding struct {
    svc *incidents.Service
}

func NewIncidentBinding(svc *incidents.Service) *IncidentBinding {
    return &IncidentBinding{svc: svc}
}

// Public methods become JS-callable
func (b *IncidentBinding) List(establishmentID int64, filter incidents.ListFilter) ([]incidents.Incident, error) {
    return b.svc.List(establishmentID, filter)
}

func (b *IncidentBinding) Get(id int64) (*incidents.Incident, error) {
    return b.svc.Get(id)
}

func (b *IncidentBinding) Create(input incidents.CreateInput) (*incidents.Incident, error) {
    return b.svc.Create(input)
}
```

Wiring in `main.go`:

```go
func main() {
    db := database.MustOpen(dbPath)
    database.Migrate(db, migrations)

    // Services
    auditLog  := audit.NewLogger(db)
    estSvc    := establishment.NewService(db)
    incSvc    := incidents.NewService(db, auditLog)
    chemSvc   := chemicals.NewService(db, auditLog)
    trainSvc  := training.NewService(db, auditLog)
    schemaSvc := schema.NewService(db, auditLog)
    reportEng := report.NewEngine(db)

    // Bindings (thin wrappers)
    app := bindings.NewAppBinding(db, estSvc)

    wails.Run(&options.App{
        Title:  "Odin",
        Width:  1280,
        Height: 800,
        OnStartup:  app.Startup,
        OnShutdown: app.Shutdown,
        Bind: []interface{}{
            app,
            bindings.NewIncidentBinding(incSvc),
            bindings.NewChemicalBinding(chemSvc),
            bindings.NewTrainingBinding(trainSvc),
            bindings.NewSchemaBinding(schemaSvc),
            bindings.NewReportBinding(reportEng),
            bindings.NewIntegrationBinding(),
        },
        AssetServer: &assetserver.Options{Assets: frontend},
    })
}
```

Frontend calls become:

```typescript
import { IncidentBinding } from '../wailsjs/go/bindings';
const incidents = await IncidentBinding.List(establishmentId, {
  status: 'open',
});
```

### 2.5 Audit Logging

Every service that modifies data takes an `audit.Logger`:

```go
// internal/audit/logger.go

type Logger struct {
    db *database.DB
}

func (l *Logger) Log(table string, recordID int64, action string, oldVals, newVals map[string]any, changedBy string) error
```

Called from the service layer, not the repository. The service decides what
constitutes an auditable action. For Schema Builder custom tables, the schema
service calls the audit logger with the custom table name.

### 2.6 Error Handling

The service layer uses typed errors:

```go
var (
    ErrNotFound      = errors.New("not found")
    ErrDuplicateCase = errors.New("case number already exists")
    ErrInvalidInput  = errors.New("invalid input")
)
```

Wails translates Go errors into rejected JS promises. The frontend wraps all
binding calls in try/catch and surfaces errors via `Toast.svelte`. The binding
layer can inspect typed errors to return structured responses that the frontend
can act on (e.g., highlighting the field that caused `ErrInvalidInput`).

---

## 3. Schema Builder Architecture

The Schema Builder lets users design their own database tables, fields, and
relationships from scratch. It supports runtime DDL on SQLite while maintaining
safety, auditability, and interoperability with pre-built modules.

### 3.1 Metadata Model

Three metadata tables describe user-defined schemas:

```sql
-- embed/migrations/100_schema_builder.sql

CREATE TABLE IF NOT EXISTS _custom_tables (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    table_name       TEXT NOT NULL,            -- internal: "cx_" prefix enforced
    display_name     TEXT NOT NULL,            -- user-facing name
    description      TEXT,
    icon             TEXT,                     -- icon identifier for sidebar
    sort_order       INTEGER DEFAULT 0,
    is_active        INTEGER DEFAULT 1,
    created_at       TEXT DEFAULT (datetime('now')),
    updated_at       TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, table_name)
);

CREATE TABLE IF NOT EXISTS _custom_fields (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    table_id      INTEGER NOT NULL,
    field_name    TEXT NOT NULL,               -- SQLite column name
    display_name  TEXT NOT NULL,               -- user-facing label
    field_type    TEXT NOT NULL,               -- see type mapping below
    is_required   INTEGER DEFAULT 0,
    default_value TEXT,                        -- stored as text, cast at query time
    sort_order    INTEGER DEFAULT 0,
    config        TEXT,                        -- JSON, type-specific (see below)
    is_active     INTEGER DEFAULT 1,
    created_at    TEXT DEFAULT (datetime('now')),
    updated_at    TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (table_id) REFERENCES _custom_tables(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS _custom_relations (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    source_table_id      INTEGER NOT NULL,
    target_table_id      INTEGER,              -- FK to _custom_tables (NULL if built-in target)
    target_builtin       TEXT,                 -- name of pre-built table if target_table_id is NULL
    relation_type        TEXT NOT NULL,         -- belongs_to, has_many, many_to_many
    foreign_key_field_id INTEGER,              -- which _custom_fields column holds the FK
    junction_table       TEXT,                 -- for many_to_many: auto-created cx_*_jn table
    display_name         TEXT,
    created_at           TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (source_table_id) REFERENCES _custom_tables(id) ON DELETE CASCADE,
    FOREIGN KEY (target_table_id) REFERENCES _custom_tables(id),
    FOREIGN KEY (foreign_key_field_id) REFERENCES _custom_fields(id)
);

CREATE TABLE IF NOT EXISTS _custom_table_versions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    table_id     INTEGER NOT NULL,
    version      INTEGER NOT NULL,
    change_type  TEXT NOT NULL,                -- create_table, add_field, deactivate_field, rename_field
    change_detail TEXT,                        -- JSON describing the change
    applied_at   TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (table_id) REFERENCES _custom_tables(id)
);
```

### 3.2 Field Type Mapping

| Schema Builder Type | SQLite Type | `config` JSON Examples                                     |
| ------------------- | ----------- | ---------------------------------------------------------- |
| `text`              | TEXT        | `{"multiline": true, "max_length": 500}`                   |
| `number`            | INTEGER     | `{"min": 0, "max": 100}`                                   |
| `decimal`           | REAL        | `{"precision": 2}`                                         |
| `date`              | TEXT        | — (stored as YYYY-MM-DD)                                   |
| `datetime`          | TEXT        | — (stored as ISO 8601)                                     |
| `boolean`           | INTEGER     | — (0/1)                                                    |
| `select`            | TEXT        | `{"options": ["Low", "Medium", "High"]}`                   |
| `relation`          | INTEGER     | `{"target_table": "cx_projects", "display_field": "name"}` |

### 3.3 Naming Convention and Safety

All user-created SQLite tables get the `cx_` prefix (custom). This prevents
collisions with pre-built module tables.

The `validator.go` enforces:

- Table names: `^[a-z][a-z0-9_]{1,58}$` (after `cx_` prefix, max 63 chars)
- Field names: `^[a-z][a-z0-9_]{1,62}$`
- Reserved names blacklist: `id`, `establishment_id`, `created_at`, `updated_at`
  (auto-added to every custom table)
- Cannot use pre-built table names
- Relation targets must exist (either in `_custom_tables` or in the whitelisted
  pre-built table list)

### 3.4 DDL Execution

The `executor.go` translates metadata into DDL:

**Table creation:**

```sql
CREATE TABLE cx_<name> (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    -- user-defined fields --
    created_at       TEXT DEFAULT (datetime('now')),
    updated_at       TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);
CREATE INDEX idx_cx_<name>_est ON cx_<name>(establishment_id);
```

**Field addition:**

```sql
ALTER TABLE cx_<name> ADD COLUMN <field_name> <sqlite_type>;
```

**Field deactivation:** Setting `is_active = 0` in metadata hides the field from
the UI and query builder. The SQLite column remains. A separate "compact"
operation can rebuild the table if explicitly requested.

**Field removal (compact):** SQLite 3.35.0+ supports
`ALTER TABLE ... DROP COLUMN`. Since `go-sqlite3` bundles a recent SQLite, this
is available but only invoked during explicit compaction, not during normal
field deactivation.

### 3.5 Dynamic Query Builder

The `query.go` provides safe, parameterized queries for custom tables. Column
names (validated against metadata) are interpolated; all data values are
parameterized:

```go
// internal/schema/query.go

type QueryBuilder struct {
    meta *Repository
}

func (qb *QueryBuilder) Select(tableID int64, opts SelectOpts) (string, []any, error)
func (qb *QueryBuilder) Insert(tableID int64, values map[string]any) (string, []any, error)
func (qb *QueryBuilder) Update(tableID int64, id int64, values map[string]any) (string, []any, error)
func (qb *QueryBuilder) Delete(tableID int64, id int64) (string, []any, error)

type SelectOpts struct {
    EstablishmentID int64
    Filters         []Filter     // {FieldName, Operator, Value}
    SortField       string
    SortDir         string       // ASC, DESC
    Limit           int
    Offset          int
}
```

### 3.6 Interoperability with Pre-Built Modules

Custom tables can have `relation` type fields pointing to whitelisted pre-built
tables:

- `establishments` (implicit via `establishment_id`)
- `employees`
- `incidents`
- `chemicals`
- `training_courses`
- `training_completions`
- `storage_locations`
- `work_areas`

When a relation field targets a pre-built table, the query builder generates
appropriate JOINs for display, and `RecordForm.svelte` renders a searchable
dropdown populated from the target table.

Custom tables can also relate to other custom tables. The Table Designer UI
shows both custom and whitelisted pre-built tables as valid relation targets.

### 3.7 Schema Versioning

Every DDL change is recorded in `_custom_table_versions`, providing a migration
history for custom tables. This enables future features like undo, export, and
schema sharing between establishments.

---

## 4. Frontend Architecture

### 4.1 Routing

Client-side hash router (no server-side routing in a Wails app). A lightweight
router like `svelte-spa-router` keeps dependencies minimal.

```
#/                              → Dashboard
#/setup                         → First-run wizard

#/incidents                     → IncidentList
#/incidents/:id                 → IncidentDetail
#/incidents/new                 → IncidentForm (create)
#/incidents/:id/edit            → IncidentForm (edit)
#/incidents/osha300             → OSHA 300 log view

#/chemicals                     → ChemicalList
#/chemicals/:id                 → ChemicalDetail
#/chemicals/new                 → ChemicalForm
#/chemicals/:id/edit            → ChemicalForm
#/chemicals/sds                 → SDSManager
#/chemicals/inventory           → InventorySnapshot
#/chemicals/tier2               → Tier II report

#/training                      → TrainingMatrix
#/training/courses              → CourseList
#/training/courses/new          → CourseForm
#/training/courses/:id/edit     → CourseForm
#/training/record               → CompletionForm
#/training/gaps                 → GapAnalysis

#/schema                        → TableList (custom tables)
#/schema/new                    → TableDesigner (create)
#/schema/:tableId/design        → TableDesigner (edit)
#/schema/:tableId               → RecordList (dynamic)
#/schema/:tableId/new           → RecordForm (dynamic, create)
#/schema/:tableId/:recordId     → RecordForm (dynamic, edit)

#/employees                     → EmployeeList
#/employees/:id                 → EmployeeDetail
#/employees/new                 → EmployeeForm

#/reports                       → Report browser
#/knowledge                     → Muninn NoteList (when available)
#/settings                      → Settings
#/settings/integrations         → IntegrationStatus
```

### 4.2 State Management

Svelte stores (writable/derived) for global state. No external library needed.

**`establishment.ts`** — the most critical store. Nearly every API call filters
by establishment. Changing it triggers refetches across visible components:

```typescript
// frontend/src/lib/stores/establishment.ts
import { writable, derived } from 'svelte/store';

export const establishments = writable<Establishment[]>([]);
export const currentEstablishmentId = writable<number>(0);
export const currentEstablishment = derived(
  [establishments, currentEstablishmentId],
  ([$all, $id]) => $all.find((e) => e.id === $id) ?? null,
);
```

**`modules.ts`** — tracks which modules are enabled for the current
establishment (controls sidebar rendering and route guards).

Page-level state stays in page components. List pages own
filter/sort/pagination. Detail pages fetch on mount from route params. Forms own
draft state.

### 4.3 Shared Component Patterns

All pre-built modules follow the same **List → Detail → Form** pattern:

**List pages:** `DataTable.svelte` with module-specific column definitions and
filters. DataTable handles sorting, column visibility, and row click navigation.
Each module's list page provides column config and a fetch function.

**Detail pages:** Read-only single record view with related data sections.
Action buttons for edit, delete, status transitions.

**Form pages:** Built with `FormField.svelte` components. Static forms (fields
known at compile time). Validation in Svelte (immediate feedback) and Go service
layer (authoritative).

**Schema Builder forms:** `RecordForm.svelte` is the dynamic counterpart. It
reads field definitions from Schema Builder metadata and renders appropriate
input components based on `field_type`. Uses the same `FormField.svelte`
primitives but composes them at runtime.

### 4.4 Table Designer UI

`TableDesigner.svelte` is the Schema Builder's power interface:

1. **Table metadata panel** — display name, description, icon selection
2. **Fields list** — drag-to-reorder. Each row shows name, type, required flag,
   expand button for config
3. **Field editor** — display name, type dropdown, required toggle, default
   value, type-specific options (select choices, relation target, number
   min/max, text multiline)
4. **Relations panel** — existing relations and add button. Picks source field,
   target table, relation type
5. **Preview panel** — live preview of the record form based on current field
   definitions
6. **Save** — sends full table definition to `SchemaBinding.SaveTable()`, which
   diffs against current state and executes necessary DDL

---

## 5. Data Flow

### 5.1 Standard CRUD Flow (example: create incident)

```
User fills IncidentForm.svelte
  → form validates locally (required fields, date formats)
  → calls IncidentBinding.Create(input) via wailsjs stub
  → Go: IncidentBinding.Create() validates input shape
  → Go: incidents.Service.Create() applies business rules:
      → generates case number (YYYY-NNN)
      → determines is_recordable from classification
      → calls incidents.Repository.Insert()
  → Go: incidents.Repository.Insert() executes parameterized INSERT
  → Go: audit.Logger.Log("incidents", newID, "INSERT", nil, newValues, "user")
  → returns *Incident to binding → JS
  → Svelte navigates to IncidentDetail
  → Wails EventsEmit("incident:created", id)
  → Dashboard (if visible) refreshes counts via EventsOn
```

### 5.2 Schema Builder Flow (create custom table)

```
User fills TableDesigner.svelte
  → defines table name, fields, relations
  → calls SchemaBinding.SaveTable(definition)
  → Go: schema.Service.CreateTable():
      1. validator.ValidateTableDef(def)
      2. schema.Repository.InsertTableMeta(def) → writes _custom_tables, _custom_fields
      3. schema.Executor.CreateTable(def) → executes CREATE TABLE cx_<name>
      4. schema.Repository.InsertVersion(tableID, 1, "create_table", details)
      5. audit.Logger.Log("_custom_tables", tableID, "INSERT", ...)
  → returns TableDef to binding → JS
  → Svelte navigates to RecordList for new table
  → Sidebar re-renders with new custom table entry
```

### 5.3 Event System

Wails events handle cross-component notifications. Events carry minimal payloads
(IDs and action types). Receiving components refetch from bindings.

**Go → JS events:**

- `establishment:changed` — current facility switched
- `module:data-changed` — `{module: "incidents", action: "create", id: 123}`
- `integration:status-changed` — ecosystem tool availability changed
- `backup:completed` — after automatic backup

**JS → Go events:** Generally not needed (frontend calls bindings directly).
Exception: `app:before-close` for confirming unsaved changes.

---

## 6. Multi-Establishment Support

### 6.1 Data Isolation

Every table with user data has `establishment_id INTEGER NOT NULL`. This is the
existing pattern across all 132 tables. Custom tables created by the Schema
Builder get `establishment_id` automatically.

The repository layer always requires `establishment_id` as a parameter. There is
no "current establishment" at the repository level — that concept lives in the
frontend store and is passed through binding calls.

### 6.2 UI Handling

`Sidebar.svelte` contains `EstablishmentPicker` at the top. Changing it:

1. Updates the `currentEstablishmentId` store
2. Persists to `settings` table (`current_establishment_id`)
3. Every visible page refetches via store subscription

The Dashboard shows the current establishment. Cross-establishment views (e.g.,
all overdue training) are available as reports, not as default navigation.

### 6.3 Establishment-Scoped Custom Tables

Custom table definitions in `_custom_tables` are scoped to `establishment_id`.
Two establishments can each define a table named "Projects" — they share the
SQLite table `cx_projects` but data is filtered by `establishment_id`, matching
the pre-built module pattern.

---

## 7. Reporting Pipeline

### 7.1 Report Registry

Reports are named queries mapping to existing SQL views or parameterized SQL:

```go
// internal/report/registry.go

type ReportDefinition struct {
    ID          string        // "osha_300_log"
    Name        string        // "OSHA 300 Log"
    Module      string        // "incidents"
    Description string
    Parameters  []ReportParam // user-provided (year, date range)
    Columns     []ColumnDef   // name, display name, type, format
    QuerySource string        // SQL view name or inline query
}
```

### 7.2 Pre-Built Reports

Mapped from existing SQL views:

| Report                         | Source View                        | Module    |
| ------------------------------ | ---------------------------------- | --------- |
| OSHA 300 Log                   | Parameterized query (by year)      | incidents |
| OSHA 300A Summary              | `osha_300a_summaries` table        | incidents |
| Current Chemical Inventory     | `v_current_inventory`              | chemicals |
| Tier II Reportable Chemicals   | `v_tier2_reportable`               | chemicals |
| SDS Review Status              | `v_sds_review_status`              | chemicals |
| TRI Reportable Chemicals       | `v_tri_reportable_chemicals`       | chemicals |
| Training Gap Analysis          | `v_training_gap_analysis`          | training  |
| Employee Training Requirements | `v_employee_required_requirements` | training  |

### 7.3 Report Execution

```go
type Engine struct {
    db       *database.DB
    registry map[string]ReportDefinition
}

func (e *Engine) Run(reportID string, estID int64, params map[string]any) (*ReportResult, error)

type ReportResult struct {
    Definition ReportDefinition
    Columns    []string
    Rows       [][]any
    Generated  time.Time
}
```

### 7.4 Export Formats

**CSV:** The report engine serializes `ReportResult` directly. Pure Go.

**PDF via Huginn:** The report engine builds a markdown document from
`ReportResult` using Huginn's input format (markdown tables + YAML frontmatter),
then sends it to Huginn over IPC. If Huginn is unavailable, the PDF export
button is disabled with an explanation.

**OSHA forms:** OSHA 300/300A/301 have specific layouts. The incidents
`reports.go` assembles data in the exact form structure, and Huginn renders it
using custom components (the `facility-header` component already exists in
Huginn's PoC).

### 7.5 Schema Builder Reports

Custom tables are reportable via the same engine:

```go
func (e *Engine) RunCustom(tableID int64, estID int64, opts SelectOpts) (*ReportResult, error)
```

Uses the Schema Builder's `QueryBuilder` to generate SQL, wraps in
`ReportResult`, rendered by the same `ReportViewer.svelte`.

---

## 8. First-Run Experience

When Odin starts and the database has no `current_establishment_id` in
`settings`, the app routes to `#/setup`.

### Wizard Steps

**Step 1: Welcome**

- Brief intro to Odin
- Detect ecosystem tools (Muninn, Huginn, Bifrost)
- Show integration status

**Step 2: Create Establishment**

- Company/facility name (required)
- Address fields (required for OSHA)
- NAICS code (optional, auto-suggest)
- Industry description

**Step 3: Choose Modules**

- Checkboxes: Incidents (OSHA), Chemicals/SDS (HazCom/Tier II), Training
- Each shows a one-line description of regulatory coverage
- At least one module required
- Schema Builder always available (not a module toggle)

**Step 4: Quick Start (optional)**

- Import employees from CSV
- "Add your first chemical" shortcut
- Schema Builder tutorial prompt

**Step 5: Done**

- Navigate to Dashboard
- Sidebar shows selected modules

Module enablement stored in:

```sql
CREATE TABLE IF NOT EXISTS module_config (
    establishment_id INTEGER NOT NULL,
    module_name      TEXT NOT NULL,
    is_enabled       INTEGER DEFAULT 1,
    enabled_at       TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (establishment_id, module_name),
    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);
```

---

## 9. Integration Surface Area

The MVP is standalone. These contracts are defined now so the architecture
supports ecosystem integration from day one.

### 9.1 Odin ↔ Bifrost

Odin registers with Bifrost on startup if its socket is available at a
well-known path (`$XDG_RUNTIME_DIR/bifrost.sock`).

**Registration payload:**

```json
{
  "service": "odin",
  "version": "0.1.0",
  "capabilities": [
    "compliance",
    "incidents",
    "chemicals",
    "training",
    "schema_builder",
    "reports"
  ],
  "endpoints": {
    "health": "/health",
    "search": "/search",
    "reports": "/reports"
  },
  "pid": 12345
}
```

**Config from Heimdall:** On startup, Odin checks Heimdall for:

- `odin.database_path` — override default DB location
- `odin.backup_path` — override backup directory
- `odin.theme` — UI theme preference
- `muninn.vault_path` — where Muninn's notes live
- `huginn.socket_path` — where to send PDF requests

If Bifrost/Heimdall is unavailable, Odin falls back to its own `settings` table
and platform-specific defaults.

### 9.2 Odin → Muninn (Odin as Muninn's GUI)

When Muninn is detected (via Bifrost or by checking PATH), Odin enables the
Knowledge section in the sidebar.

| Operation   | Method                                             |
| ----------- | -------------------------------------------------- |
| List notes  | `muninn note list --json` or socket call           |
| Get note    | `muninn note get <path> --json`                    |
| Create note | `muninn note create --title "..." --content "..."` |
| Search      | `muninn search --query "..." --json`               |
| Reindex     | `muninn note index`                                |

Until Bifrost exists, Odin shells out to the `muninn` CLI with `--json`.

### 9.3 Muninn → Odin (Muninn indexes Odin's data)

Odin exposes a local endpoint that Muninn can query:

```
GET /api/search?q=<query>&module=incidents&establishment_id=1
```

Returns JSON compliance records. Muninn indexes these as external sources
alongside its own notes and snippets.

### 9.4 Odin → Huginn (PDF generation)

```json
{
    "template": "osha_300",
    "theme": "odin_compliance",
    "data": {
        "establishment": { "..." },
        "year": 2025,
        "incidents": [ "..." ]
    },
    "output_path": "/tmp/osha300_2025.pdf"
}
```

Odin pre-formats compliance data into Huginn's markdown+component format. Output
goes to a temp directory; Odin presents a native save dialog.

If Huginn is unavailable, PDF buttons show "Requires Huginn" and offer CSV.

### 9.5 Protocol Contract

All inter-tool communication:

- **Transport:** Unix domain socket (primary) or localhost HTTP (fallback)
- **Format:** JSON-RPC 2.0 (aligns with MCP/LSP patterns in Muninn)
- **Discovery:** Bifrost registry, or well-known socket paths
- **Auth:** None (local-only, same-user, same-machine)

---

## 10. Build and Distribution

### 10.1 Build Process

```bash
wails build -platform linux/amd64
wails build -platform windows/amd64
wails build -platform darwin/universal
```

This:

1. Runs `npm run build` in `frontend/` (Vite builds Svelte)
2. Embeds built assets via `go:embed`
3. Compiles Go binary with CGo (required for go-sqlite3)
4. Produces a single native executable

### 10.2 Asset Embedding

```go
//go:embed all:frontend/dist
var frontend embed.FS

//go:embed all:embed/migrations
var migrations embed.FS
```

### 10.3 Database File Location

Platform-specific defaults:

| Platform | Path                                                 |
| -------- | ---------------------------------------------------- |
| Linux    | `$XDG_DATA_HOME/odin/odin.db` (~/.local/share/odin/) |
| macOS    | `~/Library/Application Support/odin/odin.db`         |
| Windows  | `%APPDATA%\odin\odin.db`                             |

Overridable via Heimdall config or command-line flag.

### 10.4 Platform Considerations

- **Linux:** Requires `libwebkit2gtk-4.0-dev` at build time, `libwebkit2gtk-4.0`
  at runtime. Potential AppImage/Flatpak packaging.
- **macOS:** Uses WKWebView (system-provided). No extra dependencies. Universal
  binary (amd64 + arm64).
- **Windows:** Uses WebView2 (Edge Chromium). Included in Windows 10/11 by
  default. Installer bundles WebView2 bootstrapper for older systems.

### 10.5 CI Pipeline (future)

GitHub Actions per platform:

- Linux runner → Linux binary
- macOS runner → universal macOS binary
- Windows runner → Windows exe
- All run `go test ./...` before build
- Release artifacts on GitHub Releases

---

## 11. Architecture Decision Records

### ADR-1: Wails v2, not v3

Wails v3 is in alpha. V2.12.0 is stable and documented. The architecture
isolates Wails-specific code to `main.go` and `bindings/`, so a v2→v3 migration
affects only those files.

### ADR-2: Raw SQL, not ORM

132 tables with complex views, triggers, and regulatory queries. An ORM would
fight these. Raw SQL keeps queries readable and maps directly to the existing
schema design. Consistency with Muninn and Huginn.

### ADR-3: Schema Builder uses metadata tables, not raw DDL recording

Metadata tables enable:

- UI generation (frontend needs field types, display names to render forms)
- Validation before DDL execution
- Generic report engine queries over custom tables
- Schema versioning and future undo/export

DDL replay would be fragile across SQLite versions.

### ADR-4: Single SQLite database, not per-module

All data in one `odin.db`:

- Foreign keys work across modules (incidents → employees, training → chemicals)
- Custom tables can relate to any pre-built table
- Unified audit log
- Simpler backup (one file)
- WAL handles concurrent reads

### ADR-5: `cx_` prefix for custom tables

SQLite has no schema namespacing. The `cx_` prefix is simple, visible in any
SQLite browser, and queryable
(`SELECT name FROM sqlite_master WHERE name LIKE 'cx_%'`).

### ADR-6: Corrective actions consolidation (deferred)

The existing schemas have two corrective action systems: `corrective_actions`
(tied to incidents in 001) and the CAR system (in 005). For MVP, incidents use
the existing `corrective_actions` table. When inspections/audits module ships
post-MVP, consolidate into a unified table with polymorphic source:

```sql
-- Future unified corrective_actions
source_type TEXT NOT NULL,   -- 'incident', 'audit', 'inspection', 'custom'
source_id   INTEGER NOT NULL,
```

Documented now, deferred to avoid MVP scope creep.
