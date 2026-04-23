package odin

import "embed"

// SchemaSQL contains the EHS database schema modules.
//
//go:embed docs/database-design/sql/module_*.sql
var SchemaSQL embed.FS

// SchemaViews contains view definitions re-executed on every startup by
// database.LoadViews. Separate from SchemaSQL because migrations run
// once (tracked in _migrations) while views must update whenever their
// SQL body changes.
//
//go:embed docs/database-design/sql/views/*.sql
var SchemaViews embed.FS

// AppMigrations contains application-level migrations (auth, config, etc.)
// that are separate from the EHS domain schemas.
//
//go:embed embed/migrations/*.sql
var AppMigrations embed.FS
