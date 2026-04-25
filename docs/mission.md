# Product Mission

## Problem

Small and mid-sized manufacturing facilities face the same federal EHS
compliance burdens as large-scale companies, but lack the funding and
IT budgets that commercial SaaS products demand. The available
commercial options are largely reskinned ERP tools — built around
inventory and finance workflows — that don't fit the shape of EHS
compliance work.

Odin is designed as a single binary that runs locally, with no vendor
lock-in, a SQLite database, and no recurring fees. Anyone can use it.

## Target Users

- EHS professionals (in-house safety and industrial-hygiene staff)
- Small to medium sized business owners (where the owner wears the
  EHS hat alongside other responsibilities)

## Solution

Odin is built on a custom EHS Ontology organized around three axes:

- **HazardType** — Physical, Mechanical, Chemical, Biological,
  Psychosocial, Ergonomic, Electrical
- **ActionContext** — what the affected employee was doing at the
  time of the incident (transportation, storage, maintenance,
  emergency response, etc.)
- **ContextualConditions** — modifying conditions (containment status,
  location, quantity threshold)

This three-axis routing classifies each incident to the correct
combination of federal agencies that need to be notified — OSHA, EPA,
EPCRA, DOT, NRC, and others — so users don't have to memorize the
overlapping reporting matrices.

The pedagogical effect: new EHS professionals get a tool that walks
the routing for them, and when senior practitioners retire, the
knowledge they carried doesn't leave with them — it's encoded in the
ontology that drives Odin.
