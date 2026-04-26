# Test Auth Stubs

Real auth in odin uses PAM + sessions. Tests bypass this with stub
implementations that always succeed.

```go
type mockAuth struct{ user string }

func (m *mockAuth) Verify(_, _ string) error { return nil }
// satisfies the auth.Authenticator interface

// inside newTestServerWithDB:
a := &mockAuth{user: "testuser"}
auditStore, _ := audit.NewStore(t.TempDir(), a)
userStore := auth.NewUserStore(db)
userID, _ := userStore.Create(auth.UserInput{
    Username: "testuser", Password: "testpass", Role: "admin",
})
sessionStore := auth.NewSessionStore(db, 24*time.Hour)
token, _ := sessionStore.Create(userID, "127.0.0.1")
```

## Rules

- **One stub per test package.** `mockAuth` lives in
  `internal/server/api_test.go`; `stubAuth` lives in
  `internal/importer/importer_test.go`. They aren't shared because
  each package has its own `Authenticator`-shaped interface needs.
- **Stubs always succeed.** Tests don't exercise the auth verification
  flow itself — that lives in `internal/auth/auth_test.go` against a
  real PAM stack mock. Other packages assume auth works and focus on
  their own logic.
- **Real `UserStore` and `SessionStore`.** Even with a stub
  authenticator, tests use the production user / session stores
  against the in-memory DB. Token generation, expiry handling, role
  flags — all real. Only the credential-verification step is stubbed.
- **Default test user is admin.** Tests that need to verify
  non-admin behavior create a second user with `Role: "user"` and
  use that token. See `nonAdminToken` helper in
  `api_osha_ita_test.go`.

## Why stub auth

- **PAM doesn't run in CI.** Tests can't assume the host has PAM
  configured for odin, the test user, or any password backend.
- **Auth flow has its own test surface.** `internal/auth/` is the
  one place that exercises real Authenticator behavior. Other
  packages just need "a request is authenticated" to be a true
  predicate.
- **Stubs let tests focus.** A server test for `POST /api/incidents`
  shouldn't fail because the test user's PAM session expired mid-run.

## Reference

- `internal/server/api_test.go::mockAuth`
- `internal/importer/importer_test.go::stubAuth`
- `internal/auth/auth.go::Authenticator` interface
