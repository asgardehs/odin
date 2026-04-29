# Odin

_Desktop EHS and compliance management for small manufacturing._

![Status](https://img.shields.io/badge/status-in_development-4F3B95?style=for-the-badge)

## Overview

Small and mid-size manufacturers carry the same regulatory burden as large
enterprises — OSHA recordkeeping, EPA reporting, chemical inventories,
training records, permits, inspections — but without the IT budget for
enterprise EHS software. The alternatives are expensive SaaS platforms that
lock in your data, or spreadsheets held together with good intentions. Odin
is a single-binary desktop application that runs locally, stores data in a
single SQLite file, and covers the compliance modules EHS professionals
actually use day to day. It is built for the people who have to do the work,
not for the IT departments that procure the tools.

The application runs as an embedded HTTP server on `odin.localhost:8080` and
opens the user's default browser to the UI. The browser is the interface;
Odin itself has no window chrome to manage, no native dependencies to
install, and no cloud account to create. The binary and its embedded
assets are everything you need to run it.

## Current Scope

Odin is in active development, ahead of its first release. The list below is
honest about what currently works, what is in progress, and what is
intentionally deferred.

**Available now** — implemented end-to-end with backend, API, and UI:

- Establishments (facility management)
- Employees
- Chemicals and chemical inventory
- Storage locations
- Incidents
- Inspections
- Permits
- PPE
- Training
- Waste streams
- Application users, sessions, and audit history
- Git-backed audit trail of every record change

**In progress for the initial release:**

- Emissions (schema and backend complete; frontend pending)
- Water (schema and backend complete; frontend pending)
- Reporting pipeline — OSHA 300, 300A, Tier II, TRI, and the per-module
  compliance reports
- Schema Builder — user-defined tables, fields, and relationships for data
  that does not fit the pre-built modules

**Post-release backlog:**

- NAICS/SIC code lookup helper on the Establishment form
- SDS PDF attachment and versioning on chemicals
- Schema import/export between establishments
- Additional drilldown views across the module pages

The initial release ships when the "in progress" list is complete. Backlog
items land in subsequent releases as time permits.

## Requirements

Building Odin from source requires:

- **Go 1.26 or later**
- **Bun** for the frontend build (`bun.sh`)
- A Unix-like environment (Linux or macOS) or Windows

Runtime requirements are minimal — no external database, no Python, no
Node runtime. Authentication uses the host operating system's native
facilities (PAM on Unix, the Windows authentication API on Windows),
combined with application-level user accounts managed by Odin itself.

## Building and Running

```bash
git clone --recursive https://github.com/asgardehs/odin.git
cd odin
make build
./odin
```

`--recursive` fetches the vendored EHS Ontology submodule at
`third_party/ehs-ontology/`. If you already cloned without `--recursive`,
run `git submodule update --init` from inside the repo to pick it up.

The `make build` target compiles the frontend with Bun, embeds the output
into the Go binary, and produces a single `odin` executable. Running it
starts the embedded server, runs pending database migrations, and opens
your default browser to the UI.

First-run setup prompts you to create an administrator account; subsequent
runs take you to the login screen.

### Development Mode

For iterative development, `make dev` starts the Go backend and a Vite
development server concurrently:

```bash
make dev
```

The Go backend runs at `odin.localhost:8080`. The Vite dev server runs at
`localhost:5173` and proxies `/api/*` requests to the backend. Use the Vite
URL for live reloading during frontend work; use the direct backend URL
for API or backend testing.

Stop both processes with `Ctrl+C`.

### Data Locations

Odin follows platform conventions for where it stores data:

| Platform | Default path                                           |
| -------- | ------------------------------------------------------ |
| Linux    | `~/.local/share/odin/`                                 |
| macOS    | `~/Library/Application Support/odin/`                  |
| Windows  | `%APPDATA%\odin\`                                      |

The data directory contains:

- `odin.db` — the SQLite database with all user data and application state
- `audit/` — a git repository recording every write as a commit, giving you
  a full change history you can inspect with any git client

Override the default with the `ODIN_DATA_DIR` environment variable.

## Architecture at a Glance

Odin is a Go HTTP server that embeds its React frontend assets via
`go:embed` and serves them from the same process that serves the JSON API.
SQLite is accessed through `ncruces/go-sqlite3`, a pure-Go implementation
that eliminates the CGO dependency and makes cross-compilation trivial.

The backend is organized into conventional layers: HTTP handlers in
`internal/server`, data access in `internal/repository`, database and
migration machinery in `internal/database`, authentication and sessions in
`internal/auth`, and audit logging in `internal/audit`. The frontend is a
React single-page application built with Vite, following a consistent
List → Detail → Form pattern across modules.

Two migration sources run at startup: application-level migrations
(`embed/migrations/`) manage the user, session, and config tables that
belong to Odin the application; EHS-schema migrations
(`docs/database-design/sql/`) manage the compliance domain tables that
belong to Odin the EHS tool. Keeping the two separate lets the application
scaffolding evolve without perturbing the regulatory schema.

The EHS-schema tables are derived from a formal OWL/Turtle ontology
vendored as a submodule at `third_party/ehs-ontology/` (its own repo at
[asgardehs/ehs-ontology](https://github.com/asgardehs/ehs-ontology)).
The ontology is the source of truth; SQL entries trace back to ontology
concepts. See [CONTRIBUTING.md](CONTRIBUTING.md) for the contract
between the ontology, the schema, and the application.

For the broader architectural direction — module design, reporting
pipeline, schema builder design, and ecosystem integration plans — see the
[Odin architecture docs](https://asgardehs.github.io/docs/odin/).

## Project

- **License:** GPL-3.0 — see [LICENSE](LICENSE)
- **Code of Conduct:** see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- **Contributing:** see [CONTRIBUTING.md](CONTRIBUTING.md)
- **Security:** see [SECURITY](SECURITY.md)
  

## Name

> _In Norse mythology, Odin is the all-father and chief of the Æsir, who
> sits on the high seat Hlidskjalf to look into every realm. He sends the
> ravens Huginn and Muninn out each day to bring back knowledge from
> across the worlds. Here, Odin is the seat from which facility operations
> are overseen — informed, in time, by the knowledge Muninn holds and the
> documents Huginn produces._

_Part of the [Asgard EHS family](https://asgardehs.github.io/)._
