# In-Memory Test DB Harness

Every test that touches the database uses an in-memory SQLite instance
that mirrors the production startup sequence exactly. No file-based
test DB, no shared snapshots between tests.

```go
db, err := database.Open(":memory:")
if err != nil {
    t.Fatalf("open: %v", err)
}
t.Cleanup(func() { db.Close() })

// Production-parity startup: modules → deltas → views.
sqlDir := os.DirFS("../../docs/database-design/sql")
migrations, err := database.CollectMigrations(sqlDir)
if err != nil { t.Fatalf("collect: %v", err) }
if err := database.Migrate(db, migrations); err != nil {
    t.Fatalf("migrate: %v", err)
}
deltaDir := os.DirFS("../../docs/database-design/sql/deltas")
if err := database.ApplyDeltas(db, deltaDir); err != nil {
    t.Fatalf("apply deltas: %v", err)
}
viewsDir := os.DirFS("../../docs/database-design/sql/views")
if err := database.LoadViews(db, viewsDir); err != nil {
    t.Fatalf("load views: %v", err)
}
```

## Rules

- **`:memory:`, never a file.** In-memory DBs are created fresh per
  test and disappear at cleanup. No flake from shared on-disk state,
  no leftover artifacts from prior runs.
- **Run the full startup sequence.** Migrate → ApplyDeltas →
  LoadViews. The order matches `cmd/odin/main.go` exactly. Skipping
  ApplyDeltas means tests would diverge from production behavior on
  any column added by a delta; skipping LoadViews means views never
  exist for the test.
- **One harness per package.** Each test package has its own
  `newTestX(t)` factory: `newTestEngine` (importer),
  `newTestServerWithDB` (server), `seedExportTestDB` (osha_ita).
  Don't share harnesses across packages — each handles its own
  dependencies.
- **Always `t.Cleanup(db.Close)`.** Never `defer db.Close()`. See
  `testing/cleanup-pattern.md`.

## Why production-parity in tests

Tests have caught real schema mismatches because their startup
mirrors production. The 4c view-loader incident wouldn't have
manifested in tests with file-based shared DBs that drift; with
fresh in-memory + production-parity startup, the broken view shape
shows up immediately the first time a test queries it.

## Reference

- `internal/database/database.go::Open`
- Harness examples: `internal/server/api_test.go`,
  `internal/osha_ita/exporter_test.go`,
  `internal/importer/importer_test.go`.
