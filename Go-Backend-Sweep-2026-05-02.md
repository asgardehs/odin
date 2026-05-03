# Go Backend Sweep — 2026-05-02

Master list of Go backend findings (`cmd/` + `internal/`). Issues are grouped by
severity, then numbered for stable reference. Each entry is self-contained:
file, what's wrong, why it matters, and the proposed fix.

## Validation

- Ran: `go test -tags ratatoskr_embed ./...` — pass.
- Note: test discovery includes `frontend/node_modules/...` Go package (tooling
  noise; see L-2).

## Summary

| Severity       | Count | Items                                                                                                                                                      |
| -------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| High           | 4     | H-1 recovery role escalation · H-2 ignored auth errors · H-3 `readBody` truncation · H-4 savepoint windows don't hold DB mutex                             |
| Medium         | 3     | M-1 importer commit status update outside savepoint · M-2 orphaned savepoint after rollback · M-3 validation errors returned as 500                        |
| Low            | 4     | L-1 `handleLogout` ignores delete error · L-2 `node_modules` in Go test traversal · L-3 string-formatted session expiry · L-4 silent audit-record failures |
| Note           | 1     | N-1 per-IP rate limiter is per-process for desktop usage                                                                                                   |
| Verified clean | 3     | V-1 schema builder dynamic SQL · V-2 import upload `Filename` storage · V-3 `handleAction` silent unmarshal (intentional)                                  |

---

## High

### H-1 — Recovery flow can elevate non-admin users to admin

- **File:** `internal/server/api_auth.go` (`handleRecover`, lines 458–461)
- **Details:** Recovery path mutates target account role to `admin`
  unconditionally.
- **Why it matters:** Anyone with the recovery key can elevate any non-admin
  account, expanding blast radius beyond intended emergency reset behavior.
  Severity capped at High because exploitation already requires possession of
  the physical recovery key.
- **Fix:** Remove the role mutation. Reject the recovery target unless it is
  already an admin. Add a regression test covering recovery on a non-admin user.

### H-2 — Ignored errors in security-sensitive state transitions

- **File:** `internal/server/api_auth.go`
- **Details:**
  - `handleRecover` ignores returns from `s.users.Update(...)`,
    `s.users.Reactivate(...)`, `s.sessions.DeleteForUser(...)`.
  - `handleDeactivateUser` ignores `s.sessions.DeleteForUser(id)`.
- **Why it matters:** Partial failures (e.g. deactivation succeeds but session
  revocation fails) leave the account/session state inconsistent while the API
  returns success.
- **Fix:** Check and propagate each error (5xx + structured body for internal
  failures). Add tests covering the failure paths.

### H-3 — `readBody` truncates request bodies to a single Read()

- **File:** `internal/server/api_write.go` (lines ~840–848)
- **Details:**
  ```go
  func readBody(r *http.Request) ([]byte, error) {
      defer r.Body.Close()
      var buf [1 << 20]byte // 1MB max
      n, err := r.Body.Read(buf[:])
      if err != nil && err.Error() != "EOF" {
          return nil, err
      }
      return buf[:n], nil
  }
  ```
  Three problems compounding:
  - `r.Body.Read` is **not** guaranteed to fill the buffer in one call. For
    chunked-transfer or slow-network requests the first Read can return only the
    first chunk, leaving the rest unread. JSON unmarshal then fails on truncated
    input — surfaced to the user as a generic "invalid request body" 400.
  - Error compared by string (`err.Error() != "EOF"`) instead of
    `errors.Is(err, io.EOF)`.
  - Silent truncation at 1MB rather than a 413/400; a 2MB body just gets cut.
- **Why it matters:** Used by every write/update/delete/action handler in
  `api_write.go` (40+ endpoints). Manifests as flaky "invalid body" errors that
  depend on chunking and network conditions — the kind of bug that's hard to
  reproduce locally but bites in deployment.
- **Fix:**
  ```go
  func readBody(r *http.Request) ([]byte, error) {
      defer r.Body.Close()
      return io.ReadAll(http.MaxBytesReader(nil, r.Body, 1<<20))
  }
  ```
  Surface `*http.MaxBytesError` as 413 in the callers, not 400.

### H-4 — Savepoint windows don't hold the DB mutex

- **Files:** `internal/importer/engine.go` (`Engine.Commit`);
  `internal/schemabuilder/executor.go` (`withSavepoint` and every caller —
  `CreateTable`, `AddField`, `AddRelation`, `Deactivate*`, etc.).
- **Connection model (resolved):** `database.DB` is single-connection with a
  process-wide mutex (`internal/database/database.go:24-28`). Each `Exec` /
  `ExecParams` acquires `mu`, runs, releases. All ops are on the same SQLite
  connection, so the savepoint design is real — not illusory.
- **However:** Neither `Engine.Commit` nor `schemabuilder.withSavepoint` holds
  `db.Lock()` across the `SAVEPOINT…RELEASE` span. The mutex is released between
  every Exec, so a concurrent goroutine (another HTTP handler, the
  session-cleanup ticker) can acquire `mu` mid-savepoint and run its own writes
  — which get **captured by the open savepoint on the same connection**.
- **Failure mode:** If the savepoint rolls back (e.g. importer hits a bad row),
  unrelated concurrent writes that landed during the window also roll back.
  Session deletes, audit entries, other handlers' inserts — silently lost.
- **Confirming evidence:** The `Lock`/`Unlock` contract is explicitly documented
  at `internal/database/database.go:30-33` ("callers that need to run multiple
  DB ops as a unit … hold the DB mutex across the whole sequence") — but the
  very callers it was written for don't use it.
- **Fix:** Expose
  `db.WithTx(fn func(tx *TxHandle) error) error` on `database.DB` that holds the
  mutex for the whole callback and passes unlocked primitives (`tx.Exec`,
  `tx.QueryRow`, `tx.ExecParams`) to the callback. Migrate
  `schemabuilder.withSavepoint` to use it and remove the ad-hoc
  SAVEPOINT/RELEASE sequencing; rewrite `Engine.Commit` against the same
  primitive. This solves re-entrancy structurally instead of duplicating every
  Exec method. (Design originally captured in `TODO.md` under "Proper
  transaction isolation for the DB mutex"; that bullet should come out of TODO
  once this lands here.)
- **Note on practical risk:** Single-user desktop usage makes the
  concurrent-writer scenario rare, but `SessionStore.StartCleanupLoop` runs
  every 15 minutes and could land mid-import. Real but small. The fix is
  structural, not tactical.

---

## Medium

### M-1 — Importer commit: status update outside savepoint

- **File:** `internal/importer/engine.go` (`Engine.Commit`, lines ~216–258)
- **Details:** Sequence is `SAVEPOINT import_commit` → insert rows →
  `RELEASE import_commit` → `UPDATE _imports SET status = 'committed'`. The
  status update runs **after** the savepoint releases, so rows are durable but
  the token stays flagged `pending` if the UPDATE fails.
- **Failure mode:** A retried `Commit(token, …)` passes the
  `state.Status != "pending"` guard and re-inserts every row → **duplicate
  data**.
- **Fix:** Move the `UPDATE _imports … status = 'committed'` inside the
  savepoint, before `RELEASE`. Either the whole commit succeeds atomically or it
  rolls back as a unit.

### M-2 — Importer commit: orphaned savepoint after rollback

- **File:** `internal/importer/engine.go` (line ~234)
- **Details:** On per-row insert failure, the code issues
  `ROLLBACK TO import_commit` and returns. SQLite's `ROLLBACK TO` unwinds work
  but **leaves the savepoint (and its implicit transaction) active**. Subsequent
  operations on the same connection run inside the lingering transaction.
- **Comparison:** `schemabuilder.withSavepoint` already does this correctly — it
  issues both `ROLLBACK TO` and `RELEASE` after a failed body. The importer just
  needs the same pattern.
- **Fix:** After rollback, also issue `_ = e.DB.Exec("RELEASE import_commit")`
  to fully close out the savepoint.

### M-3 — Validation errors returned as 500, leaking raw error messages

- **File:** `internal/server/api_write.go` (`handleCreate`, `handleUpdate`,
  `handleDelete`, `handleAction`)
- **Details:** Every write handler maps `fn(...) error` failures to
  `writeError(w, err.Error(), http.StatusInternalServerError)`. Repository
  validation errors ("name is required", "establishment_id must be set") are
  user input problems and should be 400, not 500. Worse, `err.Error()` is
  returned to the client verbatim — wrapped errors from deeper layers can
  include SQL fragments or internal context that shouldn't leave the server.
- **Fix:**
  - Define a sentinel/typed validation error in `repository` (e.g.
    `repository.ValidationError`) and have handlers map it to 400.
  - Return a generic "internal error" body for non-validation errors and log the
    wrapped error server-side instead of leaking it.

---

## Low

### L-1 — `handleLogout` ignores session delete error (best-effort)

- **File:** `internal/server/api_auth.go`
- **Details:** Self-logout path ignores `s.sessions.Delete(token)` error.
- **Why it matters:** Low risk — token still expires on schedule. Primarily an
  observability gap.
- **Fix:** Keep best-effort behavior; add a warning log on delete failure.

### L-2 — Go test traversal includes frontend `node_modules`

- **Evidence:** test output includes
  `github.com/asgardehs/odin/frontend/node_modules/flatted/golang/pkg/flatted`.
- **Why it matters:** Noisy CI output and accidental coupling to frontend
  dependency contents.
- **Fix:** Filter package list in test targets, e.g.
  `go test -tags ratatoskr_embed $(go list ./... | grep -v frontend/node_modules)`.

### L-3 — Session expiry stored as formatted strings

- **File:** `internal/auth/session.go`
- **Details:** `expires_at` values and comparisons use `time.DateTime` strings
  in UTC. Lexicographically sortable and correct today; SQLite has no native
  datetime so strings are idiomatic.
- **Gotcha:** Fragile if the format ever drifts or callers compare with a
  different layout.
- **Fix (optional hardening):** Migrate `expires_at` to `INTEGER` unix epoch and
  compare numerically. Defer unless something else forces a session-table
  migration.

### L-4 — Audit recording failures are silently discarded

- **Files:**
  - `internal/importer/engine.go:262` (`_ = e.Audit.Record(...)`)
  - `internal/server/api_osha_ita.go:133` (`_ = s.audit.Record(...)`)
  - `internal/server/api_schema.go:640, 658` (`_ = s.audit.Record(...)`)
- **Note:** `internal/repository/repository.go:41` correctly propagates the
  audit error — the inconsistency itself is worth fixing.
- **Why it matters:** For an EHS compliance app, a missing audit row on a
  successful import or schema mutation is a real gap, not a cosmetic one.
- **Fix:** At minimum log the audit error. Stronger: treat audit failure as
  making the originating operation fail (or at least flag it).

---

## Note (informational, no fix planned)

### N-1 — Per-IP rate limiter is effectively per-process for desktop usage

- **File:** `internal/server/ratelimit.go`
- **Details:** Token bucket keyed on client IP. For a single-user desktop app
  served on `127.0.0.1`, every request shares one bucket — fine for that
  deployment model. If Odin is ever exposed on a network for multi-user pilots,
  a single user can lock everyone else out of `/api/auth/login`,
  `/api/auth/reset-password`, and `/api/auth/recover` (5 burst, 12s refill).
- **Action:** None for current scope; flag for any future multi-user move.

---

## Verified clean (no action — documented so reviewers don't re-litigate)

### V-1 — Schema builder dynamic SQL is safe

- **Files:** `internal/schemabuilder/validator.go`, `query.go`, `executor.go`.
- **Verification:** SQL injection surface in `cx_*` table operations checked
  end-to-end:
  - Table/field names validated by `tableNameRegex` / `fieldNameRegex`
    (`^[a-z][a-z0-9_]{1,X}$`) **before** any DDL runs.
  - Field names cross-checked against `ReservedFieldNames`.
  - Relation targets restricted to `cx_*` (validated origin) or
    `IsAllowedRelationTarget` whitelist; `display_field` verified to exist via
    `PRAGMA table_info` introspection.
  - `quoteIdent` provides belt-and-braces double-quote escaping on every
    identifier interpolation.
  - The one PRAGMA that interpolates a table name (`columnExists`) is correctly
    defended — name must already exist in `sqlite_master`.

### V-2 — Import upload `Filename` storage is safe

- **Files:** `internal/server/api_import.go`,
  `internal/importer/engine.go:140-145`.
- **Verification:** Multipart `header.Filename` is passed through to
  `Engine.Upload` / `Engine.UploadParsed` and stored via parameterized insert
  into `_imports.original_filename`. No SQL injection surface. Tempfile naming
  uses `os.CreateTemp` (random suffix), and the only filename-derived input is
  the suffix from `xlsxSuffix`, which only ever returns `.xlsx`, `.xls`, or the
  default — no path-traversal vector. Frontend rendering of `original_filename`
  is out of scope for this backend sweep.

### V-3 — `handleAction` silent unmarshal is intentional

- **File:** `internal/server/api_write.go` (`handleAction`, line 827)
- **Verification:** `body, _ := readBody(r) // body is optional for actions`
  documents the design — action endpoints (`/close`, `/complete`, `/verify`, …)
  accept an optional body and proceed with zero-value request structs when
  absent or malformed. The inner `json.Unmarshal(body, &req)` calls follow that
  contract. Worth a one-line comment cluster on the inner closures for clarity,
  but not a bug.

---

## Documentation Targets (WHY-comments worth writing)

The repo has many un-commented functions, but most are self-documenting CRUD
where a comment would add noise. The list below is the small set where a
one-line **WHY** would actually prevent a future reader from getting it wrong.

| Location                                                                                                                                                         | Why it needs a comment                                                                                                                                                                                                                               |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `internal/database/database.go:35` — `Unlock`                                                                                                                    | The name implies a lock release, but this is the public mutex API for callers needing transactional scope (savepoint + multiple Execs). Context — and the Lock/Unlock contract — is hidden in the `DB` type comment; pull it onto the method itself. |
| `internal/server/api_auth.go` — `handleRecover`                                                                                                                  | Document the threat model assumption: recovery requires possession of the physical recovery key; explain why role is or isn't mutated post-fix.                                                                                                      |
| `internal/server/api_auth.go` — admin handlers (`handleCreateUser`, `handleUpdateUser`, `handleDeactivateUser`, `handleReactivateUser`, `handleSetUserPassword`) | Each has an authorization model (admin-only) and side-effect set (e.g. `handleDeactivateUser` revokes sessions). One line on what the side effects are.                                                                                              |
| `internal/schemabuilder/executor.go` — `flipTableActive`, `loadTable`, `recordVersion`                                                                           | Each has a non-obvious invariant. `recordVersion` writes the audit row inside the same savepoint as the DDL — that's the whole point and isn't visible from the call site.                                                                           |
| `internal/schemabuilder/query.go` — `joinIdents`, `placeholders`                                                                                                 | These are the SQL-safety boundary. A one-line "callers MUST validate identifiers before calling — quoting is belt-and-braces" mirrors the `quoteIdent` comment and makes the contract explicit at the helpers too.                                   |
| `internal/server/api.go` — `writeError`, `handleDashboardCounts`                                                                                                 | `writeError` is the canonical error path; document the response shape (so frontend contract is greppable). `handleDashboardCounts` runs aggregations that may evolve — name the data sources.                                                        |
| `internal/server/api_write.go` — `parseID`, `readBody` (post-H-3 fix)                                                                                            | After the H-3 fix, `readBody` will have a documented size cap and error semantics worth surfacing. `parseID` is trivial enough to skip.                                                                                                              |
| `internal/server/api_write.go` — `handleAction` inner closures                                                                                                   | Per V-3: a one-line comment that "body is optional, malformed body is treated as empty" makes the silent-unmarshal pattern explicit.                                                                                                                 |
| `internal/importer/engine.go` — `Engine.Commit` (post-H-4/M-1/M-2 fixes)                                                                                         | After the savepoint fixes, document the transactional contract: what holds the lock, what's atomic, what the failure modes are.                                                                                                                      |

**Explicitly NOT on the list:** `internal/repository/*` CRUD methods
(`CreateChemical`, `UpdateChemical`, `DeleteChemical`, etc.). These are
self-documenting and adding `// CreateChemical creates a chemical.` is noise
that rots and dilutes signal. If a specific method has a non-obvious invariant
(e.g. `DiscontinueChemical` cascades to inventory rows), document that one — but
skip the rest.

---

## Recommended Execution Order

1. **H-1, H-2** — auth/security correctness. Smallest blast radius, highest
   leverage.
2. **H-3** — `readBody` rewrite. Single-helper change that lifts a correctness
   floor under 40+ endpoints.
3. **M-1, M-2** — importer commit fixes. Local to one function; H-4 work will
   likely touch the same file so sequence them together.
4. **H-4** — savepoint mutex fix. Structural; pair with the M-1/M-2 work in
   `Engine.Commit` and propagate the same pattern to
   `schemabuilder.withSavepoint`.
5. **M-3** — validation/500 cleanup. Touches every write handler; do after H-3
   since both edit `api_write.go`.
6. **L-4** — audit propagation. Cheap and worth doing while in those files.
7. **L-1, L-2, L-3** — observability and CI noise. Defer unless they become
   operationally annoying.
8. **N-1** — leave alone unless multi-user expansion happens.

---

## Out of scope (tracked elsewhere)

- **OSHA ITA exporter pre-ship hardening.** The OSHA ITA export pipeline has
  its own pre-ship checklist in `TODO.md` ("OSHA ITA exporter — pre-ship
  hardening"). That cluster is mostly SQL view fixes (date/time formats, 180-day
  caps, gender enum mapping, INNER JOIN coverage) plus three Go test gaps
  (`internal/osha_ita/exporter_test.go` golden-bytes test + column-aliasing
  coverage; `internal/database/deltas_test.go` mapping-coverage test). Items
  ship together as a unit before the first ITA submission, so they live in
  `TODO.md` rather than getting fragmented into this list.
