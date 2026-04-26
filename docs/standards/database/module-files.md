# Module File Conventions

A module file is the authoritative current schema for one regulatory
program or subsystem. Modules live in `docs/database-design/sql/` and
are named `module_<letter>_<topic>.sql` (e.g. `module_c_osha300.sql`,
`module_d_clean_water.sql`).

Each file contains, top-to-bottom:

1. CREATE TABLE IF NOT EXISTS for every table the module owns.
2. CREATE INDEX IF NOT EXISTS for indices on those tables.
3. INSERT OR IGNORE statements for any seed/lookup data.
4. (Optionally) banner comments grouping logical sections.

**Idempotent statements only.** Modules run exactly once per database
(tracked by filename in `_migrations`), but every statement should
still be safely re-runnable. No bare `CREATE TABLE`, no bare `INSERT`,
no `ALTER TABLE` — that's what deltas are for.

**Load order is declared in Go**, not via filename prefixes:

```go
// internal/database/migrate.go
var moduleOrder = []string{
    "module_c_osha300.sql",     // foundation — establishments + employees
    "module_training.sql",      // hazard_type_codes + work_areas
    "module_a_epcra_tri.sql",
    "module_b_title_v_caa.sql",
    // ...
}
```

Reasons for the slice over filename ordering:

- The load order is a **FK-dependency declaration**, not a
  chronological one. A 5th-added module might need to load 2nd if
  several others FK into it.
- Filenames stay readable — "Module C" is `module_c_*`, not
  `001_module_c_*`. Module letters are stable references in OSHA /
  EPA documentation.
- Co-locating the order with the runner code (`CollectMigrations`)
  keeps the dependency contract in one place.

**Always edit `moduleOrder` when adding a new module file.** Files
not present in the slice are appended alphabetically at the end —
fine if the new module has zero FK dependencies on others, broken
the moment it does. Don't rely on alphabetical luck.

**Pair every additive module change with a delta.** See
`feedback_schema_deltas_convention` (memory) and
`database/delta-files.md`. Module changes alone only reach fresh
installs; deltas catch existing DBs up.
