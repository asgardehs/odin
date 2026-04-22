//go:build !ratatoskr_embed

// Stub implementation for builds without `-tags ratatoskr_embed`. The
// embedded Python distribution isn't linked in, so New() always returns
// an error directing the caller to rebuild with the tag. Importers
// (internal/server/api_import.go) handle the error gracefully and keep
// the CSV import path functional.

package ratatoskr

import "fmt"

// New always fails without the ratatoskr_embed build tag. The matching
// symbol in ratatoskr_embed.go does the real work; this keeps a
// consistent signature so the rest of odin compiles either way.
func New() (*XLSX, error) {
	return nil, fmt.Errorf("ratatoskr: XLSX parser unavailable (rebuild odin with -tags ratatoskr_embed)")
}
