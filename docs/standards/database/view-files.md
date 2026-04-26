# View File Conventions

All SQL views live in `docs/database-design/sql/views/*.sql` and are
re-executed on every odin startup via `internal/database/views.go::LoadViews`.

## Layout

One file per feature/topic. Multiple views per file is fine when
they share a domain — e.g. `views/osha_ita.sql` holds both
`v_osha_ita_detail` and `v_osha_ita_summary` because they're two
shapes of the same export.

## Required pattern

Every view definition follows this exact shape:

```sql
DROP VIEW IF EXISTS v_my_view;
CREATE VIEW v_my_view AS
SELECT ...
FROM ...;
```

DROP + CREATE makes re-execution idempotent. The runner doesn't track
view files in `_migrations`; every file is re-run on every startup.
That's the whole point — view body changes propagate to existing dev
DBs on restart, no nuke-and-resplat needed.

## Naming

- View identifiers: `v_<topic>` prefix to make them obvious in
  pragma output and SELECT statements (e.g. `v_osha_ita_detail`).
- File names: descriptive of the topic (`osha_ita.sql`,
  `audit_summary.sql`). No date prefix; views aren't time-ordered.

## Hard rule: never put CREATE VIEW in a module file

Module files are tracked in `_migrations` and run exactly once per DB.
A CREATE VIEW landing inside a module gets frozen at that database's
first apply — subsequent edits to the view body silently fail to
propagate. This bit during Phase 4c testing and is what drove the
view-extraction work.

If you find a CREATE VIEW in a `module_*.sql` file, move it to
`sql/views/<topic>.sql` and remove it from the module.

## What can views contain

Anything pure-derived: SELECT, JOIN, aggregations, CASE expressions,
strftime/datetime computations, COALESCE for null-defaults. No DML.
Views are read-only by design.

If a view's logic gets gnarly, lean toward materialization (a real
table populated by a delta) rather than a complex view — but only
when the perf cost of computing-on-read becomes a problem. Default
to a view.
