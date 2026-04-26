# entityRoutes Helper

Register list + get-by-id + search routes for a single-table read via one helper:

```go
s.entityRoutes("/api/establishments", "establishment",
    `SELECT id, name, ... FROM establishments ORDER BY name LIMIT ? OFFSET ?`,
    `SELECT COUNT(*) FROM establishments`,
    `SELECT * FROM establishments WHERE id = ?`,
    "name", "city", "naics_code",  // searchable columns
)
```

Registers:
- `GET <pattern>` — paginated list (`?page=N&per_page=N`) with optional
  `?q=<term>` LIKE-search across `searchCols`
- `GET <pattern>/{id}` — single row by id

**Use it when** the read is a single-table query with optional fuzzy search.
Boilerplate reduction and consistency across all module read routes.

**Skip it and write a custom `s.mux.HandleFunc(...)` when** the handler
does aggregations (e.g. `handleDashboardCounts`), cross-table preview shapes
(e.g. `handleITAPreview`), whitelist-driven param validation (e.g. the
`/api/lookup/{table}` route), or any non-CRUD response shape.
