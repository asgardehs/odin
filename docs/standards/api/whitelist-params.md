# Whitelisted Parameterized Routes

When a route takes a user-controlled value that becomes a SQL identifier
(table name, column name, schema name), validate against a server-side
whitelist before issuing the query. Bind parameters cannot stand in for
identifiers — they're for values only.

```go
// internal/repository/lookup.go
var lookupQueries = map[string]string{
    "case_classifications":         `SELECT code, name, '' AS description FROM ...`,
    "incident_severity_levels":     `SELECT code, name, description FROM ...`,
    "ita_establishment_sizes":      `SELECT code, name, description FROM ...`,
    // ...
}

func (r *Repo) ListLookup(table string) ([]database.Row, error) {
    query, ok := lookupQueries[table]
    if !ok {
        return nil, fmt.Errorf("unknown lookup table: %s", table)
    }
    return r.DB.QueryRows(query)
}
```

Rules:

- **Whitelist maps live alongside the SQL they gate**, not in the
  handler. The route handler is a thin pass-through; identifier-safety
  is the repository's job.
- **404 the unknown.** Unknown identifiers become `404 Not Found`,
  not `400 Bad Request`. The route truly doesn't exist for that table.
- **Add an entry only when** the underlying data has a stable shape
  (e.g. `(code, name, description)` for lookups), is non-sensitive
  (lookups never; never expose identity / audit / user data through
  whitelist routes), and serves a real frontend need (form dropdown
  data, etc.).

The pattern applies any time the URL controls an identifier. Right
now this is `/api/lookup/{table}`. If a future route exposes
column-level filtering (`/api/<table>?orderBy=<col>`), the same
pattern applies — column names whitelisted per table.

**What this is NOT for:** values. `WHERE id = ?` doesn't need a
whitelist; that's what bind parameters exist for.
