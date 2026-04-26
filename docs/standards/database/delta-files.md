# Delta File Conventions

Deltas catch existing databases up to the current module-file shape.
They live in `docs/database-design/sql/deltas/` and run forward-only,
exactly once per database (tracked in `_migrations`).

## Naming

`YYYY-MM-DD-short-description.sql` — the date is the work date, not the
release date. Self-documenting: you can see when a delta was authored
without checking git history. Serial numbers (`0001-`, `0002-`) are
rejected because they break under parallel branch work.

Example: `2026-04-22-v3.3-osha-ita.sql`.

## What goes in one delta

**One logical change set per file.** A delta corresponds to a
coherent migration target — typically one feature, one phase, one
schema-shape transition. The v3.3 ITA delta landed 5 new lookup
tables + 2 mapping tables + 10 column ALTERs in one file because
they're a single atomic upgrade. Never combine unrelated changes
("add ITA columns AND rename a Module B table") in the same delta —
roll back is impossible, and a partial failure leaves the DB in
ambiguous state.

## Idempotency

Every statement must be safe to run repeatedly. Three patterns:

| Statement | Idempotent how? |
|---|---|
| `ALTER TABLE ADD COLUMN` | Runner guards via `pragma_table_info` check before issuing |
| `CREATE TABLE IF NOT EXISTS` | Native SQLite |
| `INSERT OR IGNORE INTO ...` | Native SQLite (requires natural-key PK) |
| Anything else (UPDATE, DELETE, etc.) | Author's responsibility |

The runner only auto-guards `ALTER TABLE ADD COLUMN`. For data
migrations or other statement types, write the idempotency in by hand
(e.g. `UPDATE ... WHERE col IS NULL` for one-shot backfills).

## Forward-only

No rollbacks. If a delta is wrong, fix forward with another delta —
don't try to undo via a "down" migration. SQLite's ALTER limits
(can't drop columns, can't add FKs) make true reversal impractical.

## Pair with module changes

Every additive module-file change needs a matching delta. See
`feedback_schema_deltas_convention` (memory) — without the delta,
existing databases silently miss the new content on pull + restart.

## Reference

- Runner: `internal/database/deltas.go::ApplyDeltas`
- First real delta: `docs/database-design/sql/deltas/2026-04-22-v3.3-osha-ita.sql`
