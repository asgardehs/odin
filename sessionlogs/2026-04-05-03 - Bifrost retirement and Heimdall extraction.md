# Bifrost retirement and Heimdall extraction

**Date:** 2026-04-05
**Project(s):** bifrost (archived), heimdall (new)

## Goal

Implement message routing (asgardehs/bifrost#2) — proxy JSON-RPC calls between tools.

## What actually happened

Started planning the router, hit a wall: Muninn has no socket listener for Bifrost to connect to. Muninn only exposes CLI (text output), MCP daemon (HTTP), and LSP (stdio). The architecture doc assumed every tool would run a JSON-RPC socket server, but that doesn't match reality.

This triggered a bigger question: **is 4 separate daemons talking over IPC over-engineering?** Walked through it. The answer was yes and no:

- **No** — each tool (Odin, Muninn, Huginn) has genuine standalone value for different users. The modularity is the feature.
- **Yes** — Bifrost as an IPC router was solving a problem that doesn't exist. No user needs a message bus between 3 tools on the same machine. The real value was always Heimdall (shared config).

## Decisions

- **Bifrost archived.** The IPC daemon (service registry, message routing, socket transport) added complexity without matching reality. Each tool is standalone.
- **Heimdall extracted** into `asgardehs/heimdall` as a standalone Go library + CLI. Odin and Muninn import it directly — no daemon, no sockets. Same SQLite config DB on disk.
- **Huginn becomes a library** imported by Odin and Muninn, plus a standalone CLI. Not a separate daemon.
- **Muninn gets its own GUI eventually** — not embedded in Odin.
- **New architecture:** 3 standalone products (Odin, Muninn, Huginn) + 1 shared config library (Heimdall). No IPC layer.

## What got built

- `asgardehs/heimdall` repo created and pushed (cf3cc9f)
- Direct Go API: `Open`/`Get`/`Set`/`List`/`Reset`/`Schema`
- All Bifrost Heimdall features preserved: schema validation, enum/secret types, AI opt-in, change history, cross-platform paths
- `ChangeNotifier` interface replaces the RPC server coupling
- CLI: `heimdall config get/set/list/reset`
- `asgardehs/bifrost` archived on GitHub
- `archived-bifrost.tar` created at `~/media/projects/asgard/`

## Open threads

- Muninn: needs to import Heimdall for config management
- Odin: can now start app code — no longer blocked by Bifrost
- Project board: Bifrost issues are moot (repo archived). May want to clean up the project board.
- Memory files in `.claude/projects/-home-adam-media-projects-asgard-bifrost/` updated to reflect new architecture
