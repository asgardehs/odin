# Authentication Gates

Every handler that needs auth places `requireAuth` or `requireAdmin` at
the top, before any work:

```go
func (s *Server) handleSomething(w http.ResponseWriter, r *http.Request) {
    user := s.requireAdmin(w, r)
    if user == nil {
        return  // 401 / 403 already written
    }
    // proceed
}
```

Both helpers return `*auth.User` on success or `nil` after writing the
appropriate response (401 for unauthenticated, 403 for non-admin).

**Default: gated.** Anything not on the public list below MUST have a gate.

**Public (no gate, by intent):**

- All entity GET routes registered via `entityRoutes` — list + by-id
  reads are open
- Auth bootstrap: `POST /api/auth/login`, `POST /api/auth/setup`,
  `POST /api/auth/reset-password`, `POST /api/auth/recover`,
  `GET /api/auth/security-questions/{username}`,
  `GET /api/auth/whoami`
- `GET /api/health`

**Authenticated (`requireAuth`):**

- All entity mutations (POST/PUT/DELETE) — `handleCreate` /
  `handleAction` wrappers in `api_write.go` apply the gate automatically
- Audit history reads, `/api/auth/me`, `/api/auth/logout`

**Admin (`requireAdmin`):**

- User management (`/api/users/*`)
- Schema builder routes
- `/admin/import`
- OSHA ITA export routes

**Why explicit per-handler gates instead of router-level middleware?**
stdlib `net/http` has no group/middleware DSL, and the explicit-gate
pattern is one line at the top of each handler — immediately visible,
no hidden middleware to reason about, no routing-framework dependency.
When debugging "why didn't this fire?", the gate is right there.
