# HTTP-Level Server Tests

Server tests exercise handlers through the full request path, never
by calling handler functions directly. Use `httptest.NewRecorder` +
`srv.mux.ServeHTTP`.

```go
func TestCreateEstablishment(t *testing.T) {
    tc := newTestServerWithDB(t)

    body := `{"name": "Acme Plant", "street_address": "1 Industrial Way", ...}`
    req := httptest.NewRequest("POST", "/api/establishments", bytes.NewBufferString(body))
    tc.authRequest(req)        // attaches Bearer token
    w := httptest.NewRecorder()

    tc.srv.mux.ServeHTTP(w, req)

    if w.Code != http.StatusCreated {
        t.Fatalf("status = %d; body: %s", w.Code, w.Body.String())
    }
    var result map[string]any
    json.NewDecoder(w.Body).Decode(&result)
    // assert on response shape
}
```

## Rules

- **Always `srv.mux.ServeHTTP`, not direct handler calls.** Going
  through the mux exercises the routing pattern, the auth middleware
  in wrappers like `handleCreate` / `handleAction`, and any future
  global middleware. A test that calls `s.handleCreateX(w, r)`
  directly skips all of that and lies about coverage.
- **Use `httptest.NewRequest` + `httptest.NewRecorder`.** Stdlib
  testing primitives, no custom HTTP fakes.
- **Round-trip is the default shape.** POST + GET back, assert on the
  body of the GET. Tests both the write path and the read path against
  the SQL written, in one test, in one transaction's worth of state.
- **One auth-headed request per assertion.** Use `tc.authRequest(req)`
  to attach the test session token. Unauthenticated tests omit it
  intentionally.
- **Decode response bodies into `map[string]any` for spot-checks**
  unless the response shape is large enough to justify a typed
  struct. Tests aren't where API client structs live.

## Why HTTP-level

- **Routing matters.** `entityRoutes` / `requireAdmin` /
  `handleCreate` wrappers are real code that can break. Direct
  handler calls miss bugs in route registration, middleware order,
  and path parameter parsing.
- **Closer to user behavior.** A 200 response with the right body in
  a test gives confidence the actual `curl` or browser request would
  succeed. Direct calls don't.
- **Refactor-friendly.** When the implementation moves between files
  or middleware reshuffles, HTTP-level tests don't care — the
  contract at the URL is what matters. Direct-call tests break on
  every internal refactor.

## When direct calls are OK

- Pure helper functions (no HTTP context): `parseAlterAddColumn`,
  `splitSQLStatements`, `cellToString`, etc. Direct unit tests are
  the right shape.
- Repository / package-level functions that don't need HTTP:
  `database.LoadViews`, `osha_ita.Preview`, importer validators.

The rule is for handlers specifically: don't call a Go function
named `handleX` directly from a test.

## Reference

- `internal/server/api_test.go::newTestServerWithDB` — the harness
  every server test uses.
- Examples: `internal/server/api_write_test.go`,
  `internal/server/api_osha_ita_test.go`.
