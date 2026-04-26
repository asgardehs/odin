# Seed Data Convention

Lookup tables (closed enumerations: severities, classifications, ITA
codes, etc.) follow a uniform shape and idempotent seed pattern.

## Table shape

```sql
CREATE TABLE IF NOT EXISTS <table> (
    code TEXT PRIMARY KEY,        -- natural key, stable, human-readable
    name TEXT NOT NULL,           -- display label
    description TEXT NOT NULL,    -- longer explanation
    -- extra per-table columns as needed:
    cfr_reference TEXT,
    is_osha_recordable INTEGER DEFAULT 0,
    ...
);

INSERT OR IGNORE INTO <table> (code, name, description, ...) VALUES
    ('FATALITY', 'Fatality', '...', ...),
    ('LOST_TIME', 'Lost Time Incident', '...', ...);
```

## Rules

- **`code TEXT PRIMARY KEY`, never `id INTEGER PRIMARY KEY AUTOINCREMENT`**
  for lookup tables. `INSERT OR IGNORE` becomes meaningful (conflict
  on natural key = "row already exists"), and FK references read as
  `severity_code = 'FATALITY'` instead of `severity_code = 4`. Pick
  stable codes — PK changes propagate to every dependent table.
- **`(code, name, description)` is the canonical 3-column contract**
  for lookups. Every `LookupDropdown` in the frontend consumes this
  shape via `/api/lookup/{table}`. Tables can carry additional
  columns for their own queries (`is_osha_recordable`, `cfr_reference`,
  `ita_csv_column`, etc.), but those are opt-in per consumer — not
  part of the lookup contract.
- **`INSERT OR IGNORE` for all seed data.** Required for idempotency:
  modules and deltas may both seed the same row; module re-runs (on
  fresh installs) must be safe. The natural-key PK makes the IGNORE
  meaningful.
- **Empty descriptions are OK.** Some lookups (e.g. `case_classifications`)
  use single-word names where a description is redundant. The lookup
  endpoint's `'' AS description` cast keeps the row shape uniform
  for the frontend regardless.
- **Don't depend on row order.** SELECT statements that consume seed
  data MUST `ORDER BY` something — typically `ORDER BY code` for
  alphabetical, but per-table ORDER BYs are fine when the natural
  read-order isn't alphabetical (`ORDER BY is_osha_recordable DESC,
  code` for severity levels).

## Anti-patterns

- ❌ `id INTEGER PRIMARY KEY AUTOINCREMENT` for a lookup table —
  loses idempotent INSERT OR IGNORE and forces opaque IDs in FKs.
- ❌ Storing per-installation data alongside seed data — seeds are
  static across all installs. Per-tenant overrides go in a separate
  table.
- ❌ Adding sort_order columns. If display order matters, the SELECT
  query handles it via ORDER BY of an existing column. Sort_order is
  cargo from frameworks that don't have proper ORDER BY.
