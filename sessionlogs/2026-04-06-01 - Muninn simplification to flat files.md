# Muninn simplification to flat files

**Date:** 2026-04-06
**Project(s):** muninn, asgardehs.github.io

## Goal

Strip Muninn down to its essence: flat markdown files with text search. Remove SQLite, ONNX embeddings, MCP server, and snippets.

## What happened

- Archived pre-simplification code to `~/media/projects/asgard/muninn-archive.tar` (230MB)
- Deleted 4 packages: `internal/server/` (MCP), `internal/embed/` (ONNX), `internal/store/` (SQLite), `internal/importer/`
- Deleted `internal/markdown/chunker.go` and 10 CLI command files (snippets, daemon, stats, export, import)
- Dropped 9 go.mod dependencies (sqlite3, sqlite-vec, onnxruntime, MCP SDK, x/crypto, etc.)
- Added 3 new vault files: `search.go` (text search with scoring), `tags.go`, `list.go` (filtered listing)
- Rewired LSP to use vault + in-memory wikilink index (removed 6 `s.store.*` call sites across 4 files)
- Rewrote 7 CLI command files to use vault directly
- Simplified Makefile: no CGO, no `-tags fts5`, cross-compile now works for all platforms
- Rewrote CI release workflow: matrix build for Linux/macOS/Windows (no MSYS2, no sqlite3.h)
- Rewrote all 8 remaining doc site pages, deleted `snippets.md` and `mcp-tools.md`
- Updated README, design doc, CLAUDE.md (both repo and parent), chore.md
- Commit: `ac8899f Simplify Muninn to flat-file vault with text search`

## Decisions

- **Drop snippets entirely** rather than converting to flat files. Muninn is a note tool, not a snippet manager. Simpler model.
- **Keep the LSP** — it's 2500 LOC but provides real editor value (wikilinks, completion, diagnostics) and has zero dependency on the removed infrastructure.
- **Simple text scoring** for search: title match +3, tag match +2, body match +1 per query word. No fancy ranking needed for a personal vault.
- **Pure Go build** — no CGO means trivial cross-compilation. The CI workflow that was a multi-issue headache (sqlite3.h on Windows, deprecated macOS runners) is now a simple matrix build.

## Open threads

- CI release workflow rewritten but untested — needs a tag push to verify all 3 platform builds
- Site docs updated locally but not pushed yet — needs commit in asgardehs.github.io repo
- Heimdall integration (board item) is still pending — Muninn config management
- Project board may have stale items from the old architecture
