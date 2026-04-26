# Inline Fixture Seeding

Each test (or test file) seeds the data it needs, inline. There is
no shared `seed-everything-for-all-tests` helper.

```go
func TestExportDetail_FiltersNonRecordableAndEmitsFullShape(t *testing.T) {
    db, estID := seedExportTestDB(t)
    // seedExportTestDB inserts ONE establishment + 3 employees + 4
    // incidents — the minimum needed for this test family. Other
    // tests in other files seed their own.
    ...
}
```

## Rules

- **No global / shared seed file.** Tests don't depend on a baseline
  set of "default rows" the harness creates. The harness creates an
  empty database; the test seeds what it needs.
- **One seed per test family is fine.** Helpers like
  `seedExportTestDB(t)` that seed a fixture used across multiple
  related tests in the same file are normal. The line is at file
  boundaries — don't import seed helpers across packages or share
  them across unrelated test families.
- **Seeds use `db.ExecParams`, not `INSERT OR IGNORE`.** If the seed
  conflicts with itself, the test environment is wrong and the test
  should fail loudly. Idempotent seeds hide setup bugs.
- **Per-test mutations stay inside the test.** A test that needs
  one incident in a specific shape inserts it inline rather than
  growing the file's shared seed. Shared fixtures stay minimal.

## Why no shared seeds

- **"What does the shared seed know about this test?"** is a question
  that compounds. Every shared row becomes implicit context every test
  must reason about. Per-test seeds make the dependency surface
  visible at the top of the test.
- **Test isolation is automatic.** When the seed lives in the test,
  there's no chance another test's seed mutation leaks in. Each
  test's `:memory:` database is fresh.
- **Refactors stay local.** Changing a column on `establishments`
  doesn't ripple through 50 test files because each test seeded its
  own minimal establishment row inline.

## Reference

- `internal/osha_ita/exporter_test.go::seedExportTestDB` — file-scoped
  helper that's used by ~6 tests in that file.
- `internal/server/api_write_test.go` — every test seeds its own
  fixture inline, no shared helper.
