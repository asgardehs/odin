# Odin audit and auth, landing uncommitted changes

**Date:** 2026-04-07
**Project(s):** odin, heimdall, muninn

## Goal

Short session. Wire Odin's audit + auth packages into the HTTP server and land the uncommitted Heimdall/Muninn changes that had been sitting since yesterday.

## What happened

- Wired `internal/auth` (PAM/LogonUser) and `internal/audit` (git-backed trail) into the Odin HTTP server
- Added API endpoints: `POST /api/auth/verify`, `GET /api/auth/whoami`, `GET /api/audit/{module}/{entityID}`, `POST /api/audit/export`
- Audit endpoints gated by Basic Auth — credentials flow through to the audit store which re-verifies via OS auth
- Created platform-specific bootstrap files (`platform_unix.go`, `platform_windows.go`) with `ODIN_DATA_DIR` env override
- Fixed bug in `audit.walkLog` — was walking cumulative tree per commit instead of diffing against parent, causing duplicate entries
- Wrote 11 tests across audit and server packages, all passing
- Committed and pushed Odin (`9d0379f`)
- Committed and pushed Heimdall defaults cleanup (`4680bf0`) — removed stale `database_path` and `model_name`
- Committed and pushed Muninn Heimdall integration (`e3b95fc`) — three-tier vault path resolution

## Decisions

- **Basic Auth for audit endpoints** — simplest approach for a localhost-only app where the point is OS-level re-authentication, not session management. The audit store itself does the PAM/LogonUser verification.
- **`ODIN_DATA_DIR` env var** — follows the same pattern as `MUNINN_VAULT_PATH`. Audit repo lives at `$ODIN_DATA_DIR/audit/`, defaulting to `~/.local/share/odin/audit/`.

## Open threads

- Odin still needs: database layer (ncruces/go-sqlite3), migrations, first module (incidents or establishment core)
- Heimdall v0.1.0 release still parked until Odin reveals what else it needs
- Site sessionlogs symlink issue resolved earlier today (before this session)
