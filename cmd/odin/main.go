package main

import (
	"context"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
	"time"

	odin "github.com/asgardehs/odin"
	"github.com/asgardehs/odin/internal/audit"
	"github.com/asgardehs/odin/internal/auth"
	"github.com/asgardehs/odin/internal/database"
	"github.com/asgardehs/odin/internal/server"
)

var version = "dev"

func main() {
	// Extract the dist/ subdirectory from the embedded FS.
	dist, err := fs.Sub(odin.FrontendDist, "frontend/dist")
	if err != nil {
		log.Fatalf("embedded frontend not found: %v", err)
	}

	// Set up OS-level authenticator.
	authenticator := newAuthenticator()

	// Set up data directory.
	dataDir, err := odinDataDir()
	if err != nil {
		log.Fatalf("data directory: %v", err)
	}

	// Open EHS database and run schema migrations.
	sqlFS, err := fs.Sub(odin.SchemaSQL, "docs/database-design/sql")
	if err != nil {
		log.Fatalf("embedded schema not found: %v", err)
	}
	migrations, err := database.CollectMigrations(sqlFS)
	if err != nil {
		log.Fatalf("collect migrations: %v", err)
	}
	db, err := database.Open(filepath.Join(dataDir, "odin.db"))
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer db.Close()
	if err := database.Migrate(db, migrations); err != nil {
		log.Fatalf("migrate: %v", err)
	}

	// Run application-level migrations (auth tables, etc.).
	appMigFS, err := fs.Sub(odin.AppMigrations, "embed/migrations")
	if err != nil {
		log.Fatalf("embedded app migrations not found: %v", err)
	}
	appMigrations, err := database.CollectAppMigrations(appMigFS)
	if err != nil {
		log.Fatalf("collect app migrations: %v", err)
	}
	if err := database.Migrate(db, appMigrations); err != nil {
		log.Fatalf("app migrate: %v", err)
	}

	// Apply forward-only schema deltas (one-shot, tracked in _migrations).
	// Catches existing DBs up to the current schema when module files
	// change after initial apply.
	deltaFS, err := fs.Sub(odin.SchemaDeltas, "docs/database-design/sql/deltas")
	if err != nil {
		log.Fatalf("embedded deltas not found: %v", err)
	}
	if err := database.ApplyDeltas(db, deltaFS); err != nil {
		log.Fatalf("apply deltas: %v", err)
	}

	// Load (re-create) all views. Runs on every startup so pulled
	// changes to view bodies take effect without a DB reset.
	viewsFS, err := fs.Sub(odin.SchemaViews, "docs/database-design/sql/views")
	if err != nil {
		log.Fatalf("embedded views not found: %v", err)
	}
	if err := database.LoadViews(db, viewsFS); err != nil {
		log.Fatalf("load views: %v", err)
	}

	// Set up git-backed audit trail.
	auditStore, err := audit.NewStore(filepath.Join(dataDir, "audit"), authenticator)
	if err != nil {
		log.Fatalf("audit store: %v", err)
	}

	// Set up application-level user and session stores.
	userStore := auth.NewUserStore(db)
	sessionStore := auth.NewSessionStore(db, 24*time.Hour)
	recoveryStore := auth.NewRecoveryStore(db)

	// Background context for long-lived goroutines; cancelled on shutdown.
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Periodic session cleanup — removes expired sessions every 15 minutes.
	// Also runs once immediately on startup.
	go sessionStore.StartCleanupLoop(ctx, 15*time.Minute)

	addr := "odin.localhost:8080"
	srv := server.New(dist, authenticator, auditStore, db, userStore, sessionStore, recoveryStore)

	// Graceful shutdown on interrupt.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		fmt.Printf("Odin %s listening on http://%s\n", version, addr)
		if err := srv.ListenAndServe(addr); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()

	// Open browser after server starts.
	go openBrowser("http://" + addr)

	<-stop
	fmt.Println("\nShutting down.")
	srv.Shutdown()
}

// openBrowser launches the user's default browser.
func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "linux":
		cmd = exec.Command("xdg-open", url)
	case "darwin":
		cmd = exec.Command("open", url)
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	}
	if cmd != nil {
		cmd.Start()
	}
}
