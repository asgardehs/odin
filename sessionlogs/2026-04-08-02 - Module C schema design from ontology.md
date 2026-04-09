# Module C schema design from ontology

**Date:** 2026-04-08
**Project(s):** odin

## Goal

Build one module's SQLite schema from the completed ontology (v3.1) to validate that the .ttl maps cleanly to tables and to compare against the original database design.

## What happened

- Compared `001_incidents.sql` (original) against ontology Modules C + D
- Designed and wrote `module_c_osha300.sql` — full OSHA 300 recordkeeping schema derived from the ontology
- Original design was structurally sound for data capture but lacked the decision logic — the ontology adds the two-gate recording decision tree (work-relatedness → recording criteria) as explicit, auditable tables
- New schema adds: `recording_decisions`, `recording_criteria`, `recording_criteria_met`, `work_relatedness_exceptions`, `first_aid_treatments`, `incident_treatments`, `osha_direct_reports`, `osha_reporting_triggers`, `incident_investigations`, `investigation_team_members`, `incident_witnesses`, `incident_severity_levels`
- Key validation: the ontology maps cleanly to relational tables. Reference tables encode the expert knowledge, junction tables capture the decision logic, and the UI can render guided workflows from the schema structure.

## Decisions

- **Recording decision as a separate table, not a boolean flag** — makes the two-gate process auditable. An OSHA inspector can see exactly which criteria fired and why a case was or was not recorded.
- **Corrective actions link to investigation, not directly to incident** — follows the ontology's workflow: incident → investigation → root cause → corrective action → verification.
- **Hierarchy of Controls is a required field on corrective actions** with justification required for lower-effectiveness choices (administrative/PPE).
- **Audit log and settings removed from module schema** — audit is handled by the git-backed audit store, settings by Heimdall.

## Open threads

- Module C schema not committed yet — no code changes, just design doc
- Squirrel parked: structured RCA forms per method (5 Whys chain, Fishbone 6M categories, Fault Tree AND/OR gates)
- Remaining modules to design: A (EPCRA/TRI), B (Title V/CAA), D (already partially covered in Module C schema)
- Database layer (ncruces/go-sqlite3, migration runner) still needed before any of this becomes real code
- User sitting on ontology v3.1 overnight — confirmed it validated clean in Protege
