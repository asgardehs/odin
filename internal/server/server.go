package server

import (
	"context"
	"encoding/json"
	"io/fs"
	"net/http"
	"time"

	"github.com/asgardehs/odin/internal/audit"
	"github.com/asgardehs/odin/internal/auth"
	"github.com/asgardehs/odin/internal/database"
	"github.com/asgardehs/odin/internal/repository"
)

// Server is the Odin HTTP server.
type Server struct {
	mux             *http.ServeMux
	frontend        fs.FS
	audit           *audit.Store
	auth            auth.Authenticator
	db              *database.DB
	repo            *repository.Repo
	users           *auth.UserStore
	sessions        *auth.SessionStore
	recovery        *auth.RecoveryStore
	limiter         *RateLimiter
	stopLimiter     context.CancelFunc
}

// New creates a server that serves the embedded frontend and API routes.
func New(frontend fs.FS, authenticator auth.Authenticator, auditStore *audit.Store, db *database.DB, users *auth.UserStore, sessions *auth.SessionStore, recovery *auth.RecoveryStore) *Server {
	var repo *repository.Repo
	if db != nil && auditStore != nil {
		repo = &repository.Repo{DB: db, Audit: auditStore}
	}
	s := &Server{
		mux:      http.NewServeMux(),
		frontend: frontend,
		audit:    auditStore,
		auth:     authenticator,
		db:       db,
		repo:     repo,
		users:    users,
		sessions: sessions,
		recovery: recovery,
		// 5 tokens, 1 token earned per 12 seconds (≈5 attempts/minute).
		limiter: NewRateLimiter(5, 12*time.Second),
	}
	// Start the rate-limiter stale-bucket cleanup with a cancellable context
	// so it can be stopped cleanly (tests, graceful shutdown).
	limiterCtx, limiterCancel := context.WithCancel(context.Background())
	s.stopLimiter = limiterCancel
	go s.limiter.startCleanupLoop(limiterCtx)
	s.routes()
	return s
}

// Shutdown stops background goroutines started by New. Safe to call multiple times.
func (s *Server) Shutdown() {
	if s.stopLimiter != nil {
		s.stopLimiter()
	}
}

// ListenAndServe starts the HTTP server.
func (s *Server) ListenAndServe(addr string) error {
	return http.ListenAndServe(addr, s.mux)
}

// routes registers all HTTP routes.
func (s *Server) routes() {
	// System routes.
	s.mux.HandleFunc("GET /api/health", s.handleHealth)
	s.mux.HandleFunc("POST /api/auth/verify", s.handleAuthVerify)
	s.mux.HandleFunc("GET /api/auth/whoami", s.handleWhoAmI)
	s.mux.HandleFunc("GET /api/audit/{module}/{entityID}", s.handleAuditHistory)
	s.mux.HandleFunc("POST /api/audit/export", s.handleAuditExport)

	// Application auth routes.
	// Login, reset-password, and recover are rate-limited (per-IP token bucket)
	// to prevent brute-force attacks.
	s.mux.HandleFunc("POST /api/auth/login", s.rateLimited(s.handleLogin))
	s.mux.HandleFunc("POST /api/auth/logout", s.handleLogout)
	s.mux.HandleFunc("POST /api/auth/setup", s.handleSetup)
	s.mux.HandleFunc("GET /api/auth/me", s.handleMe)

	// Self-service password reset via security questions.
	s.mux.HandleFunc("POST /api/auth/security-questions", s.handleSetSecurityQuestions)
	s.mux.HandleFunc("GET /api/auth/security-questions/{username}", s.handleGetSecurityQuestions)
	s.mux.HandleFunc("POST /api/auth/reset-password", s.rateLimited(s.handleResetPassword))

	// Disaster recovery — recovery key generated at setup, used to
	// regain admin access when all passwords are lost.
	s.mux.HandleFunc("POST /api/auth/recover", s.rateLimited(s.handleRecover))
	s.mux.HandleFunc("POST /api/auth/regenerate-recovery-key", s.handleRegenerateRecoveryKey)

	// User management routes (admin only).
	s.mux.HandleFunc("GET /api/users", s.handleListUsers)
	s.mux.HandleFunc("POST /api/users", s.handleCreateUser)
	s.mux.HandleFunc("GET /api/users/{id}", s.handleGetUser)
	s.mux.HandleFunc("PUT /api/users/{id}", s.handleUpdateUser)
	s.mux.HandleFunc("POST /api/users/{id}/deactivate", s.handleDeactivateUser)
	s.mux.HandleFunc("POST /api/users/{id}/reactivate", s.handleReactivateUser)
	s.mux.HandleFunc("POST /api/users/{id}/password", s.handleSetUserPassword)

	// Data API routes (requires database).
	s.apiRoutes()
	s.writeRoutes()

	// Frontend: serve embedded SPA. Non-file paths fall back to index.html
	// so React Router can handle client-side routes.
	s.mux.Handle("/", spaHandler(s.frontend))
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok"}`))
}

// handleAuthVerify checks OS credentials. Returns 200 on success, 401 on failure.
func (s *Server) handleAuthVerify(w http.ResponseWriter, r *http.Request) {
	creds, ok := extractBasicAuth(r)
	if !ok {
		http.Error(w, `{"error":"missing credentials"}`, http.StatusUnauthorized)
		return
	}

	if err := s.auth.Verify(creds.Username, creds.Password); err != nil {
		http.Error(w, `{"error":"invalid credentials"}`, http.StatusUnauthorized)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok"}`))
}

// handleWhoAmI returns the OS username of the process owner.
func (s *Server) handleWhoAmI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"user": s.auth.CurrentUser(),
	})
}

// handleAuditHistory returns the audit trail for a specific entity.
// Requires Basic Auth — the audit store re-verifies credentials.
func (s *Server) handleAuditHistory(w http.ResponseWriter, r *http.Request) {
	creds, ok := extractBasicAuth(r)
	if !ok {
		http.Error(w, `{"error":"audit access requires authentication"}`, http.StatusUnauthorized)
		return
	}

	module := r.PathValue("module")
	entityID := r.PathValue("entityID")

	entries, err := s.audit.History(module, entityID, creds)
	if err != nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(entries)
}

// exportRequest is the JSON body for the audit export endpoint.
type exportRequest struct {
	Start string `json:"start"` // RFC 3339
	End   string `json:"end"`   // RFC 3339
}

// handleAuditExport returns all audit entries in a date range.
// Requires Basic Auth.
func (s *Server) handleAuditExport(w http.ResponseWriter, r *http.Request) {
	creds, ok := extractBasicAuth(r)
	if !ok {
		http.Error(w, `{"error":"audit access requires authentication"}`, http.StatusUnauthorized)
		return
	}

	var req exportRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	start, err := time.Parse(time.RFC3339, req.Start)
	if err != nil {
		http.Error(w, `{"error":"invalid start time"}`, http.StatusBadRequest)
		return
	}
	end, err := time.Parse(time.RFC3339, req.End)
	if err != nil {
		http.Error(w, `{"error":"invalid end time"}`, http.StatusBadRequest)
		return
	}

	entries, err := s.audit.Export(start, end, creds)
	if err != nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(entries)
}

// extractBasicAuth pulls credentials from the Authorization header.
func extractBasicAuth(r *http.Request) (auth.Credentials, bool) {
	username, password, ok := r.BasicAuth()
	if !ok {
		return auth.Credentials{}, false
	}
	return auth.Credentials{Username: username, Password: password}, true
}

// spaHandler serves static files from the FS, falling back to index.html
// for paths that don't match a file (client-side routing).
func spaHandler(content fs.FS) http.Handler {
	fileServer := http.FileServer(http.FS(content))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Try to serve the file directly.
		path := r.URL.Path
		if path == "/" {
			fileServer.ServeHTTP(w, r)
			return
		}

		// Check if the file exists in the embedded FS.
		f, err := content.Open(path[1:]) // strip leading /
		if err == nil {
			f.Close()
			fileServer.ServeHTTP(w, r)
			return
		}

		// File not found — serve index.html for client-side routing.
		r.URL.Path = "/"
		fileServer.ServeHTTP(w, r)
	})
}
