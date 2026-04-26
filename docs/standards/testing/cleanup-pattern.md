# t.Cleanup over defer

Test resources (DB connections, temp dirs, file handles, server
shutdowns) register cleanup via `t.Cleanup`, never `defer`.

```go
// good
db, err := database.Open(":memory:")
if err != nil { t.Fatalf("open: %v", err) }
t.Cleanup(func() { db.Close() })

// bad
db, err := database.Open(":memory:")
if err != nil { t.Fatalf("open: %v", err) }
defer db.Close()
```

## Rules

- **Use `t.Cleanup` for any resource that needs teardown.** DB
  connections, file handles, temp dirs, started goroutines,
  bound listeners, etc.
- **Cleanup registers in order, runs in reverse.** Multiple
  `t.Cleanup` calls run in LIFO order, just like `defer`. Keep the
  registration order matching the resource-acquisition order.
- **`t.TempDir()` doesn't need explicit cleanup.** It auto-removes
  via `t.Cleanup` internally. Don't double-cleanup.
- **Subtests inherit cleanup correctly.** When `t.Run` creates a
  subtest, cleanups registered inside the subtest run before the
  parent's cleanups, automatically. `defer` doesn't compose this
  way across `t.Run`.

## Why not `defer`

- **`t.Helper`-friendly.** A test factory like `newTestEngine(t)`
  can register cleanup on the passed `*testing.T` and it works
  correctly even when called from a sub-helper. With `defer`, the
  cleanup would run at the helper's return, not the test's — too
  early.
- **Fails-after-Fatalf still cleans up.** `t.Fatalf` triggers
  cleanups; a bare `defer` after a `Fatalf` in a helper might
  never run depending on goroutine state. `t.Cleanup` is part of
  the test runtime contract.
- **Standard idiom from Go 1.14+.** Modern Go test code uses
  `t.Cleanup` exclusively for resource teardown. `defer` in tests
  reads as legacy.

## Reference

- All test harnesses in `internal/*/[*_test.go]`.
- Go testing package docs: https://pkg.go.dev/testing#T.Cleanup
