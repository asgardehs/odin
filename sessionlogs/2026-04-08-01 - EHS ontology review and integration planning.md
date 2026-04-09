# EHS ontology review and integration planning

**Date:** 2026-04-08
**Project(s):** odin

## Goal

Review the EHS ontology (.ttl) and decide how it integrates into Odin.

## What happened

- Read full 1249-line ehs-ontology.ttl (v2.0) — Employee–Hazard bipolar model with three-axis compliance routing (HazardType + ActionContext + ContextualConditions)
- Discussed three integration options: Go structs, SQLite reference data, or Turtle/RDF at runtime
- Agreed on SQLite for runtime data + .ttl as design document. Go code implements routing as SQL queries. No XML, no RDF engine.
- Decided to defer database schema work until ontology is complete

## Decisions

- **SQLite over XML for ontology runtime** — XML would require custom parser, validator, and query layer. SQLite gives all of that for free, plus lives alongside operational data in one store.
- **.ttl is the blueprint, SQLite is the building** — maintain the ontology in Turtle for formal design, generate/migrate SQLite seed data from it.
- **Ontology drives schema, not the other way** — existing SQL table designs may need redesign once the .ttl is finished. Don't lock in tables prematurely.

## What happened (continued)

- User completed ontology independently between sessions — jumped from v2.0 to v3.1
- v3.1 adds: Establishment class, Module A (EPCRA Tier II + TRI Section 313), Module B (Title V/CAA air permitting), Module C (OSHA 300 recordkeeping), Module D (Employee Incident Management)
- Cross-module wiring connects chemicals through inventory → emission units → TRI → employee exposure → incidents → OSHA recording
- Validated in Protege — no errors
- Ontology now lives at `docs/ontology/ehs-ontology-v3.1.ttl` in the Odin repo

## Open threads

- User sleeping on the .ttl overnight before committing to schema design
- Next session: design SQLite tables from the ontology, then build the routing engine
- Any ontology additions after schema design become program updates, not blockers
- Existing database design docs in odin/docs/database-design/ may need revision post-ontology
