package odin

import "embed"

// SchemaSQL contains the EHS database schema modules.
//
//go:embed docs/database-design/sql/module_*.sql
var SchemaSQL embed.FS

// AppMigrations contains application-level migrations (auth, config, etc.)
// that are separate from the EHS domain schemas.
//
//go:embed embed/migrations/*.sql
var AppMigrations embed.FS
