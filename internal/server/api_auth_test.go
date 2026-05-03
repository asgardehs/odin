package server

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/asgardehs/odin/internal/auth"
)

// TestRecover_RejectsNonAdmin guards against re-introducing the
// recovery-flow privilege escalation: possession of a valid recovery key
// must NOT be usable to reset (or elevate) a non-admin account.
func TestRecover_RejectsNonAdmin(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Seed a non-admin user with a known password.
	const (
		regularUsername = "regular"
		originalPass    = "original-password"
		attemptedPass   = "attacker-supplied-password"
	)
	if _, err := tc.users.Create(auth.UserInput{
		Username:    regularUsername,
		DisplayName: "Regular User",
		Password:    originalPass,
		Role:        "user",
	}); err != nil {
		t.Fatalf("seed regular user: %v", err)
	}

	// Generate a valid recovery key.
	recoveryKey, err := tc.recovery.GenerateAndStore()
	if err != nil {
		t.Fatalf("generate recovery key: %v", err)
	}

	// Attempt recovery against the non-admin user.
	body, _ := json.Marshal(map[string]string{
		"recovery_key": recoveryKey,
		"username":     regularUsername,
		"new_password": attemptedPass,
	})
	req := httptest.NewRequest("POST", "/api/auth/recover", bytes.NewReader(body))
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Fatalf("recover non-admin: status = %d, want 403; body: %s", w.Code, w.Body.String())
	}

	// Original password must still work.
	user, err := tc.users.Authenticate(regularUsername, originalPass)
	if err != nil {
		t.Fatalf("authenticate with original password: %v", err)
	}
	if user == nil {
		t.Fatal("original password no longer works — recovery mutated state on a rejected request")
	}

	// Attacker-supplied password must NOT work.
	user, err = tc.users.Authenticate(regularUsername, attemptedPass)
	if err != nil {
		t.Fatalf("authenticate with attempted password: %v", err)
	}
	if user != nil {
		t.Fatal("attacker-supplied password authenticates — non-admin recovery was not actually rejected")
	}

	// Role must still be "user".
	got, err := tc.users.GetByUsername(regularUsername)
	if err != nil {
		t.Fatalf("get regular user: %v", err)
	}
	if got == nil {
		t.Fatal("regular user disappeared")
	}
	if got.Role != "user" {
		t.Fatalf("role = %q, want %q (recovery must not elevate)", got.Role, "user")
	}
}

// TestRecover_AdminHappyPath verifies the recovery flow still works for
// admin accounts after the H-1 fix: recovery resets the password,
// returns a session token, and leaves the role unchanged.
func TestRecover_AdminHappyPath(t *testing.T) {
	tc := newTestServerWithDB(t)

	// The seeded "testuser" is admin (see newTestServerWithDB).
	const (
		adminUsername = "testuser"
		newPass       = "post-recovery-password"
	)

	recoveryKey, err := tc.recovery.GenerateAndStore()
	if err != nil {
		t.Fatalf("generate recovery key: %v", err)
	}

	body, _ := json.Marshal(map[string]string{
		"recovery_key": recoveryKey,
		"username":     adminUsername,
		"new_password": newPass,
	})
	req := httptest.NewRequest("POST", "/api/auth/recover", bytes.NewReader(body))
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("recover admin: status = %d, want 200; body: %s", w.Code, w.Body.String())
	}

	var resp struct {
		Token string     `json:"token"`
		User  *auth.User `json:"user"`
	}
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.Token == "" {
		t.Error("expected session token in response")
	}
	if resp.User == nil || resp.User.Role != "admin" {
		t.Errorf("user role = %v, want admin", resp.User)
	}

	// New password must work.
	user, err := tc.users.Authenticate(adminUsername, newPass)
	if err != nil {
		t.Fatalf("authenticate with new password: %v", err)
	}
	if user == nil {
		t.Fatal("new password does not authenticate after successful recovery")
	}
}

// TestDeactivateUser_RevokesSessions verifies that deactivating a user
// also tears down their active sessions. Guards H-2's error-checking
// fix in handleDeactivateUser by asserting the success path actually
// invalidates session tokens (so an error-swallowing regression would
// be caught by the session surviving deactivation).
func TestDeactivateUser_RevokesSessions(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Seed a regular user and create a live session for them.
	regularID, err := tc.users.Create(auth.UserInput{
		Username:    "soontogo",
		DisplayName: "Soon To Go",
		Password:    "before-deactivation",
		Role:        "user",
	})
	if err != nil {
		t.Fatalf("seed regular user: %v", err)
	}
	regularToken, err := tc.sessions.Create(regularID, "127.0.0.1")
	if err != nil {
		t.Fatalf("create session: %v", err)
	}
	// Sanity: token is valid before deactivation.
	if u, _ := tc.sessions.Validate(regularToken); u == nil {
		t.Fatal("token invalid before deactivation — test scaffold broken")
	}

	// Admin deactivates the user.
	req := httptest.NewRequest("POST", fmt.Sprintf("/api/users/%d/deactivate", regularID), nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("deactivate: status = %d, want 200; body: %s", w.Code, w.Body.String())
	}

	// Token must no longer authenticate.
	if u, _ := tc.sessions.Validate(regularToken); u != nil {
		t.Fatal("session still valid after deactivation — DeleteForUser error was swallowed")
	}
}
