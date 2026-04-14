# Frontend Module Pages & Backend Hardening Implementation Plan

Created: 2026-04-13
Status: COMPLETE
Approved: Yes
Iterations: 0
Worktree: Yes
Type: Feature

## Summary

**Goal:** Replace 9 placeholder frontend module pages with real paginated list views (TanStack Table) and per-module detail pages, wire up the existing `CleanExpired()` session cleanup goroutine on a periodic schedule, add in-memory rate limiting to auth endpoints, and provide a Makefile for concurrent frontend+backend development.

**Architecture:** Frontend gains a reusable `<DataTable>` component powered by TanStack Table, 9 module-specific list page configurations, and 9 separate detail page components. Backend gains a `ratelimit` package with per-IP token buckets applied as handler wrappers on auth endpoints, plus a background goroutine for session cleanup. A top-level Makefile ties the dev workflow together.

**Tech Stack:** React 19, TanStack Table, react-router 7, Tailwind 4, Vite 8 (frontend) | Go 1.26, ncruces/go-sqlite3 (backend)

## Scope

### In Scope

- Replace all 9 `<Placeholder />` routes with paginated list views using TanStack Table
- Per-module detail page components (establishments, employees, incidents, chemicals, training, inspections, permits, waste, PPE)
- Detail route wiring (`/module/:id`)
- Clickable rows in list → navigate to detail
- Periodic session cleanup goroutine calling `CleanExpired()` every 15 minutes
- In-memory per-IP rate limiting on `POST /api/auth/login`, `POST /api/auth/reset-password`, `POST /api/auth/recover`
- Makefile with `make dev` to run Go server + Vite dev server concurrently
- Backend tests for rate limiter and session cleanup
- Frontend empty/loading/error states

### Out of Scope

- Create/edit forms (write operations) — CRUD endpoints exist, UI deferred
- Sorting, filtering, column visibility — TanStack Table supports these, add later
- Search/full-text search across modules
- Module-specific sub-entity navigation (e.g., inspection → findings drill-down)
- Authentication/authorization changes beyond rate limiting
- Mobile-responsive table layouts beyond basic overflow scrolling

## Approach

**Chosen:** Config-driven list pages + separate detail components

**Why:** A single `<DataTable>` component with TanStack Table handles all list views via per-module column configurations. Detail pages are separate components per module — this gives flexibility for module-specific layouts (incident timelines, chemical hazard flags, permit expiration tracking) at the cost of more files, but the patterns are consistent enough that each is small and focused.

**Alternatives considered:**
- Generic key-value detail renderer — rejected because EHS modules have very different field semantics (dates, CAS numbers, status codes) that deserve intentional formatting
- Custom HTML table without TanStack — rejected because TanStack's headless approach adds minimal bundle size while providing pagination state management and future extensibility (sorting, filtering) for free

## Context for Implementer

> Write for an implementer who has never seen the codebase.

- **Patterns to follow:**
  - List API returns `PagedResult` with `{ data: Row[], total, page, per_page, total_pages }` — see `internal/database/page.go:53-59`
  - Detail API returns a flat `Row` (map[string]any) — see `internal/server/api.go:36-48`
  - Frontend fetch wrapper at `frontend/src/api.ts` — use `api.get<T>(url)` for typed requests
  - Existing `useApi<T>` hook at `frontend/src/hooks/useApi.ts` works for simple GET requests
  - Dashboard cards at `frontend/src/pages/Dashboard.tsx` show the existing UI pattern (design tokens, Tailwind classes)

- **Conventions:**
  - CSS: Use `var(--color-*)` design tokens exclusively — never hardcode colors
  - Go: Table-driven tests, `httptest` recorder pattern (see `internal/server/api_test.go`)
  - Frontend pages go in `frontend/src/pages/`, components in `frontend/src/components/`
  - All API routes are at `odin.localhost:8080`, Vite proxies `/api/*` already configured in `vite.config.ts`

- **Key files:**
  - `frontend/src/App.tsx` — route definitions, currently imports Placeholder for 9 routes
  - `frontend/src/pages/Placeholder.tsx` — the file being replaced
  - `frontend/src/components/Shell.tsx` — sidebar nav with all module links
  - `internal/server/server.go:55-94` — all route registrations
  - `internal/server/api.go:52-204` — `entityRoutes()` pattern and all list/detail SQL
  - `internal/server/api_auth.go:67-249` — login, reset-password, recover handlers (rate limit targets)
  - `internal/auth/session.go:102-105` — `CleanExpired()` method
  - `cmd/odin/main.go:81` — where `CleanExpired()` is called once at startup

- **Gotchas:**
  - The Go server binds to `odin.localhost:8080`, not plain `localhost` — browsers resolve `*.localhost` to loopback per RFC 6761
  - `database.Row` is `map[string]any` — column names are snake_case from SQLite
  - `PagedResult.Data` is `[]Row` which serializes as `[]map[string]any` — frontend receives dynamic JSON objects, not typed structs
  - `readBody` in `api_write.go` has a 1MB limit — not relevant for this plan but be aware
  - List endpoints don't require auth (read-only data). Write endpoints require Bearer token.
  - **Training and PPE use sub-resource API paths** — training list is `/api/training/courses` (not `/api/training`), PPE list is `/api/ppe/items` (not `/api/ppe`). All other 7 modules follow the flat `/api/{module}` pattern. Getting this wrong produces a 404.

- **Domain context:**
  - This is an EHS (Environmental Health & Safety) platform for small industrial facilities
  - "Establishments" = physical facilities/plants. "Incidents" = workplace injuries/exposures tracked per OSHA 300 log requirements.
  - CAS numbers are unique chemical identifiers (e.g., "7732-18-5" for water). EHS = Extremely Hazardous Substance flag.
  - Training courses have validity periods — completions expire. PPE has inspection schedules.
  - Permits have expiration dates — "expiring soon" is a key dashboard metric.

## Runtime Environment

- **Start command:** `go run ./cmd/odin` (backend, port 8080) + `cd frontend && npm run dev` (Vite, port 5173)
- **Port:** Backend: 8080, Frontend dev: 5173 (proxies `/api/*` → 8080)
- **Health check:** `GET /api/health` → `{"status":"ok"}`

## Assumptions

- `@tanstack/react-table` v8 supports React 19 — supported by [TanStack docs, React 19 compatibility confirmed in v8.20+] — Tasks 4, 5 depend on this
- The 9 module list endpoints all return `PagedResult` with consistent structure — supported by `entityRoutes()` pattern in `api.go:25-49` — Tasks 5, 6 depend on this
- In-memory rate limiting is sufficient since this is a single-process desktop app — supported by architecture (single Go binary, localhost only) — Task 3 depends on this
- Session cleanup every 15 minutes is frequent enough — supported by `DefaultSessionDuration = 24h` (sessions live 24h, 15min cleanup catches expired ones promptly) — Task 2 depends on this

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| TanStack Table v8 incompatible with React 19 | Low | High | Check compatibility before installing; fallback to plain HTML table if needed |
| Rate limiter memory leak from abandoned IPs | Low | Low | Periodic cleanup goroutine evicts stale entries every 15 minutes |
| Module detail pages show different field sets than expected | Medium | Low | Detail pages read all fields from API response; add/remove fields in the component config |
| Concurrent `make dev` fails on some systems | Low | Medium | Makefile uses simple background process + wait; document manual alternative |

## Goal Verification

### Truths

1. All 9 module routes show paginated data tables instead of "Module view coming soon" placeholder
2. Clicking a row in any module list navigates to a detail page showing all fields for that record
3. `CleanExpired()` runs automatically every 15 minutes after server start, cleaning expired sessions
4. 6+ rapid login attempts within 60 seconds returns HTTP 429 Too Many Requests
5. `make dev` starts both Go backend and Vite frontend, and the frontend can call API endpoints through the proxy
6. Empty modules show a "No records" state, not a blank page or error
7. TS-001 through TS-005 pass end-to-end

### Artifacts

1. `frontend/src/components/DataTable.tsx` — reusable TanStack Table component
2. `frontend/src/pages/modules/*.tsx` — 9 list pages + 9 detail pages replacing Placeholder
3. `internal/server/ratelimit.go` — rate limiter implementation
4. `internal/server/ratelimit_test.go` — rate limiter tests
5. `internal/auth/session_test.go` — session cleanup goroutine tests (or additions to `auth_test.go`)
6. `Makefile` — dev workflow

## E2E Test Scenarios

### TS-001: Navigate module list pages
**Priority:** Critical
**Preconditions:** Backend running with seeded data, frontend dev server running
**Mapped Tasks:** Task 5

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/establishments` | Page title shows "Facilities", data table renders with column headers |
| 2 | Check table has pagination controls | Previous/Next buttons visible, page indicator shows "Page 1 of N" |
| 3 | Navigate to `/employees` | Different columns render (name, job title, department) |
| 4 | Navigate to `/chemicals` | Chemical-specific columns render (CAS number, product name) |

### TS-002: Click row to view detail
**Priority:** Critical
**Preconditions:** At least 1 establishment record exists
**Mapped Tasks:** Task 6

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/establishments` | List page renders with at least 1 row |
| 2 | Click on the first row | Browser navigates to `/establishments/1` |
| 3 | Verify detail page content | All establishment fields displayed (name, address, NAICS code, etc.) |
| 4 | Click browser back button | Returns to `/establishments` list |

### TS-003: Empty module state
**Priority:** High
**Preconditions:** Module with zero records (e.g., incidents on a fresh database)
**Mapped Tasks:** Task 5

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/incidents` | Page title shows "Incidents" |
| 2 | Check table area | "No records found" message displayed instead of empty table |

### TS-004: Rate limiting blocks rapid login attempts
**Priority:** High
**Preconditions:** Backend running, valid user exists
**Mapped Tasks:** Task 3

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Submit 5 login attempts with wrong password rapidly | Each returns 401 Unauthorized |
| 2 | Submit 6th login attempt immediately | Returns 429 Too Many Requests |
| 3 | Wait 60 seconds | Next login attempt returns 401 (not 429) — bucket refilled |

### TS-005: Pagination navigation
**Priority:** High
**Preconditions:** Module with >50 records (default page size)
**Mapped Tasks:** Task 5

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to module with many records | Table shows first page, pagination indicates multiple pages |
| 2 | Click "Next" page button | Table updates with next set of records, page indicator updates |
| 3 | Click "Previous" page button | Returns to first page |

## Progress Tracking

- [x] Task 1: Makefile for concurrent dev servers
- [x] Task 2: Session cleanup goroutine
- [x] Task 3: Rate limiter for auth endpoints
- [x] Task 4: TanStack Table + DataTable component
- [x] Task 5: Module list pages — replace all 9 placeholders
- [x] Task 6: Detail pages — Establishments, Employees, Incidents
- [x] Task 7: Detail pages — Chemicals, Training, Inspections
- [x] Task 8: Detail pages — Permits, Waste, PPE

**Total Tasks:** 8 | **Completed:** 8 | **Remaining:** 0

## Implementation Tasks

### Task 1: Makefile for concurrent dev servers

**Objective:** Create a Makefile that runs the Go backend and Vite dev server concurrently with a single command, unblocking end-to-end auth testing.

**Dependencies:** None

**Files:**

- Create: `Makefile`

**Key Decisions / Notes:**

- Set `SHELL := /bin/bash` at the top of the Makefile to ensure consistent behavior (user's interactive shell is fish, which doesn't support POSIX `trap`).
- Use `&` backgrounding for the Go server, then run Vite in foreground. `trap` to clean up on Ctrl+C.
- The Vite proxy is already configured in `frontend/vite.config.ts:9-11` — no changes needed there.
- Go server binds to `odin.localhost:8080`, Vite dev server runs on its default port (5173).
- Add `make build` target too (builds frontend then Go binary).

**Definition of Done:**

- [ ] `make dev` starts Go backend + Vite frontend concurrently
- [ ] Ctrl+C stops both processes cleanly
- [ ] Frontend served at `http://localhost:5173` can call `/api/health` through the proxy
- [ ] `make build` produces a working binary with embedded frontend

**Verify:**

- `make dev` (manual — observe both servers start)
- `curl http://localhost:5173/api/health` returns `{"status":"ok"}`

---

### Task 2: Session cleanup goroutine

**Objective:** Start a background goroutine that calls `SessionStore.CleanExpired()` every 15 minutes, replacing the single startup-time call.

**Dependencies:** None

**Files:**

- Modify: `cmd/odin/main.go`
- Create: `internal/auth/session_test.go` (or add to existing `auth_test.go`)

**Key Decisions / Notes:**

- Replace line 81 (`sessionStore.CleanExpired()`) with a goroutine that runs `CleanExpired()` in a ticker loop.
- Extract the cleanup loop into a testable function: `StartCleanupLoop(ctx context.Context, store *SessionStore, interval time.Duration)` on the `SessionStore` type. This way `main.go` calls `go sessionStore.StartCleanupLoop(ctx, 15*time.Minute)` and tests can use a short interval.
- Use `context.WithCancel` tied to the shutdown signal so the goroutine stops cleanly.
- Log cleanup errors at warn level but don't crash — `CleanExpired()` is best-effort.
- 15 minute interval balances between cleanup frequency and unnecessary work (sessions last 24h).

**Definition of Done:**

- [ ] Goroutine calls `CleanExpired()` every 15 minutes
- [ ] Goroutine stops cleanly on context cancellation (no goroutine leak)
- [ ] One immediate cleanup on startup retained
- [ ] Unit test verifies cleanup goroutine calls `CleanExpired` at least once and exits on context cancellation
- [ ] No test failures in existing suite

**Verify:**

- `go test ./internal/auth/ -run TestCleanup -v`
- `go vet ./cmd/odin/...`

---

### Task 3: Rate limiter for auth endpoints

**Objective:** Add in-memory per-IP rate limiting to login, reset-password, and recover endpoints. Return HTTP 429 when limit exceeded.

**Dependencies:** None

**Files:**

- Create: `internal/server/ratelimit.go`
- Create: `internal/server/ratelimit_test.go`
- Modify: `internal/server/api_auth.go` (wrap handlers)

**Key Decisions / Notes:**

- Token bucket algorithm: each IP gets a bucket of 5 tokens, refilling 1 token per 12 seconds (≈5/min). Implemented as a struct with `sync.Mutex` protection.
- Global `RateLimiter` struct holds `map[string]*bucket` with a periodic cleanup goroutine removing entries older than 10 minutes.
- Apply to 3 endpoints: `handleLogin`, `handleResetPassword`, `handleRecover`. These are the unauthenticated endpoints accepting credentials.
- Don't rate-limit `handleGetSecurityQuestions` (GET, returns questions only, no credential attempt).
- `handleSetup` is also unprotected but only works when zero users exist — not a brute-force target.
- Rate limiter wraps as `s.rateLimited(handler)` returning an `http.HandlerFunc`.
- The `RateLimiter` should be created in `server.New()` and stored on the Server struct.

**Definition of Done:**

- [ ] First 5 login attempts succeed (consume all 5 tokens), the 6th attempt returns HTTP 429
- [ ] Rate limit applies per remote IP (different IPs have independent buckets)
- [ ] Rate limit response includes `Retry-After` header
- [ ] Stale bucket entries are cleaned up periodically
- [ ] Tests verify exact boundary: `TestRateLimiter_Allow5Block6`, `TestRateLimiter_RefillAfterDelay`, `TestRateLimiter_PerIP`
- [ ] All existing tests pass

**Verify:**

- `go test ./internal/server/ -run TestRateLimit -v`
- `go test ./internal/server/ -v` (full suite)

---

### Task 4: TanStack Table + DataTable component

**Objective:** Install TanStack Table and build a reusable `<DataTable>` component that renders paginated data from the API's `PagedResult` format.

**Dependencies:** None
**Mapped Scenarios:** TS-003, TS-005

**Files:**

- Modify: `frontend/package.json` (add @tanstack/react-table)
- Create: `frontend/src/components/DataTable.tsx`

**Key Decisions / Notes:**

- Install `@tanstack/react-table` (headless — we control all rendering with Tailwind).
- `DataTable` props: `columns` (TanStack ColumnDef[]), `apiUrl` (string — the paginated list endpoint), `onRowClick` (optional callback).
- Component internally fetches data using `apiFetch`, manages pagination state, and renders a styled `<table>`.
- Pagination controls: Previous / page number / Next. Show "Page X of Y" and total count.
- States: loading (skeleton rows), empty ("No records found" with icon), error (error message banner).
- Style with existing design tokens (`var(--color-bg-card)`, `var(--color-border)`, etc.) matching Dashboard card styling.
- Row hover effect for clickable rows.

**Definition of Done:**

- [ ] `@tanstack/react-table` installed
- [ ] DataTable renders a paginated table from any `PagedResult` API endpoint
- [ ] Loading state shows skeleton placeholder
- [ ] Empty state shows "No records found" message
- [ ] Error state shows error message
- [ ] Pagination Previous/Next controls work
- [ ] Clicking a row calls `onRowClick` callback
- [ ] No TypeScript errors (`tsc --noEmit`)

**Verify:**

- `cd frontend && npm run build` (type check + build)

---

### Task 5: Module list pages — replace all 9 placeholders

**Objective:** Create module-specific list pages using `DataTable` and replace all `<Placeholder />` routes in `App.tsx`.

**Dependencies:** Task 4
**Mapped Scenarios:** TS-001, TS-003, TS-005

**Files:**

- Create: `frontend/src/pages/modules/EstablishmentList.tsx`
- Create: `frontend/src/pages/modules/EmployeeList.tsx`
- Create: `frontend/src/pages/modules/IncidentList.tsx`
- Create: `frontend/src/pages/modules/ChemicalList.tsx`
- Create: `frontend/src/pages/modules/TrainingList.tsx`
- Create: `frontend/src/pages/modules/InspectionList.tsx`
- Create: `frontend/src/pages/modules/PermitList.tsx`
- Create: `frontend/src/pages/modules/WasteList.tsx`
- Create: `frontend/src/pages/modules/PPEList.tsx`
- Modify: `frontend/src/App.tsx` (replace Placeholder imports with module list pages, add `:id` detail routes)
- Modify: `frontend/src/components/Shell.tsx` (update nav if needed)

**Key Decisions / Notes:**

- Each list page is a thin wrapper: imports `DataTable`, passes module-specific column definitions and API URL.
- Column definitions and API URLs per module — show the most important 4-6 columns:
  - Establishments: `apiUrl: /api/establishments` — name, city, state, NAICS code, is_active
  - Employees: `apiUrl: /api/employees` — name (first + last), job_title, department, is_active
  - Incidents: `apiUrl: /api/incidents` — case_number, incident_date, description (truncated), severity, status
  - Chemicals: `apiUrl: /api/chemicals` — product_name, CAS number, is_ehs, is_active
  - Training: `apiUrl: /api/training/courses` (**not** `/api/training`) — course_code, course_name, duration_minutes, delivery_method
  - Inspections: `apiUrl: /api/inspections` — inspection_number, inspection_date, status, overall_result
  - Permits: `apiUrl: /api/permits` — permit_number, permit_name, expiration_date, status
  - Waste: `apiUrl: /api/waste-streams` — stream_code, stream_name, waste_category, is_active
  - PPE: `apiUrl: /api/ppe/items` (**not** `/api/ppe`) — serial_number, manufacturer, model, status
- Row click navigates to `/{module}/{id}` using react-router's `useNavigate`.
- Keep `Placeholder.tsx` file but remove its import from App.tsx — can be deleted later.
- Add wildcard detail routes: `<Route path="establishments/:id" element={<EstablishmentDetail />} />` etc. (detail components come in Tasks 6-8, use a temporary "Loading detail..." component until then).

**Definition of Done:**

- [ ] All 9 module routes show paginated data tables with module-specific columns
- [ ] No module shows "Module view coming soon"
- [ ] Empty modules show "No records found"
- [ ] Row click navigates to `/{module}/{id}`
- [ ] Pagination works on all list pages
- [ ] No TypeScript errors

**Verify:**

- `cd frontend && npm run build`
- `cd frontend && npm run lint`

---

### Task 6: Detail pages — Establishments, Employees, Incidents

**Objective:** Create detail page components for the 3 core modules with module-specific layouts.

**Dependencies:** Task 5
**Mapped Scenarios:** TS-002

**Files:**

- Create: `frontend/src/pages/modules/EstablishmentDetail.tsx`
- Create: `frontend/src/pages/modules/EmployeeDetail.tsx`
- Create: `frontend/src/pages/modules/IncidentDetail.tsx`
- Modify: `frontend/src/App.tsx` (wire detail routes if not done in Task 5)

**Key Decisions / Notes:**

- Each detail page: fetches single record from `GET /api/{module}/{id}`, renders all fields in a structured layout.
- Use `useParams()` from react-router to get the ID, `useApi` hook to fetch.
- Layout pattern: page title (record name/number) + back button, then grouped field sections in cards.
  - Establishment: Address section, Industry section (NAICS/SIC), Employee counts, Metadata
  - Employee: Personal info, Employment info (job title, department, hire date), Status
  - Incident: Case info (number, date, time), Description, Classification (severity, case code), Status, Location
- Handle 404 (record not found) gracefully — show "Record not found" with back link.
- Use existing design tokens for cards, labels, values.

**Definition of Done:**

- [ ] `/establishments/:id` shows all establishment fields
- [ ] `/employees/:id` shows all employee fields
- [ ] `/incidents/:id` shows all incident fields with severity and status styling
- [ ] Back button returns to module list
- [ ] 404/missing record shows error state
- [ ] No TypeScript errors

**Verify:**

- `cd frontend && npm run build`

---

### Task 7: Detail pages — Chemicals, Training, Inspections

**Objective:** Create detail page components for chemicals, training courses, and inspections.

**Dependencies:** Task 5

**Files:**

- Create: `frontend/src/pages/modules/ChemicalDetail.tsx`
- Create: `frontend/src/pages/modules/TrainingDetail.tsx`
- Create: `frontend/src/pages/modules/InspectionDetail.tsx`

**Key Decisions / Notes:**

- Chemical: CAS number prominent, hazard flags (is_ehs, is_sara_313, is_pbt) as colored badges, physical state, manufacturer
- Training: Course info (code, name, description, duration, delivery method), test info (has_test, passing_score), validity period
- Inspection: Inspection number, type, dates (scheduled vs actual), inspector, status, overall result
- Same layout pattern as Task 6: title + back button, grouped sections in cards.

**Definition of Done:**

- [ ] `/chemicals/:id` shows all chemical fields with hazard flag badges
- [ ] `/training/:id` shows course details (mapped to `GET /api/training/courses/:id`)
- [ ] `/inspections/:id` shows inspection details with date handling
- [ ] Back button works on all three
- [ ] No TypeScript errors

**Verify:**

- `cd frontend && npm run build`

---

### Task 8: Detail pages — Permits, Waste, PPE

**Objective:** Create detail page components for permits, waste streams, and PPE items.

**Dependencies:** Task 5

**Files:**

- Create: `frontend/src/pages/modules/PermitDetail.tsx`
- Create: `frontend/src/pages/modules/WasteDetail.tsx`
- Create: `frontend/src/pages/modules/PPEDetail.tsx`

**Key Decisions / Notes:**

- Permit: Permit number, name, issuing agency, dates (effective, expiration), status. Highlight if expiring within 90 days.
- Waste: Stream code, name, category, type code, physical form, status
- PPE: Serial/asset tag, manufacturer, model, size, dates (in-service, expiration), status, current assignee
- Same layout pattern: title + back button, grouped sections in cards.
- Training route maps to `/api/training/courses/:id`, PPE route maps to `/api/ppe/items/:id` — note the API path differs from the frontend route.

**Definition of Done:**

- [ ] `/permits/:id` shows permit details with expiration highlighting
- [ ] `/waste/:id` shows waste stream details
- [ ] `/ppe/:id` shows PPE item details
- [ ] Back button works on all three
- [ ] No TypeScript errors

**Verify:**

- `cd frontend && npm run build`

## Open Questions

None — all design decisions resolved.

## Deferred Ideas

- **Create/edit forms** — write API endpoints exist; add forms in a future plan
- **Table sorting and filtering** — TanStack Table supports this; enable once list views are validated
- **Sub-entity navigation** — e.g., inspection → findings, incident → corrective actions
- **Bulk operations** — multi-select rows for batch status changes
- **Export to CSV/PDF** — compliance reporting needs
