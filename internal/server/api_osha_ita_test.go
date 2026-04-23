package server

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/asgardehs/odin/internal/auth"
)

// seedITAFixture inserts a minimally-complete establishment (with the
// ITA fields populated) so the /api/osha/ita/* routes have something to
// return. Returns the establishment ID.
func seedITAFixture(t *testing.T, tc *testContext) int64 {
	t.Helper()
	// Update the pre-seeded establishment (id=1) to carry ITA fields.
	if err := tc.srv.db.ExecParams(
		`UPDATE establishments
		    SET ein = ?, company_name = ?, size_code = ?, establishment_type_code = ?,
		        annual_avg_employees = ?, total_hours_worked = ?
		  WHERE id = ?`,
		"12-3456789", "Test Holdings", "LARGE", "PRIVATE",
		300, 600000, 1,
	); err != nil {
		t.Fatalf("seed ITA establishment fields: %v", err)
	}

	// Insert one recordable incident so the detail CSV has a row.
	if err := tc.srv.db.ExecParams(
		`INSERT INTO incidents (establishment_id, incident_date, incident_description,
		        severity_code, case_classification_code, case_number)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		1, "2025-04-10",
		"Chemical burn to forearm during transfer.",
		"MEDICAL_TX", "INJURY", "2025-001",
	); err != nil {
		t.Fatalf("seed incident: %v", err)
	}
	return 1
}

// nonAdminToken creates a second user with role="user" and returns a
// valid session token for them. The authRequest helper on testContext
// hands out the admin token by default; this bypasses that.
func nonAdminToken(t *testing.T, tc *testContext) string {
	t.Helper()
	userStore := auth.NewUserStore(tc.srv.db)
	sessionStore := auth.NewSessionStore(tc.srv.db, 24*time.Hour)
	uid, err := userStore.Create(auth.UserInput{
		Username:    "observer",
		DisplayName: "Regular Observer",
		Password:    "observepass",
		Role:        "user",
	})
	if err != nil {
		t.Fatalf("create non-admin user: %v", err)
	}
	token, err := sessionStore.Create(uid, "127.0.0.1")
	if err != nil {
		t.Fatalf("create non-admin session: %v", err)
	}
	return token
}

// --- Happy path ---

func TestITADetailCSV_AdminGet(t *testing.T) {
	tc := newTestServerWithDB(t)
	seedITAFixture(t, tc)

	req := httptest.NewRequest("GET", "/api/osha/ita/detail.csv?establishment_id=1&year=2025", nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d; body: %s", w.Code, w.Body.String())
	}
	if ct := w.Header().Get("Content-Type"); !strings.HasPrefix(ct, "text/csv") {
		t.Errorf("Content-Type = %q, want text/csv prefix", ct)
	}
	if cd := w.Header().Get("Content-Disposition"); !strings.Contains(cd, "osha-ita-detail-1-2025.csv") {
		t.Errorf("Content-Disposition = %q, want filename osha-ita-detail-1-2025.csv", cd)
	}
	body := w.Body.String()
	if !strings.HasPrefix(body, "establishment_name,year_of_filing,") {
		t.Errorf("body does not start with expected header; got: %.80q", body)
	}
	// 1 seeded recordable → header + 1 data row.
	if got := strings.Count(body, "\n"); got < 2 {
		t.Errorf("body has %d newlines, want >= 2 (header + 1 row)", got)
	}
}

func TestITASummaryCSV_AdminGet(t *testing.T) {
	tc := newTestServerWithDB(t)
	seedITAFixture(t, tc)

	req := httptest.NewRequest("GET", "/api/osha/ita/summary.csv?establishment_id=1&year=2025", nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d; body: %s", w.Code, w.Body.String())
	}
	body := w.Body.String()
	if !strings.HasPrefix(body, "establishment_name,ein,company_name,") {
		t.Errorf("body does not start with expected header; got: %.80q", body)
	}
}

func TestITAPreview_AdminGet(t *testing.T) {
	tc := newTestServerWithDB(t)
	seedITAFixture(t, tc)

	req := httptest.NewRequest("GET", "/api/osha/ita/preview?establishment_id=1&year=2025", nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d; body: %s", w.Code, w.Body.String())
	}
	body := w.Body.String()
	// Smoke-check a few expected fields in the JSON response.
	for _, want := range []string{
		`"detail_row_count":1`,
		`"establishment_known":true`,
		`"no_injuries_illnesses":"N"`,
	} {
		if !strings.Contains(body, want) {
			t.Errorf("preview missing %s in body: %s", want, body)
		}
	}
}

// --- Auth enforcement ---

func TestITAExport_RejectsNonAdmin(t *testing.T) {
	tc := newTestServerWithDB(t)
	seedITAFixture(t, tc)
	userToken := nonAdminToken(t, tc)

	paths := []string{
		"/api/osha/ita/detail.csv?establishment_id=1&year=2025",
		"/api/osha/ita/summary.csv?establishment_id=1&year=2025",
		"/api/osha/ita/preview?establishment_id=1&year=2025",
	}
	for _, p := range paths {
		req := httptest.NewRequest("GET", p, nil)
		req.Header.Set("Authorization", "Bearer "+userToken)
		w := httptest.NewRecorder()
		tc.srv.mux.ServeHTTP(w, req)
		if w.Code != http.StatusForbidden {
			t.Errorf("%s as non-admin = %d, want 403", p, w.Code)
		}
	}
}

func TestITAExport_RejectsUnauthenticated(t *testing.T) {
	tc := newTestServerWithDB(t)
	seedITAFixture(t, tc)

	req := httptest.NewRequest("GET", "/api/osha/ita/detail.csv?establishment_id=1&year=2025", nil)
	// No Authorization header.
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	// requireAdmin upstream calls requireAuth first; unauthenticated
	// requests get 401, not 403.
	if w.Code != http.StatusUnauthorized {
		t.Errorf("unauthenticated = %d, want 401", w.Code)
	}
}

// --- Parameter validation ---

func TestITAExport_RejectsBadParams(t *testing.T) {
	tc := newTestServerWithDB(t)

	tests := []struct {
		name string
		path string
	}{
		{"missing establishment_id", "/api/osha/ita/detail.csv?year=2025"},
		{"non-numeric establishment_id", "/api/osha/ita/detail.csv?establishment_id=abc&year=2025"},
		{"negative establishment_id", "/api/osha/ita/detail.csv?establishment_id=-1&year=2025"},
		{"missing year", "/api/osha/ita/detail.csv?establishment_id=1"},
		{"non-numeric year", "/api/osha/ita/detail.csv?establishment_id=1&year=abcd"},
		{"3-digit year", "/api/osha/ita/detail.csv?establishment_id=1&year=202"},
	}
	for _, tt := range tests {
		req := httptest.NewRequest("GET", tt.path, nil)
		tc.authRequest(req)
		w := httptest.NewRecorder()
		tc.srv.mux.ServeHTTP(w, req)
		if w.Code != http.StatusBadRequest {
			t.Errorf("%s: status = %d, want 400; body: %s", tt.name, w.Code, w.Body.String())
		}
	}
}
