# Bifrost Windows transport, AI config, and service registry

**Date:** 2026-04-05
**Project(s):** bifrost

## Goal

Get Bifrost's IPC working on Windows, add AI opt-in configuration to Heimdall, and start the service registry.

## What happened

- **Windows named pipe support** — abstracted transport behind build-tagged `PlatformListen` (listener_unix.go / listener_windows.go) and `platform.Dial` (dial_unix.go / dial_windows.go). Added `go-winio` dependency. Both `go build` and `GOOS=windows go vet` pass clean.
- **AI opt-in config** — new `ai` namespace in Heimdall with 6 keys: `enabled` (boolean, default false), `provider` (enum: anthropic/openai), `api_key` (secret, masked in CLI), `odin_access`, `muninn_access`, `huginn_access` (arrays). Two new schema types: `secret` (display masking) and `enum` (validated choices via `choices` column on config_schema). AI config changes broadcast to all connected services.
- **Service registry** — new `internal/registry/` package. `bifrost.register`, `bifrost.deregister`, `bifrost.services` RPC methods. Auto-deregistration on connection drop via disconnect callback on the RPC server. Event broadcasting for service registered/gone.
- Opened PR asgardehs/bifrost#7 linking issues #1 (service registry) and #4 (Windows named pipes). Merged to main.

## Decisions

- **`secret` type is a display hint, not encryption** — API keys stored as plaintext in local SQLite. Acceptable for v1 since it's local-only with filesystem permissions. OS keyring is a future enhancement.
- **`ai` namespace is user-writable only** — no tool can write to it (namespace enforcement). Tools read AI config, users control it via CLI.
- **Disconnect callback over interface** — simple `func(connID string)` on the RPC server rather than a `DisconnectHandler` interface. Only one consumer (registry) needs it.
- **`ServiceInfo` vs `ServiceEntry`** — public-facing RPC results strip `ConnID` (internal implementation detail).

## Open threads

- **Message routing (asgardehs/bifrost#2)** — next up. Method-prefix routing to proxy RPC calls between tools. Depends on registry (now done).
- **Discovery and health monitoring (asgardehs/bifrost#3)** — data model accommodates it (`LastHealthy`, `Status`) but no goroutines yet.
