---
project: Odin
description:
  Desktop EHS/compliance application for small manufacturing facilities
doc_date: 2026-04-03
doc_rev_date: 2026-04-06
written_by: Adam Bick
---

# Odin — Design Document

Full design documentation lives on the project site:

- [Overview](https://asgardehs.github.io/docs/odin/)
- [Architecture](https://asgardehs.github.io/docs/odin/architecture/) — backend
  layers, frontend patterns, data flow, ADRs
- [Schema Builder](https://asgardehs.github.io/docs/odin/schema-builder/) —
  custom table engine
- [Database Design](https://asgardehs.github.io/docs/odin/database/) — schema
  summary across all modules
- [Integration](https://asgardehs.github.io/docs/odin/integration/) — ecosystem
  connections (Heimdall, Muninn, Huginn)

Detailed database schemas are in `docs/database-design/`.

## History

This document supersedes `docs/architecture.md` (archived 2026-04-06). The
architecture doc was the initial design draft; the site documentation is the
maintained version with Bifrost references removed and Muninn integration
updated for the flat-file architecture.
