# UI Restructure — Phased Plan (2026-05-04)

Implements the UI restructure designed in
[`ui change.md`](../../ui%20change.md): collapses the flat module sidebar
into six top-level destinations with three domain hubs (Facilities,
Employees, Inspections), a global facility selector, and KPI-card
dashboards.

## Principles

- **Hubs teach grouping.** The IA itself communicates how compliance
  scopes work (per-facility, per-employee, per-inspection).
- **KPI cards, not nav tiles.** Every hub card carries at least one live
  number — it's a teaching surface, status surface, and nav entry in one.
- **Selection propagates everywhere.** Selected facility scopes the
  top-level Dashboard, all three hubs, and their child module pages.
- **Top-level Dashboard is the funding-demo screen.** Ships fully wired
  before any hub. If hub KPIs need to ship as `—` placeholders to make
  the v1 release date, that's acceptable; the top-level can't.
- **Existing routes stay.** All current module pages remain reachable;
  only the entry surface changes.

## Cross-cutting decisions

- Facility selector lives at the **top of the sidebar**, persisted in
  user preferences, with an explicit "All facilities" option.
- "Currently selected facility" is global app state — React context +
  user-pref persistence on the backend.
- All list endpoints accept an optional `facility_id` query param.
  Filter semantic is **inclusive**: records associated with the selected
  facility (including via join paths), not strictly belonging to it.
- Sample Events is one polymorphic card; type filtering happens inside
  the page, not via separate cards per sampling type.
- Custom tables are injected into the relevant hub based on a
  parent-module field added to the Custom Table Builder.
- "Schema" admin tool is renamed to **"Custom Table Builder"** in the
  UI; route stays `/admin/schema`.
- Account moves out of the sidebar into the top-right user menu.

## Phase 0 — Data-model audit + schema deltas

**Goal:** Confirm every entity that should be facility-scopable has a
clean FK or join path to facility. Catch and address gaps before any UI
work depends on them.

Tasks:

- Audit each module table for facility relationship: `permits`,
  `emission_units`, `chemicals`, `storage_locations`, `discharge_points`,
  `waste`, `audits`, `inspections`, `ww_sample_events`, `incidents`,
  `training`, `ppe`, `employees`.
- Document each entity's join path (direct FK, through employee, etc.)
  in `docs/database-design/` or as comments in the module SQL.
- For any entity missing a usable path: write a schema delta
  (`sql/deltas/2026-05-DD-*.sql`) per the project's delta convention.
- Decide single-vs-multi facility assignment for `employees`. If
  multi-assignment is real, document the join table now.

Demo checkpoint: written audit doc, deltas (if any) merged, existing DBs
upgrade clean on restart.

Unblocks: every later phase.

## Phase 1 — Chrome: sidebar restructure + facility selector + persistence

**Goal:** New nav surface in place. Selector works and persists, but no
hub layouts exist yet — clicking sidebar items still routes to existing
list pages.

Backend:

- User preferences storage for `selected_facility_id` (extend existing
  user prefs or add a small table; schema delta if needed).
- API: `GET /api/me/preferences`, `PATCH /api/me/preferences` (or
  whatever pattern matches existing prefs handling).

Frontend:

- `FacilityContext` provider + `useFacility()` hook (reads/writes pref).
- `<FacilitySelector />` component at top of sidebar — facility
  combobox + "All facilities" option.
- New sidebar with six items: Dashboard · Facilities · Employees ·
  Inspections · SDS and Documents · Admin (admin-only).
- Move Account link from sidebar to top-right user menu.
- Old sidebar items (Permits, Emissions, Waste, etc.) hidden from nav
  but routes still work for deep links.

Demo checkpoint: app runs with new sidebar; selecting a facility
persists across reload; clicking sidebar items lands on existing list
pages (unchanged for now).

Unblocks: Phases 2, 3, 7.

## Phase 2 — KPI infrastructure (reusable surface)

**Goal:** Build the components and backend pattern every hub will
consume. No user-visible feature ships in this phase by itself.

Backend:

- Decide pattern: per-module summary endpoints
  (`GET /api/permits/summary?facility_id=X`) or a single aggregate
  endpoint (`GET /api/dashboard/summary`). Recommend per-module — keeps
  ownership clean and lets each module evolve its KPI independently.
- Stub summary endpoints for every module that will get a card
  (returning `{}` is fine where the live aggregate isn't built yet).

Frontend:

- `<KPICard />` component: title, primary number, secondary metric,
  status color (red/amber thresholds), whole-card click target, empty
  state ("No records yet — add your first").
- `<HubLayout />` component: upper-third card grid + lower 2/3 records
  table slot + Expand button → `/{base}/full` route.
- All facility-aware queries read from `useFacility()` and pass
  `facility_id` to the backend.

Demo checkpoint: Storybook-equivalent or a temporary `/devnull` route
showing KPICard variants and HubLayout shell. Not user-facing.

Unblocks: Phases 3, 4, 5, 6.

## Phase 3 — Top-level Dashboard (funding-demo screen)

**Goal:** The screen the funding pitch opens to. Fully wired, polished.

Backend:

- Aggregate endpoints for the six top-level cards (or a unified
  endpoint hitting each module's summary):
  - Expiring permits (counts by 30/60/90 day buckets)
  - Expiring training (lapsing in 30 days)
  - Open audit findings
  - Open incidents (by severity)
  - Sampling events due
  - OSHA 300 status (entries logged YTD, ITA submission state)

Frontend:

- `/` route renders the top-level Dashboard with the six cards.
- Honors `useFacility()` — when a facility is selected, all six cards
  re-scope; when "All facilities", they're org-wide.
- Polish budget: this is the demo screen. Spacing, copy, status colors,
  empty states all reviewed.

Demo checkpoint: top-level Dashboard tells a five-second story.
Selecting a facility re-scopes every card live.

Unblocks: nothing critical (parallelizable with hub phases after).

## Phase 4 — Facilities hub

**Goal:** First hub built — validates the HubLayout pattern at scale.

Backend:

- Summary endpoints for the seven cards (Permits, Emission Units,
  NPDES Permits, Waste, Chemicals, Storage Locations, Outfalls). Some
  may already exist from Phase 3; reuse.
- Each child module's list endpoint accepts `?facility_id=X`.

Frontend:

- `/establishments` (labeled "Facilities") renders HubLayout: 7 KPI
  cards + Facilities records table + Expand button.
- `/establishments/full` fullscreen route shows just the records table.
- Card clicks deep-link to child module pages with facility scope
  applied (e.g. `/permits?facility_id=X` or via FacilityContext if the
  child reads from context directly — pick one pattern, stick with it).

Demo checkpoint: select a facility → its compliance posture is visible
at a glance via the seven cards.

Unblocks: pattern proven for Phases 5, 6.

## Phase 5 — Employees hub

**Goal:** Apply the validated pattern.

- Summary endpoints for Training, PPE, Incidents (filtered through
  employee → facility join).
- `/employees` renders HubLayout: 3 KPI cards + Employees records
  table + Expand button.
- `/employees/full` fullscreen route.

Demo checkpoint: training-compliance status for selected facility's
employees visible at a glance.

## Phase 6 — Inspections hub

- Summary endpoints for Audits and (polymorphic) Sample Events.
- `/inspections` renders HubLayout: 2 KPI cards + Inspections records
  table + Expand button.
- Sample Events page extended with type filter chips (WW today; IH/air
  reserved as future types).
- `/inspections/full` fullscreen route.

## Phase 7 — SDS and Documents + Admin hub

Combined because both are lightweight aggregator pages.

SDS and Documents:

- New `/documents` route with two sections: SWPPPs (embeds existing
  `swpps` list) and SDS Library (empty-state placeholder describing
  the future feature: chemical-linked SDS PDFs, search, expiry).

Admin hub:

- New `/admin` landing page (admin-only), four cards: Users · Custom
  Table Builder · Import · OSHA ITA Export.
- UI labels: rename "Schema" → "Custom Table Builder" everywhere it
  appears in nav, breadcrumbs, page titles. Routes unchanged.

Demo checkpoint: every sidebar item reaches a real (or
deliberately-placeholder) page; SDS empty state communicates intent.

## Phase 8 — Custom Table Builder: parent-module picker

**Goal:** Custom tables can declare which hub they belong to and show
up there as additional KPI cards.

Backend:

- Schema delta: add `parent_module` column to the schemas table
  (values: `none`, `facilities`, `employees`, `inspections`).
- API: schema CRUD includes parent_module.
- Each hub's summary endpoint returns built-in cards plus any custom
  tables matching that hub.

Frontend:

- Builder add a "Where does this live?" field with the four options.
- Hubs render custom-table cards after their built-in cards (with a
  visible "Custom" or user-added affordance so the distinction is
  legible).
- Top-level (`none`) custom tables surface in the sidebar as their own
  entry, after the six built-in items.

Demo checkpoint: create a custom table with parent=Facilities → it
appears as an extra card on the Facilities hub.

## Phase 9 — Cleanup + polish

- Remove dead Placeholder routes if any.
- Verify deep links to old top-level module routes still work and are
  facility-scoped via context.
- Audit empty states across hubs — every zero-state has a CTA.
- Audit status-color thresholds (red/amber/green) for consistency.
- README / `docs/odin/` page updates documenting the new IA.
- Remove "ui change.md" from repo root (it's the design scratch; the
  plan is the work tracker, the docs site is the user-facing record).

## Suggested build order

0 → 1 → 2 → 3 → (4, 5, 6 in any order; 4 first to validate pattern) →
7 → 8 → 9.

Phases 4–6 are parallelizable once Phase 2 lands. Phase 8 must wait for
Phase 7 (Admin hub must exist before changing the builder under it).

## Out of scope

- New module pages or net-new EHS data types
- Theming / Nótt & Dagr changes
- Mobile / narrow-viewport layout (defer to post-v1)
- The actual SDS library implementation (placeholder only)
- Schema changes beyond what Phases 0 and 8 require
