package odin

import "embed"

// FrontendDist contains the built React app (frontend/dist/).
//
//go:embed all:frontend/dist
var FrontendDist embed.FS
