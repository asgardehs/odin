# Foreign Keys & SQLite Gotchas

`PRAGMA foreign_keys=ON` is set on every connection in
`internal/database/database.go::Open`, alongside `journal_mode=WAL`,
`busy_timeout=5000`, and the rest. **This is an explicit choice, not
the SQLite default.** Out of the box SQLite leaves FKs unenforced
unless you turn them on per-connection.

The choice has consequences. Several of them have to be respected by
every layer of the migration system.

## Module load order = FK dependency order

`moduleOrder` in `internal/database/migrate.go` is the FK dependency
declaration. A module that FKs into another's table MUST load after
that table has been created.

Module C (establishments + employees + incidents) is the foundation
for almost everything else, so it loads first. Module D (Clean Water
Act) loads before `module_industrial_waste_streams.sql` because the
streams view references CWA tables.

Modify `moduleOrder` whenever you add a module that FKs into another.

## ADD COLUMN with REFERENCES is safe

Deltas frequently issue:

```sql
ALTER TABLE incidents
    ADD COLUMN treatment_facility_type_code TEXT
    REFERENCES ita_treatment_facility_types(code);
```

This works on existing tables with data because the new column is
NULL for existing rows, and **NULL satisfies any FK constraint**.
Future inserts and updates enforce the constraint normally.

Caveat: the FK target table must exist before the ALTER runs. The
delta runner handles this by ordering: tables created in the same
delta come before the ALTERs that reference them, and a delta that
needs a target from another module relies on the module having run
first (which it always has, by virtue of `_migrations` ordering).

## What SQLite ALTER cannot do

- **Add a FK to an existing column.** No `ALTER TABLE ADD CONSTRAINT
  FOREIGN KEY` syntax exists in SQLite. Workaround: recreate the
  table with the FK in the new CREATE statement, copy data over, drop
  the old. Painful enough that we haven't done it yet.
- **Drop a column.** SQLite 3.35+ supports `DROP COLUMN` but only when
  no FK / index / view references the column. Same painful workaround
  for any non-trivial drop.
- **Change a column's type or constraints.** No-go without table
  recreate.

The migration runner's `pragma_table_info` guard handles the
common-case ADD COLUMN idempotency. Anything more structural needs a
hand-rolled multi-step delta with table recreation, which we'll write
when we first need it.

## Hard rule: do not disable FKs

Some test suites in other Go projects disable FKs to ease seed data
loading. Don't do that here. Tests run against production-shape
schema; if the seed order can't satisfy FKs, the seed data is wrong.

## Reference

- Pragma config: `internal/database/database.go::Open`
- Module ordering: `internal/database/migrate.go::moduleOrder`
- ALTER guard: `internal/database/deltas.go::applyDeltaStatements`
