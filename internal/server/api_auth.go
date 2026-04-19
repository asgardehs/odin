package server

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/asgardehs/odin/internal/auth"
)

// authenticatedUser extracts and validates a session token from the
// Authorization header (Bearer scheme). Returns the user if valid,
// or nil if unauthenticated.
func (s *Server) authenticatedUser(r *http.Request) *auth.User {
	if s.sessions == nil {
		return nil
	}

	header := r.Header.Get("Authorization")
	if header == "" {
		return nil
	}

	// Support "Bearer <token>" format.
	const prefix = "Bearer "
	if !strings.HasPrefix(header, prefix) {
		return nil
	}
	token := header[len(prefix):]

	user, err := s.sessions.Validate(token)
	if err != nil || user == nil {
		return nil
	}
	return user
}

// requireAuth is a helper that extracts the authenticated user and
// writes a 401 response if missing. Returns the user or nil (with
// response already written).
func (s *Server) requireAuth(w http.ResponseWriter, r *http.Request) *auth.User {
	user := s.authenticatedUser(r)
	if user == nil {
		writeError(w, "authentication required", http.StatusUnauthorized)
		return nil
	}
	return user
}

// requireAdmin is like requireAuth but also checks for admin role.
func (s *Server) requireAdmin(w http.ResponseWriter, r *http.Request) *auth.User {
	user := s.requireAuth(w, r)
	if user == nil {
		return nil
	}
	if user.Role != "admin" {
		writeError(w, "admin access required", http.StatusForbidden)
		return nil
	}
	return user
}

// --- Auth endpoints ---

// handleLogin authenticates with username/password and returns a session token.
func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	if s.users == nil || s.sessions == nil {
		writeError(w, "auth not configured", http.StatusServiceUnavailable)
		return
	}

	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	user, err := s.users.Authenticate(req.Username, req.Password)
	if err != nil {
		writeError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if user == nil {
		writeError(w, "invalid credentials", http.StatusUnauthorized)
		return
	}

	token, err := s.sessions.Create(user.ID, r.RemoteAddr)
	if err != nil {
		writeError(w, "failed to create session", http.StatusInternalServerError)
		return
	}

	writeJSON(w, map[string]any{
		"token": token,
		"user":  user,
	})
}

// handleLogout destroys the current session.
func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	header := r.Header.Get("Authorization")
	if strings.HasPrefix(header, "Bearer ") {
		token := header[len("Bearer "):]
		s.sessions.Delete(token)
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleSetup creates the first admin user. Only works when zero users
// exist — this is the bootstrap endpoint for fresh installs. Also
// generates a recovery key that must be printed and stored securely.
func (s *Server) handleSetup(w http.ResponseWriter, r *http.Request) {
	if s.users == nil {
		writeError(w, "auth not configured", http.StatusServiceUnavailable)
		return
	}

	count, err := s.users.UserCount()
	if err != nil {
		writeError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if count > 0 {
		writeError(w, "setup already complete — users exist", http.StatusConflict)
		return
	}

	var req auth.UserInput
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	req.Role = "admin" // first user is always admin

	id, err := s.users.Create(req)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Auto-login the new admin.
	token, err := s.sessions.Create(id, r.RemoteAddr)
	if err != nil {
		writeError(w, "user created but login failed", http.StatusInternalServerError)
		return
	}

	// Generate the recovery key — this is the ONLY time the plaintext
	// is available. The frontend must prompt the user to print it.
	var recoveryKey string
	if s.recovery != nil {
		recoveryKey, err = s.recovery.GenerateAndStore()
		if err != nil {
			writeError(w, "user created but recovery key generation failed", http.StatusInternalServerError)
			return
		}
	}

	user, _ := s.users.Get(id)
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, map[string]any{
		"token":        token,
		"user":         user,
		"recovery_key": recoveryKey,
	})
}

// handleMe returns the currently authenticated user's profile.
func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}
	writeJSON(w, user)
}

// --- Security question password reset ---

// handleSetSecurityQuestions lets an authenticated user set their 3
// security questions and answers. Requires login — you have to know
// your current password to set recovery questions.
func (s *Server) handleSetSecurityQuestions(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}

	var req auth.SecurityQuestionsInput
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if err := s.users.SetSecurityQuestions(user.ID, req); err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	writeJSON(w, map[string]string{"status": "ok"})
}

// handleGetSecurityQuestions returns the 3 security questions for a
// given username (questions only, never answers). No auth required —
// this is the first step of the self-service reset flow.
func (s *Server) handleGetSecurityQuestions(w http.ResponseWriter, r *http.Request) {
	username := r.PathValue("username")

	questions, err := s.users.GetSecurityQuestions(username)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if questions == nil {
		writeError(w, "no security questions configured for this user", http.StatusNotFound)
		return
	}

	writeJSON(w, map[string]any{"questions": questions})
}

// handleResetPassword verifies 3 security answers (case-sensitive) and
// sets a new password. No auth required — this is the self-service
// reset endpoint. The frontend flow is:
//  1. GET /api/auth/security-questions/{username} → get the 3 questions
//  2. POST /api/auth/reset-password → submit answers + new password
func (s *Server) handleResetPassword(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username    string    `json:"username"`
		Answers     [3]string `json:"answers"`
		NewPassword string    `json:"new_password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if err := s.users.ResetPassword(req.Username, req.Answers, req.NewPassword); err != nil {
		// Don't reveal whether the user exists or which answer was wrong.
		writeError(w, "password reset failed — check your answers", http.StatusUnauthorized)
		return
	}

	writeJSON(w, map[string]string{"status": "ok"})
}

// --- User management endpoints (admin only) ---

func (s *Server) handleListUsers(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}

	users, err := s.users.List()
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, users)
}

func (s *Server) handleCreateUser(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}

	var req auth.UserInput
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	id, err := s.users.Create(req)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	user, _ := s.users.Get(id)
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, user)
}

func (s *Server) handleGetUser(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}

	user, err := s.users.Get(id)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if user == nil {
		writeError(w, "user not found", http.StatusNotFound)
		return
	}
	writeJSON(w, user)
}

func (s *Server) handleUpdateUser(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}

	var req auth.UserInput
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if err := s.users.Update(id, req); err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	user, _ := s.users.Get(id)
	writeJSON(w, user)
}

func (s *Server) handleDeactivateUser(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}

	if err := s.users.Deactivate(id); err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Force logout all sessions for this user.
	s.sessions.DeleteForUser(id)

	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleReactivateUser(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}

	if err := s.users.Reactivate(id); err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleSetUserPassword(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}

	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}

	var req struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if err := s.users.SetPassword(id, req.Password); err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	writeJSON(w, map[string]string{"status": "ok"})
}

// --- Disaster recovery ---

// handleRecover verifies a recovery key and resets the password for an
// admin account. No auth required — this is the last-resort endpoint
// for when all admin passwords are lost.
//
// The recovery key is generated at setup time and should be printed and
// stored physically (e.g. in the facility's emergency binder).
func (s *Server) handleRecover(w http.ResponseWriter, r *http.Request) {
	if s.recovery == nil || s.users == nil || s.sessions == nil {
		writeError(w, "recovery not configured", http.StatusServiceUnavailable)
		return
	}

	var req struct {
		RecoveryKey string `json:"recovery_key"`
		Username    string `json:"username"`
		NewPassword string `json:"new_password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	// Verify the recovery key.
	valid, err := s.recovery.Verify(req.RecoveryKey)
	if err != nil {
		writeError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !valid {
		writeError(w, "invalid recovery key", http.StatusUnauthorized)
		return
	}

	// Find the user to reset.
	user, err := s.users.GetByUsername(req.Username)
	if err != nil {
		writeError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if user == nil {
		writeError(w, "user not found", http.StatusNotFound)
		return
	}

	// Reset password, reactivate if needed, and ensure admin role.
	if err := s.users.SetPassword(user.ID, req.NewPassword); err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Reactivate the user if they were deactivated, and ensure admin role.
	s.users.Update(user.ID, auth.UserInput{
		DisplayName: user.DisplayName,
		Role:        "admin",
	})
	// Force reactivation in case the account was deactivated.
	s.users.Reactivate(user.ID)

	// Invalidate all existing sessions for this user (security measure).
	s.sessions.DeleteForUser(user.ID)

	// Auto-login with the new credentials.
	token, err := s.sessions.Create(user.ID, r.RemoteAddr)
	if err != nil {
		writeError(w, "password reset but login failed", http.StatusInternalServerError)
		return
	}

	refreshedUser, _ := s.users.Get(user.ID)
	writeJSON(w, map[string]any{
		"token": token,
		"user":  refreshedUser,
	})
}

// handleRegenerateRecoveryKey generates a new recovery key, replacing
// the old one. Admin only — use this if the old key was lost while
// someone with admin access is still around.
func (s *Server) handleRegenerateRecoveryKey(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}

	if s.recovery == nil {
		writeError(w, "recovery not configured", http.StatusServiceUnavailable)
		return
	}

	key, err := s.recovery.GenerateAndStore()
	if err != nil {
		writeError(w, "failed to generate recovery key", http.StatusInternalServerError)
		return
	}

	writeJSON(w, map[string]any{
		"recovery_key": key,
	})
}
