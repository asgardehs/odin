# Three-Layer Migration Model

Schema changes in odin go through one of three layers depending on
what's changing:

| Layer | Lives in | Tracking | Re-runs? |
|---|---|---|---|
| Modules | `sql/module_*.sql` | `_migrations` table | Once, ever |
| Deltas | `sql/deltas/YYYY-MM-DD-*.sql` | `_migrations` table | Once, ever |
| Views | `sql/views/*.sql` | None | Every startup |

**Modules** are the authoritative current schema. Read these to know
what odin's DB looks like today. CREATE TABLE IF NOT EXISTS with full
shape inline; seed data via INSERT OR IGNORE.

**Deltas** are forward-only ALTER-class statements that catch existing
DBs up to the current module shape. Used when a module file gets an
additive change (new column, new table, new seed row) after the
module has already been applied to a database — `_migrations` makes
the module a no-op on restart, so the delta is the only path that
runs against existing installs.

**Views** are derived schema. They reference tables but contain no
data of their own; rebuilding them is free. The `LoadViews` runner
DROPs and re-CREATEs every view file on every startup, so any pulled
edit to a view body propagates without a DB reset.

**Picking the layer:**

- Brand-new table → module file (with delta if existing DBs need it).
- Brand-new column on an existing table → both module file (for
  fresh installs) AND a delta (for existing DBs).
- New seed row in a lookup table → both module and delta.
- New view, or any change to an existing view body → views/ file
  only. Never put CREATE VIEW in module files; it gets stuck behind
  the `_migrations` guard and won't update.

**Why three layers instead of one ordered sequence?** Standard
numbered-migration frameworks force you to read the entire sequence
to know the current schema. The module/delta split keeps modules as
"what is" and deltas as "how to catch up" — readable separately.
Views run on a different schedule because they have no data to
preserve and their definitions evolve more often than tables. The
view extraction was incident-driven: pulled changes to view bodies
silently failed to propagate to dev DBs, and that bit during browser
testing in Phase 4c.
