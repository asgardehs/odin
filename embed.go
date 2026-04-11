package odin

import "embed"

// SchemaSQL contains the EHS database schema modules.
//
//go:embed docs/database-design/sql/module_*.sql
var SchemaSQL embed.FS
