# Tech Stack

## Frontend

- React + TypeScript
- Vite (dev server + bundler)
- React Router
- TanStack Table
- Tailwind CSS
- Nótt & Dagr theme package (shared across the Asgard ecosystem)

## Backend

- Go (stdlib `net/http`, no framework)
- Embedded frontend bundle for single-binary deploy

## Database

- SQLite via `ncruces/go-sqlite3` (zero CGO required)
- One-shot module migrations + forward-only deltas for additive
  schema changes on existing DBs
- View definitions re-executed on every startup so schema-derived
  surfaces stay in sync without a DB reset

## Other

- PAM authentication
- Git-backed audit log
- GitHub Actions CI; push-mirror to GitLab on every push to main
