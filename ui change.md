# UI Restructure — Plan

Iteration on the original sketch. Goal: collapse the flat module list into a small set of domain hubs that **teach** the EHS compliance mental model (per-facility, per-employee, per-inspection), not just save nav real estate.

## Principles guiding the restructure

1. **Hubs teach grouping.** The fact that Permits/Emissions/NPDES/Waste/Chemicals/Storage/Outfalls all hang off a Facility is itself a teaching moment for new EHS pros. The IA should make that visible.
2. **KPI cards, not nav tiles.** A card that says "Permits" with an icon is a wasted slot. A card that says "**3 active permits — 1 expiring in 30 days**" is a teaching surface, a status surface, and a navigation entry all at once. Every hub-dashboard card should carry at least one live number.
3. **Context propagates.** Clicking a card from a Facility's hub should land on that child module **filtered to the current facility**, not the global list. Same for Employee → Training (filtered to that employee). This is what makes the hub model coherent.
4. **Existing routes don't disappear.** All current module pages stay reachable via deep links and from inside the hubs; we're only changing the **entry surface** (sidebar + landing pages). Low blast radius.

## Top-level navigation (sidebar)

Six destinations:

- **Dashboard** — cross-cutting KPIs across all facilities/employees
- **Facilities** — hub dashboard
- **Employees** — hub dashboard
- **Inspections** — hub dashboard
- **SDS and Documents** — library
- **Admin** — settings hub (admin-only visibility)

User menu (top-right, separate from sidebar) keeps **Account** + **Logout**.

## Top-level Dashboard

**Job-to-be-done:** "What needs my attention across the whole org this week?"

Suggested KPI cards:

- **Expiring permits** (count, next 30/60/90 days)
- **Expiring training** (count of employees with training lapsing in 30 days)
- **Open audit findings** (across all facilities)
- **Open incidents** (unresolved, by severity)
- **Sampling events due** (upcoming, by deadline)
- **OSHA 300 status** (current year — entries logged, ITA submission state)

Each card click → its filtered child view at the cross-org scope.

This top-level dashboard is **the funding-pitch demo screen**. It needs to look good and tell a story in five seconds. Worth budgeting polish here.

## Facilities (hub)

**Layout:**

- Upper third: 7 KPI cards (one row, wraps on narrow screens)
- Lower two-thirds: Facilities records table (was `EstablishmentList`)
- Toolbar above the table: search, filter, **"Expand"** button → fullscreen route (`/establishments/full`) that hides the cards and gives the table the whole viewport

**Cards** (each card → child module's list, filtered to the *currently-selected* facility if one is highlighted in the table; otherwise org-wide):

| Card | Source | Suggested KPI |
|------|--------|--------------|
| Permits | `permits` | "N active · M expiring 30d" |
| Emission Units | `emission-units` | "N units · M monitoring overdue" |
| NPDES Permits | `permits/npdes` | "N active · M sample events due" |
| Waste | `waste` | "N streams · M pending manifests" |
| Chemicals | `chemicals` | "N on inventory · M without SDS" |
| Storage Locations | `storage-locations` | "N locations · M over capacity" |
| Outfalls (Discharge Points) | `discharge-points` | "N outfalls · M with exceedances" |

**Decided:** User picks a current facility (e.g. via a facility selector in the chrome). The selection is **persisted in user config** so it survives sessions. Hub cards reflect the selected facility's numbers; clicking a card jumps to that child module filtered to the same facility. A "Clear selection" / "All facilities" option returns to org-wide view.

> Terminology note: route is `establishments` (OSHA's term, important for ITA reporting), label is "Facilities" (everyday term). Recommend keeping route, labeling "Facilities" in the UI — same record, two audiences. Flag for visibility.

## Employees (hub)

Same layout pattern.

| Card | Source | Suggested KPI |
|------|--------|--------------|
| Training | `training` | "N current · M expiring 30d · K overdue" |
| PPE | `ppe` | "N assignments · M due for fit test" |
| Incidents | `incidents` | "N open · M this year · K OSHA-recordable" |

Lower 2/3: Employees records table + Expand button → fullscreen.

## Inspections (hub)

| Card | Source | Suggested KPI |
|------|--------|--------------|
| Audits | `audits` | "N scheduled · M with open findings" |
| Sample Events | polymorphic (WW today; IH/air later) | "N events YTD · M results pending" |

Lower 2/3: Inspections records table + Expand button.

**Decided:** Single polymorphic Sample Events card. Today it covers `ww-sample-events`; the underlying view should be built generically so adding IH personal sampling, air sampling, etc. is a data/type addition, not a new card. Filter chips inside the Sample Events page differentiate by type.

## SDS and Documents

V1 contents:

- **SWPPPs** — existing `swpps` routes, surface as a list section here
- **SDS Library** — placeholder route + empty state with "coming soon" copy referencing what'll go here (chemical-linked SDS PDFs, search, expiration tracking)

For v1.0 funding demo, this can be a single page with two sections + an empty SDS state — that's enough to show intent without overpromising.

## Admin

Admin-only landing page with cards:

| Card | Route | Notes |
|------|-------|-------|
| Users | `admin/users` | Existing |
| Custom Table Builder | `admin/schema` | **Rename in-UI from "Schema"** — route can stay `admin/schema` |
| Import | `admin/import` | Existing |
| OSHA ITA Export | `osha-ita` | Existing |

**Decided:** User-created custom tables are **injected into the relevant hub** based on a "parent module" the user picks at table-creation time in the Custom Table Builder. Valid parents: Facilities, Employees, Inspections, or **None / top-level** (shows up directly in the sidebar as its own entry). Custom tables appear as additional KPI cards in their parent hub, after the built-in cards. Builder needs a "Where does this live?" field added to the create flow.

## Cross-cutting design rules

- **KPI card anatomy:** title (label) · primary number (large) · secondary metric (small, contextual) · subtle status color when threshold crossed (red for overdue/expired, amber for ≤30 days). Whole card is the click target.
- **Empty states:** if a module has zero records, the card shows "No records yet — add your first" as a CTA, not a hidden zero. Pedagogy + good demo UX.
- **Expand button semantics:** routes to a sibling URL (e.g. `/establishments/full`) so users can deep-link the fullscreen view. Browser back returns to the hub.
- **Permission visibility:** Admin sidebar entry hidden for non-admins (existing `AdminOnly` wrapper pattern still applies).
- **Account:** moves out of the sidebar into the user menu (top-right). Reduces sidebar to the six items.

## Out of scope for this iteration

- New module pages or schema changes
- Theming changes (Nótt & Dagr stays as-is)
- Mobile/narrow-viewport layout (defer; desktop-first for v1)
- The SDS library itself (placeholder only)

## Decisions

- **Card scope (Facilities hub):** user-selected facility, persisted in config
- **Sample Events polymorphism:** one polymorphic card, type-filtered internally
- **Custom tables home:** Option B — parent picked at create-time in the Custom Table Builder
- **Facility selector lives at the top of the sidebar.** Always visible; current scope is legible from any page.
- **Selection propagates everywhere.** Selected facility scopes the Top-level Dashboard, all three hubs, and their child module pages. "All facilities" / cleared selection returns to org-wide. Worth the extra implementation lift for the workflow win.
- **KPI wiring for v1:** Top-level Dashboard ships **fully wired** (funding-pitch screen — must demo). Hub KPIs may ship partially live with `—` placeholders for queries not yet built; placeholders are explicit and tracked.

## Implementation notes raised by "propagate everywhere"

- A "currently selected facility" becomes **global app state** (likely a context provider + persisted user pref). All list queries take an optional `facility_id` filter.
- **Data model check needed at build time:** confirm every entity that should be facility-scopeable has a clean FK or join path to facility. Things to verify:
  - Employees → facility (single? multi-assignment?)
  - Training, PPE, Incidents → through Employee → facility
  - Audits, Sample Events → directly to facility?
  - Chemicals, Storage Locations → directly to facility?
  - Custom tables → depends on parent module
- If any entity can span multiple facilities (e.g. an employee assigned to two), define the filter semantic: "show records associated with the selected facility" (inclusive) vs. "show records *only* at the selected facility" (exclusive). Recommend inclusive — it's more useful and pedagogically honest about how compliance scopes work.
