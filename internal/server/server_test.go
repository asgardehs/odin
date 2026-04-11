package server

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"testing/fstest"

	"github.com/asgardehs/odin/internal/audit"
)

// mockAuth accepts any credentials.
type mockAuth struct{ user string }

func (m *mockAuth) Verify(_, _ string) error { return nil }
func (m *mockAuth) CurrentUser() string       { return m.user }

func newTestServer(t *testing.T) *Server {
	t.Helper()

	// Minimal embedded FS with an index.html.
	frontend := fstest.MapFS{
		"index.html": &fstest.MapFile{Data: []byte("<html></html>")},
	}

	a := &mockAuth{user: "testuser"}

	dir := t.TempDir()
	store, err := audit.NewStore(dir, a)
	if err != nil {
		t.Fatalf("NewStore: %v", err)
	}

	return New(frontend, a, store, nil)
}

func TestHealthEndpoint(t *testing.T) {
	srv := newTestServer(t)
	req := httptest.NewRequest("GET", "/api/health", nil)
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", w.Code, http.StatusOK)
	}

	var body map[string]string
	json.NewDecoder(w.Body).Decode(&body)
	if body["status"] != "ok" {
		t.Errorf("body = %v, want status ok", body)
	}
}

func TestWhoAmI(t *testing.T) {
	srv := newTestServer(t)
	req := httptest.NewRequest("GET", "/api/auth/whoami", nil)
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", w.Code, http.StatusOK)
	}

	var body map[string]string
	json.NewDecoder(w.Body).Decode(&body)
	if body["user"] != "testuser" {
		t.Errorf("user = %q, want %q", body["user"], "testuser")
	}
}

func TestAuthVerifyRequiresCredentials(t *testing.T) {
	srv := newTestServer(t)
	req := httptest.NewRequest("POST", "/api/auth/verify", nil)
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

func TestAuthVerifyWithCredentials(t *testing.T) {
	srv := newTestServer(t)
	req := httptest.NewRequest("POST", "/api/auth/verify", nil)
	req.SetBasicAuth("testuser", "password")
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", w.Code, http.StatusOK)
	}
}

func TestAuditHistoryRequiresAuth(t *testing.T) {
	srv := newTestServer(t)
	req := httptest.NewRequest("GET", "/api/audit/incidents/INC-001", nil)
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

func TestAuditHistoryWithAuth(t *testing.T) {
	srv := newTestServer(t)

	// Record an entry first so there's something to query.
	srv.audit.Record(audit.Entry{
		Action:   audit.ActionCreate,
		Module:   "incidents",
		EntityID: "INC-001",
		Summary:  "test incident",
	})

	req := httptest.NewRequest("GET", "/api/audit/incidents/INC-001", nil)
	req.SetBasicAuth("testuser", "password")
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", w.Code, http.StatusOK)
	}

	var entries []audit.HistoryEntry
	json.NewDecoder(w.Body).Decode(&entries)
	if len(entries) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(entries))
	}
}

func TestSPAFallback(t *testing.T) {
	srv := newTestServer(t)
	req := httptest.NewRequest("GET", "/some/client/route", nil)
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", w.Code, http.StatusOK)
	}
}
