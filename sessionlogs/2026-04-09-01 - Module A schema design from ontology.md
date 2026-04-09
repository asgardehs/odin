# Module A schema design from ontology

**Date:** 2026-04-09
**Project(s):** odin

## Goal

Design clean Module A (EPCRA/TRI) SQLite schema from the ontology v3.1, same approach as Module C — consolidate the pre-ontology `002_chemicals.sql` + `002a_sara313.sql` into one ontology-derived file.

## What happened

- Set up laptop dev environment first (bun for frontend build, gh CLI installed + authed, nvm present but no node versions — used bun instead since fish shell + nvm don't play well together)
- Go build passes clean on laptop
- Compared existing pre-ontology chemical/TRI schema against ontology Module A classes
- Existing schema was already structurally solid for data capture — the gap was thinner than Module C's was
- Wrote `module_a_epcra_tri.sql` — complete ontology-derived schema

## Decisions

- **Auditable decision tables over boolean flags** — same pattern as Module C's `recording_decisions`. Added three new determination tables: `tier2_threshold_determinations`, `tri_applicability_determinations`, `tri_form_determinations`. An inspector can trace every regulatory gate.
- **EPCRA notification tracking as first-class tables** — Section 302 (EHS planning, 60-day deadline), Section 311 (initial chemical notification, 90-day), Section 304 (release notification, immediate + 7-day written follow-up). The original schema only tracked Tier II reports (Section 312).
- **Cross-module emission unit link** — `tri_release_emission_units` table with commented FK to Module B. The ontology's `releaseFromEmissionUnit` creates the three-way linkage: inventory → emission unit → TRI release.
- **MEK correctly excluded from SARA 313 seed data** — ontology v3.1 documents the delisting (70 FR 37727, June 2005). MEK remains an InventoryChemical for Tier II but is not a TRIChemical.
- **Regulatory requirements bridge tables excluded** — they're cross-module concerns, not Module A specific. Will need a shared/common file eventually.

## Open threads

- Module A schema not committed yet — design doc only, same as Module C was before commit
- Module B (Title V / CAA air permitting) next — will complete the emission unit FK
- Module D (Employee Incident Management) after that — partially covered by Module C's incidents/investigations tables
- Database layer (ncruces/go-sqlite3, migration runner) still the main blocker before any schema becomes real code
- Regulatory requirements bridge tables need a home — either a shared file or folded into the migration runner
