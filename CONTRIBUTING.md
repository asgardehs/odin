# Contributing to Odin

Odin is a desktop EHS and compliance application aimed at small manufacturing
facilities. Its design rests on a formal ontology, a derived SQL schema, and
a layered application architecture that assumes both surfaces will stay in
sync over time. Contributions that respect that architecture are welcome.
Contributions that shortcut it — schema edits that bypass the ontology,
module implementations that depart from established patterns, migrations
that edit shipped history — create work for the maintainer and for every
downstream user.

This document is direct about what works and what doesn't because the
alternative is wasted effort. Your time is worth respecting, and so is the
project's.

## Before You Start

A few things to know about how this project is run, so you can decide
whether contributing here is a good use of your time.

Odin is solo-maintained. Review cadence depends on the maintainer's
availability, and not every contribution will be accepted. The project has
a defined scope, a defined architecture, and a clear release plan. Changes
that fit are welcome; changes that don't will be declined — sometimes after
discussion, sometimes on sight. Declining a contribution is not a comment
on its quality; it means it doesn't belong in this particular application.

Odin has three sources of truth, ordered by distance from the user:

- **The ontology** (`docs/ontology/ehs-ontology-v3.1.ttl`) — a formal
  OWL/Turtle model of the EHS domain, covering regulatory concepts like
  EPCRA/TRI, Title V/CAA, OSHA 300, and Incident Management. This is the
  core logic of the entire system. Everything else is derived from it.
- **The EHS schema** (`docs/database-design/sql/`) — SQL translation of
  the ontology into SQLite tables, views, and triggers. Schema entries
  should be traceable back to ontology concepts.
- **The application schema** (`embed/migrations/`) — tables that belong to
  Odin the application, not the EHS domain: users, sessions, app config.
  These evolve independently of the ontology.

Contributions that change the ontology or the EHS schema have downstream
implications that the application schema does not. The rules below reflect
that difference.

## Reporting Issues

A good bug report for Odin includes, at minimum:

- Your operating system (Odin's auth and browser-launch behavior are
  platform-specific)
- The Odin version or commit you are using
- Whether you are running a built binary or `make dev`
- A minimal reproduction — ideally the sequence of UI actions or API
  calls that triggered the bug, along with any errors from the server
  console or browser devtools

If the bug involves the database, please mention whether the database was
created fresh or carries data from an earlier version, and whether your
audit git repo (`ODIN_DATA_DIR/audit/`) has any unusual state. Migration
bugs and audit bugs often only surface on databases with real history.

If you are not sure whether something is a bug or expected behavior, open
an issue anyway and label it as a question. An unclear behavior that needs
documentation is itself a kind of bug.

## Before You Submit a PR

There are two kinds of pull requests: ones that should just be sent, and
ones that should be discussed first. Knowing which is which saves
everyone's time.

**Just send it.** Typo fixes, broken-link corrections, obvious-bug fixes
with a clear root cause, small documentation improvements, and test
additions for existing behavior don't need prior discussion. Open a PR.

**Open an issue first.** Anything that fits one of the following
categories should be discussed before code is written:

- New EHS modules (see below)
- Ontology extensions or changes (see below)
- New database migrations or changes to shipped migrations (see below)
- Changes to authentication, session management, or the audit trail
- Changes to shared frontend components (`DataTable`, `FormField`,
  `SectionCard`, `FormActions`, `Modal`, `ConfirmDialog`, `StatusBadge`,
  `AuditHistory`, `Shell`) — these are used by every module page
- Refactors that touch more than a handful of files
- Anything that deviates from the established patterns described below
- Anything you're not sure about

Pull requests in these categories that arrive without prior discussion
will usually be closed without a detailed review. This is not personal,
and it is not a comment on code quality. It is a consequence of scarce
review time being spent on changes whose direction has already been
agreed on. A ten-minute issue conversation before you start can save you
hours of work on a PR that does not fit the project's direction.

### New EHS Modules

A new EHS module (say, a hypothetical Emergency Response Plans module, or
Contractor Safety, or Hearing Conservation) is one of the largest change
categories in the project. A module typically touches the ontology, the
EHS schema, the backend repositories and API, the frontend pages, and
eventually the reporting pipeline. A misaligned module is a lot of wasted
work.

Before starting:

1. Open an issue proposing the module, including the regulatory drivers
   (which standards does it cover, at the section level), the primary
   records it needs to capture, and the existing modules it would relate
   to.
2. Wait for the maintainer to confirm scope and approach. The answer
   may be "yes, proceed," "yes, but with a smaller first cut," or "not
   yet — that conflicts with something already planned."
3. Once scope is agreed, work through the ontology first, the schema
   second, the backend third, and the frontend last. Skipping the
   ontology step is not an option.

### Ontology Extensions

The ontology is the root of truth for Odin's domain model. Extending it
means proposing new classes, properties, or relationships — and because
the rest of the system derives from it, getting the ontology right
matters more than getting any particular piece of code right.

Contributions to the ontology must include supporting research. Before
opening an issue:

- Cite the regulatory standards, guidance documents, or authoritative
  references the proposed concepts come from. EPA, OSHA, state-level
  agency citations, and consensus standards (ANSI, ISO) all qualify;
  vendor whitepapers and blog posts generally do not.
- Describe concrete scenarios the extension needs to represent. "We
  should model X" is not sufficient; "a facility that does Y needs to
  record Z because regulation W requires it" is.
- If you are extending an existing axis (hazard type, action context,
  contextual condition), explain how your addition fits the existing
  classification rather than duplicating it.

For context on the ontology's architecture and the research methodology
behind it, see the paper
*The Compliance Routing Problem — A Practitioner-Built Ontology for
Multi-Agency EHS Navigation* referenced in `docs/ontology/README.md`.
Proposals that align with the paper's three-axis routing model are
easier to evaluate than proposals that work around it.

Ontology changes are validated in Protege before they are translated into
SQL. If you are not set up to validate in Protege, the maintainer can do
that step; just be clear in the issue about which parts of the proposal
you can test and which need help.

### Migrations

Migrations are forward-only in practice. Once a migration has shipped in
a released version — or, pre-release, once it has been merged — it
cannot be edited. It can only be superseded by a later migration. New
migrations must be safe against existing data, and they must be tested
against a database that was created by an earlier version of Odin, not
just a freshly seeded database.

The EHS schema migrations in `docs/database-design/sql/` and the
application migrations in `embed/migrations/` use separate numbering
sequences and run independently at startup. A contribution that needs
changes to both should explain why in the PR description; most
contributions touch only one.

Migration numbering follows the existing convention. Do not reuse or
rearrange numbers.

## Development Setup

Odin is a Go backend that embeds a React frontend. Development typically
means running both concurrently.

### Backend

Requirements:

- Go 1.26 or later
- A Unix-like environment or Windows for OS-level authentication testing

Build and run the backend alone:

```bash
go build ./cmd/odin
./odin
```

Run the backend's tests:

```bash
go test ./...
```

The backend stores data in the platform-default directory
(`~/.local/share/odin/` on Linux, `~/Library/Application Support/odin/`
on macOS, `%APPDATA%\odin\` on Windows). Override with `ODIN_DATA_DIR`
when working on database code so you can blow away test state without
touching your real data:

```bash
ODIN_DATA_DIR=/tmp/odin-dev go run ./cmd/odin
```

### Frontend

Requirements:

- Bun (`bun.sh`) — the project uses Bun for package management and build

Install dependencies and run the frontend dev server:

```bash
cd frontend
bun install
bun run dev
```

The Vite dev server runs at `localhost:5173` and proxies `/api/*` to the
backend at `odin.localhost:8080`. For most frontend work, run both
concurrently:

```bash
make dev
```

This starts the Go backend and the Vite dev server in one command, with
coordinated shutdown on `Ctrl+C`.

## What Makes a Good PR

A pull request is more likely to be accepted quickly if it:

- Has a clear, narrow scope — one change per PR, not five
- Preserves the no-CGO dependency posture (Odin uses `ncruces/go-sqlite3`
  for a reason)
- Keeps the JSON API backwards-compatible unless the change is part of an
  agreed breaking-change release
- Includes tests for backend behavior changes, not just code changes
- Does not regress existing module pages or shared components
- Updates the relevant plan document in `docs/plans/` if it implements or
  changes part of a planned feature

Pull requests that bundle a bug fix with a refactor with a new feature
will be asked to split before review. Not because the work is unwelcome,
but because reviewing bundled changes is harder and slower, and each piece
deserves its own decision.

### Backend Conventions

New backend code follows the existing layering:

- One file per domain entity in `internal/repository/` (e.g., `chemical.go`,
  `incident.go`)
- HTTP handlers stay thin — reads in `internal/server/api.go`, writes in
  `internal/server/api_write.go`, both delegating to the repository layer
- All mutations go through `audit.Store` so they land in the git audit
  trail
- Test files sit next to the code they test (`_test.go` alongside the
  implementation)

### Frontend Conventions

New frontend code **must** follow the established patterns. These are
enforced in review:

- **Module pages follow the List → Detail → Form triplet.** A new module
  ships three pages: `{Entity}List.tsx`, `{Entity}Detail.tsx`, and
  `{Entity}Form.tsx`, all under `src/pages/modules/`. This is the shape
  every existing module follows; deviations should be discussed in an
  issue before code.
- **Use the shared components.** Lists use `DataTable`. Forms use
  `FormField`, `SectionCard`, `FormActions`, and `EntitySelector` for
  relation pickers. Detail pages use `DetailSection` and `AuditHistory`.
  Confirmations use `ConfirmDialog`. Status pills use `StatusBadge`.
  If a new component is genuinely needed, propose it as a shared
  component in an issue rather than inlining a one-off.
- **Use the shared hooks.** Data fetching uses `useApi`. Mutations use
  `useEntityMutation`. Forms with unsaved state use `useUnsavedGuard`.
  Rolling a new hook that duplicates these will be asked to remove it.
- **Follow the folder structure.** Module pages live under
  `src/pages/modules/`. Admin pages under `src/pages/admin/`. Shared
  components under `src/components/` (or `src/components/forms/` for
  form-specific components). Hooks under `src/hooks/`. Don't create
  sibling directories to the existing ones without a reason.
- **Keep page files as thin compositions.** Business logic belongs in
  hooks or in the backend. A module page that grows past a screen of
  code usually needs something extracted.

These conventions exist because every existing module follows them and
users benefit from the consistency. A module page that deviates stands
out, and not in a good way.

## Commits and PRs

Commit messages follow the Asgard EHS project conventions, which are also
documented in the
[brand guidelines](https://asgardehs.github.io/docs/brand/#voice-and-tone):

- Imperative mood: "Add emissions module frontend," not "Added" or "Adds"
- Present tense
- Summary line under 72 characters
- If the change is not self-explanatory, a blank line followed by a
  paragraph that explains why — not what, since the diff shows what

Pull request descriptions should link to the issue they address (if one
exists), summarize the change in one or two sentences, and call out
anything a reviewer should pay particular attention to. For module and
ontology changes, the PR description should also link to the plan
document in `docs/plans/` if one exists. PRs that are simply labeled
"fix bug" or "update code" will be asked for more context before review.

## Code of Conduct

Participation in this project is governed by the
[Asgard EHS Code of Conduct](CODE_OF_CONDUCT.md). By contributing, you
agree to uphold its expectations.

## License

Odin is licensed under GPL-3.0. Contributions are accepted under the same
license. By submitting a pull request, you confirm that you have the
right to submit the code and that you agree to license it under GPL-3.0.
