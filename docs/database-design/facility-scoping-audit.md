# Facility-Scoping Audit (Phase 0)

Companion to [`docs/plans/2026-05-04-ui-restructure.md`](../plans/2026-05-04-ui-restructure.md).

The UI restructure introduces a global "currently selected facility" that
propagates to the top-level Dashboard, all three hubs, and their child
module pages. This audit confirms every facility-scopable entity has a
clean FK or join path to `establishments`, so that facility filtering
can be implemented without further schema work.

## Result

**No EHS-module schema deltas required.** Every entity below either has a
direct `establishment_id` FK or reaches one through a single-hop join.

One **non-domain gap** flagged for Phase 1: there is no per-user
preferences table. Owned by Phase 1 (chrome / persistence), not this
audit.

## Single-vs-multi facility (decided)

`employees.establishment_id` is `NOT NULL` — schema enforces **one
employee belongs to exactly one establishment**. There is no
employee-establishment join table.

**Decision:** keep the single-facility-per-employee model for v1. If
multi-facility employee assignment is wanted later it becomes its own
schema change with downstream filter-semantic implications. Not in scope
now.

## Direct facility FKs

These entities have `establishment_id INTEGER NOT NULL REFERENCES establishments(id)`
and an index on it. List endpoints can filter with a simple
`WHERE establishment_id = ?`.

| Entity | Module | Notes |
|---|---|---|
| `employees` | `module_c_osha300.sql:46` | hard FK; one employee → one facility |
| `incidents` | `module_c_osha300.sql:274` | direct |
| `permits` | `module_permits_licenses.sql:167` | direct; UNIQUE(establishment_id, permit_number) |
| `chemicals` | `module_a_epcra_tri.sql:76` | direct |
| `storage_locations` | `module_a_epcra_tri.sql:35` | direct |
| `air_emission_units` (Emissions) | `module_b_title_v_caa.sql:354` | UNIQUE(establishment_id, unit_name) |
| `discharge_points` (Outfalls) | `module_d_clean_water.sql:143` | UNIQUE(establishment_id, outfall_code) |
| `waste_streams` (Waste) | `module_industrial_waste_streams.sql:238` | direct |
| `inspections` | `module_inspections_audits.sql:713` | direct |
| `audits` | `module_inspections_audits.sql:971` | direct |
| `ww_sampling_events` (Sample Events) | `module_d_clean_water.sql:605` | direct |
| `training_courses` | `module_training.sql:353` | course definition is per-facility |
| `ppe_items` | `module_ppe.sql:416` | physical asset is per-facility |

## Join-path facility scoping

These are per-employee tables (no establishment_id of their own); they
inherit facility scope by joining through `employees.establishment_id`.

| Entity | Filter path |
|---|---|
| `training_completions` | `JOIN employees ON tc.employee_id = e.id WHERE e.establishment_id = ?` |
| `training_assignments` | same path through employee |
| `ppe_assignments` | through `ppe_items.establishment_id` (asset side) **or** through employee — pick the asset path; that's where the physical scope lives |
| `ppe_fit_tests` | through employee |
| `employee_ppe_sizes` | through employee |
| `employee_activities` | through employee |
| `employee_work_areas` | through `work_areas.establishment_id` (work area is itself facility-scoped) |

## KPI query implications by hub

**Facilities hub cards** (all direct):

- Permits: `SELECT count(*) FROM permits WHERE establishment_id = ?`
- Emission Units: `air_emission_units` direct
- NPDES Permits: `permits` filtered by permit type
- Waste: `waste_streams` direct
- Chemicals: `chemicals` direct
- Storage: `storage_locations` direct
- Outfalls: `discharge_points` direct

**Employees hub cards** (mixed):

- Training: count over `training_completions` joined to `employees`,
  filter `e.establishment_id = ?`. KPIs like "expiring in 30d" use
  `training_completions.expires_on` (verify field name during Phase 5).
- PPE: per-employee assignments — count `ppe_assignments` joined to
  `employees` filtered by `establishment_id`. "Due for fit test" uses
  `ppe_fit_tests` join.
- Incidents: `incidents.establishment_id` direct.

**Inspections hub cards** (all direct):

- Audits: `audits.establishment_id` direct.
- Sample Events: `ww_sampling_events.establishment_id` direct. The
  polymorphic card promised in the plan needs a future "type" column or
  a UNION over multiple sampling-event tables when IH/air sampling is
  added — that's a future schema decision, not blocking for v1 (WW
  only).

**Top-level Dashboard cards** — same queries with the optional
`establishment_id = ?` filter; when "All facilities" is selected the
filter is omitted and aggregates run org-wide.

## Filter semantic

Inclusive: a record is in scope if it is associated with the selected
facility through any of the paths documented above. There is no
exclusive/strict variant since the schema doesn't currently allow an
entity to belong to multiple facilities anyway.

## Per-user preferences gap (flagged for Phase 1)

The selected facility must persist per user across sessions. The current
schema has no per-user preferences table — `app_users` has only auth
fields, and `app_config` is a global key/value store, not per-user.

**Recommended Phase 1 delta:** `embed/migrations/003_user_preferences.sql`
with a small `app_user_preferences(user_id, key, value)` table keyed
`(user_id, key)`. Generic enough to hold the selected facility today
plus future prefs (default landing page, table column visibility, etc.)
without further migrations.

This is captured in Phase 1's backend task list and does not need to be
written now.
