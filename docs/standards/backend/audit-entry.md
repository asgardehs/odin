# Audit Entry Shape

Every audit record uses the same shape:

```go
audit.Entry{
    Action:   audit.ActionUpdate,           // create | update | delete | export
    Module:   "establishments",             // SQL table name
    EntityID: strconv.FormatInt(id, 10),    // primary key as string
    User:     user,                         // OS username
    Summary:  "Updated establishment: Acme",// human-readable
    Before:   beforeJSON,                   // optional snapshot
    After:    afterJSON,                    // optional snapshot
}
```

Rules:

- **`Module` is the SQL table name**, not a logical-domain label. Direct,
  machine-correlatable, and the audit history UI joins
  `module = ? AND entity_id = ?` straight against the source row. No
  translation layer.
- **`EntityID` is always a string.** Numeric IDs use
  `strconv.FormatInt(id, 10)`. Composite IDs use a delimiter pattern,
  e.g. `"{establishment_id}-{year}-{kind}"` for OSHA ITA exports.
- **`Action` is one of the typed constants** in `internal/audit`:
  `ActionCreate`, `ActionUpdate`, `ActionDelete`, `ActionExport`.
  Add a new `Action` constant rather than freelancing strings.
- **`Summary` is human-readable**, not JSON. Goes to the audit-history
  UI and to commit messages on the git-backed audit log. Format like
  `"<verb> <module>: <identifier>"` — e.g. `"Created establishment:
  Acme Plant"`, `"Exported OSHA ITA detail CSV for establishment 1,
  year 2025"`.
- **Audit is best-effort.** Never block a successful mutation on an
  audit-write failure. The `recordRowAudit` / `recordSchemaAudit`
  helpers swallow errors with `_ = s.audit.Record(...)` because the
  mutation has already committed by that point. Losing the audit
  trail is bad; rolling back a real write because the audit log is
  unreachable is worse.

For new modules: don't invoke `audit.Record` directly from handlers.
Mutations route through the repository's `insertAndAudit` /
`updateAndAudit` / `deleteAndAudit` helpers, which compose the right
Entry shape automatically. Only call `audit.Record` directly for
non-mutation events (exports, schema DDL changes).
