# Response Helpers

Every JSON-returning handler ends with one of two helpers:

```go
// Success
writeJSON(w, data)

// Error
writeError(w, "establishment not found", http.StatusNotFound)
```

Shapes:

```json
// Success — data goes at the top level
{ "id": 42, "name": "Acme Plant" }

// Error — { "error": "<message>" }
{ "error": "establishment not found" }
```

Rules:

- **No bare `w.Write([]byte(...))` for JSON** responses. Both helpers
  set `Content-Type: application/json` and handle encoding correctly.
- **Errors use the `{"error": "..."}` envelope.** Success responses
  do NOT wrap data in `{success, data}` — the absence of an `error`
  key + a 2xx status is the signal. Frontend's `apiFetch` already
  inspects `res.ok` and `res.status`; redundant envelopes waste
  bytes for no information gain.
- **HTTP status carries the verdict.** 200 / 201 / 204 / 400 / 401 /
  403 / 404 / 500 mean what they say. The error message in the body
  is supplementary, never the primary signal.

**Intentional bypasses (non-JSON responses):**

- CSV exports — `Content-Type: text/csv`, streamed via `io.Copy`
  (e.g. `handleITADetailCSV` in `internal/server/api_osha_ita.go`).
- File downloads — same pattern as CSV with appropriate
  `Content-Disposition`.
- Future: server-sent events, raw binary downloads. Same principle —
  if the response is not JSON, `writeJSON` is wrong.

For JSON-shaped responses there are no other bypasses.
