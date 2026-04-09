# Odin design doc and architecture decisions

**Date:** 2026-04-06
**Project(s):** odin, asgardehs.github.io

## Goal

Create Odin's design documentation on the project site, building on the valid parts of the existing architecture.md and updating for current ecosystem state.

## What happened

- Read full 1188-line architecture.md and all 7 database design docs (incidents, chemicals, training, waste, inspections, permits, emissions, water)
- Created 5 site doc pages: index, architecture, schema-builder, database, integration
- Updated all stale references: Bifrost → Heimdall, Muninn → flat-file, Wails → dropped
- Made three major architecture pivots during the session:
  1. Dropped Wails v2 — CGO requirement for webview bindings
  2. Switched to embedded HTTP server + system browser (zero CGO)
  3. Switched from Svelte to React (bigger ecosystem for admin UI, Svelte was a Wails convenience)
  4. Switched from mattn/go-sqlite3 to ncruces/go-sqlite3 (pure Go SQLite via WASM)
- Added Odin to site nav and landing page
- Created pointer design-doc.md in Odin repo, architecture.md ready to archive

## Decisions

- **Embedded HTTP server + system browser, not Wails** — eliminates CGO entirely. The compliance tool doesn't need native window chrome. Single binary, trivial cross-compilation.
- **`odin.localhost:8080`** — browsers resolve `*.localhost` to loopback per RFC 6761. Clean address bar, no /etc/hosts edit.
- **React + Tailwind, not Svelte** — Svelte was a Wails convenience. React has the larger ecosystem for data tables, forms, and admin UIs (shadcn/ui, TanStack Table, React Hook Form).
- **`ncruces/go-sqlite3`** — pure Go SQLite via WASM. Full compatibility (WAL, FTS5, triggers, 132 tables) with zero CGO.
- **Every Asgard tool is now pure Go** — Muninn, Heimdall, and now Odin. One `go build`, one CI matrix, done.

## Open threads

- Odin repo has no code yet — just docs and database designs. Scaffold is next.
- Heimdall integration uncommitted in Muninn (env.go + cmd_init.go changes)
- Heimdall defaults.go cleanup uncommitted
- Site docs need commit + push (Muninn updates, Heimdall pages, Odin pages)
- architecture.md needs archiving after site docs land
