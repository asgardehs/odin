SHELL := /bin/bash

# Ratatoskr ships its embedded Python distribution behind this build tag;
# XLSX imports only work when the binary is built with it set.
GOTAGS := ratatoskr_embed

.PHONY: dev build clean test

# Start Go backend (odin.localhost:8080) and Vite dev server (localhost:5173) concurrently.
# The Vite proxy forwards /api/* to the backend automatically.
# Press Ctrl+C to stop both processes.
dev:
	@trap 'kill $$BGPID 2>/dev/null; wait $$BGPID 2>/dev/null' EXIT INT TERM; \
	go run -tags $(GOTAGS) ./cmd/odin & BGPID=$$!; \
	echo "Backend starting at http://odin.localhost:8080 (PID $$BGPID)"; \
	sleep 1; \
	cd frontend && bun run dev

# Build frontend assets then compile the Go binary with all assets embedded.
build:
	cd frontend && bun run build
	go build -tags $(GOTAGS) -o odin ./cmd/odin

test:
	go test -tags $(GOTAGS) ./...

clean:
	rm -f odin
	rm -rf frontend/dist
