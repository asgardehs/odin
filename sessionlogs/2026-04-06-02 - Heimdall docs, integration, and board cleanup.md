# Heimdall docs, integration, and board cleanup

**Date:** 2026-04-06
**Project(s):** heimdall, muninn, asgardehs.github.io

## Goal

Work through the remaining punch list: Heimdall docs, Heimdall-Muninn integration, project board cleanup.

## What happened

- Wrote Heimdall README and full doc site (index, quickstart, Go API, CLI reference, config keys) in `asgardehs.github.io/docs/heimdall/`
- Updated site landing page: added Heimdall card + docs nav link, updated Muninn description for flat-file arch
- Integrated Heimdall into Muninn's `env.go`: three-tier vault path resolution (env var > Heimdall > platform default)
- `heimdallVaultPath()` checks for DB existence before opening — won't create `~/.local/share/heimdall/` on a fresh system
- `muninn init` now persists vault path to Heimdall (best-effort, silent on failure)
- Cleaned stale Heimdall defaults: removed `database_path` and `model_name` from muninn namespace
- Updated Muninn config docs with the new precedence chain
- Cleaned project board: marked Heimdall integration Done, commented all moot issues (10 closed issues annotated with simplification context)
- Stopped the old `muninn.service` systemd unit (daemon mode no longer exists)

## Decisions

- **Env var always wins over Heimdall** — standard Unix convention, keeps backward compat. VS Code extension already passes vault path via env var.
- **Don't create Heimdall DB on read** — only `muninn init` creates it. Normal commands skip Heimdall if DB doesn't exist. Prevents side effects on fresh systems.
- **Holding Heimdall v0.1.0 release** — waiting until after Odin work reveals what else Heimdall needs to manage. Avoids premature versioning.

## Open threads

- Muninn Heimdall integration and docs update changes are uncommitted — need commit + push
- Heimdall defaults.go cleanup uncommitted — needs commit + push in heimdall repo
- Site docs (Muninn updates + Heimdall pages + landing page) uncommitted — need commit + push, also `git rm --cached sessionlogs` to fix CI build
- Board has 2 Todo items left: Heimdall v0.1.0 release, Odin scaffold
- Next: Odin design doc
