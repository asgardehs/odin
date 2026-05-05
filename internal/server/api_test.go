package server

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"testing"
	"testing/fstest"
	"time"

	"github.com/asgardehs/odin/internal/audit"
	"github.com/asgardehs/odin/internal/auth"
	"github.com/asgardehs/odin/internal/database"
)

// testContext holds a test server + session token for authenticated requests.
type testContext struct {
	srv      *Server
	token    string
	users    *auth.UserStore
	sessions *auth.SessionStore
	recovery *auth.RecoveryStore
}

// authRequest adds the test session token to a request.
func (tc *testContext) authRequest(req *http.Request) *http.Request {
	req.Header.Set("Authorization", "Bearer "+tc.token)
	return req
}

// newTestServerWithDB creates a server backed by an in-memory database
// with all EHS schema modules and auth tables applied, a seeded test
// user, and a valid session token.
func newTestServerWithDB(t *testing.T) *testContext {
	t.Helper()

	frontend := fstest.MapFS{
		"index.html": &fstest.MapFile{Data: []byte("<html></html>")},
	}
	a := &mockAuth{user: "testuser"}
	auditDir := t.TempDir()
	store, err := audit.NewStore(auditDir, a)
	if err != nil {
		t.Fatalf("NewStore: %v", err)
	}

	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	// Apply EHS schema migrations.
	sqlDir := os.DirFS("../../docs/database-design/sql")
	migrations, err := database.CollectMigrations(sqlDir)
	if err != nil {
		t.Fatalf("collect: %v", err)
	}
	if err := database.Migrate(db, migrations); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	// Deltas run after modules in prod; mirror that order here.
	deltaDir := os.DirFS("../../docs/database-design/sql/deltas")
	if err := database.ApplyDeltas(db, deltaDir); err != nil {
		t.Fatalf("apply deltas: %v", err)
	}
	// Views re-loaded on every startup in prod; mirror that here so
	// exporter / lookup / route tests hit the widened shape.
	viewsDir := os.DirFS("../../docs/database-design/sql/views")
	if err := database.LoadViews(db, viewsDir); err != nil {
		t.Fatalf("load views: %v", err)
	}

	// Apply app migrations (auth, schema-builder metadata, etc.) in
	// alphabetical order so tests mirror the production bootstrap.
	appMigDir := os.DirFS("../../embed/migrations")
	appMigrations, err := database.CollectAppMigrations(appMigDir)
	if err != nil {
		t.Fatalf("collect app migrations: %v", err)
	}
	for _, m := range appMigrations {
		if err := db.Exec(m.SQL); err != nil {
			t.Fatalf("app migration %s: %v", m.Name, err)
		}
	}

	// Seed a test establishment so FK-dependent queries work.
	if err := db.ExecParams(
		`INSERT INTO establishments (id, name, street_address, city, state, zip, naics_code)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		1, "Test Facility", "123 Industrial Pkwy", "Springfield", "IL", "62701", "325199",
	); err != nil {
		t.Fatalf("seed establishment: %v", err)
	}

	// Create user and session stores, seed a test user and session.
	userStore := auth.NewUserStore(db)
	sessionStore := auth.NewSessionStore(db, 24*time.Hour)

	userID, err := userStore.Create(auth.UserInput{
		Username:    "testuser",
		DisplayName: "Test User",
		Password:    "testpass",
		Role:        "admin",
	})
	if err != nil {
		t.Fatalf("create test user: %v", err)
	}

	token, err := sessionStore.Create(userID, "127.0.0.1")
	if err != nil {
		t.Fatalf("create test session: %v", err)
	}

	recoveryStore := auth.NewRecoveryStore(db)
	srv := New(frontend, a, store, db, userStore, sessionStore, recoveryStore)
	return &testContext{
		srv:      srv,
		token:    token,
		users:    userStore,
		sessions: sessionStore,
		recovery: recoveryStore,
	}
}

// TestListSearchFilter verifies that ?q= filters results on configured
// search columns. Creates three employees and asserts that matching
// last_name and employee_number narrow the result set.
func TestListSearchFilter(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Seed three employees; none match "zebra", two match "son".
	seedEmp := func(empNum, first, last string) {
		body := bytes.NewBufferString(`{"establishment_id":1,"employee_number":"` + empNum +
			`","first_name":"` + first + `","last_name":"` + last + `"}`)
		req := httptest.NewRequest("POST", "/api/employees", body)
		tc.authRequest(req)
		w := httptest.NewRecorder()
		tc.srv.mux.ServeHTTP(w, req)
		if w.Code != http.StatusCreated {
			t.Fatalf("seed %s %s: %d; %s", first, last, w.Code, w.Body.String())
		}
	}
	seedEmp("E001", "Ada", "Anderson")
	seedEmp("E002", "Ben", "Johnson")
	seedEmp("E003", "Cara", "Jefferson")

	cases := []struct {
		q    string
		want int
	}{
		{"zebra", 0},
		{"son", 3},  // Anderson + Johnson + Jefferson all contain "son"
		{"John", 1}, // Johnson only
		{"Ada", 1},  // first_name match
		{"E002", 1}, // employee_number match
	}
	for _, tc2 := range cases {
		t.Run(tc2.q, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/api/employees?q="+tc2.q, nil)
			w := httptest.NewRecorder()
			tc.srv.mux.ServeHTTP(w, req)
			if w.Code != http.StatusOK {
				t.Fatalf("GET ?q=%s = %d; %s", tc2.q, w.Code, w.Body.String())
			}
			var result database.PagedResult
			json.NewDecoder(w.Body).Decode(&result)
			if int(result.Total) != tc2.want {
				t.Errorf("?q=%s total = %d, want %d", tc2.q, result.Total, tc2.want)
			}
			if len(result.Data) != tc2.want {
				t.Errorf("?q=%s data len = %d, want %d", tc2.q, len(result.Data), tc2.want)
			}
		})
	}
}

// TestListSearchIgnoredWithoutSearchCols verifies that ?q= is a no-op
// on endpoints that weren't registered with search columns.
func TestListSearchIgnoredWithoutSearchCols(t *testing.T) {
	tc := newTestServerWithDB(t)

	// chemical-inventory has no search cols configured.
	req := httptest.NewRequest("GET", "/api/chemical-inventory?q=anything", nil)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GET chemical-inventory?q=anything = %d; %s", w.Code, w.Body.String())
	}
}

// TestListEndpointsReturn200 verifies all list endpoints respond with
// valid paginated JSON, even when tables are empty.
func TestListEndpointsReturn200(t *testing.T) {
	tc := newTestServerWithDB(t)

	endpoints := []string{
		"/api/establishments",
		"/api/employees",
		"/api/incidents",
		"/api/corrective-actions",
		"/api/chemicals",
		"/api/chemical-inventory",
		"/api/emission-units",
		"/api/training/courses",
		"/api/training/completions",
		"/api/inspections",
		"/api/audits",
		"/api/permits",
		"/api/waste-streams",
		"/api/ppe/items",
		"/api/ppe/assignments",
	}

	for _, ep := range endpoints {
		t.Run(ep, func(t *testing.T) {
			req := httptest.NewRequest("GET", ep, nil)
			w := httptest.NewRecorder()
			tc.srv.mux.ServeHTTP(w, req)

			if w.Code != http.StatusOK {
				t.Errorf("GET %s = %d, want 200; body: %s", ep, w.Code, w.Body.String())
				return
			}

			var result database.PagedResult
			if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
				t.Errorf("GET %s: decode: %v", ep, err)
				return
			}
			if result.Data == nil {
				t.Errorf("GET %s: data is nil, want empty array", ep)
			}
		})
	}
}

// TestGetByIDReturns404 verifies get-by-ID returns 404 for missing records.
func TestGetByIDReturns404(t *testing.T) {
	tc := newTestServerWithDB(t)

	endpoints := []string{
		"/api/establishments/999",
		"/api/employees/999",
		"/api/incidents/999",
		"/api/chemicals/999",
	}

	for _, ep := range endpoints {
		t.Run(ep, func(t *testing.T) {
			req := httptest.NewRequest("GET", ep, nil)
			w := httptest.NewRecorder()
			tc.srv.mux.ServeHTTP(w, req)

			if w.Code != http.StatusNotFound {
				t.Errorf("GET %s = %d, want 404", ep, w.Code)
			}
		})
	}
}

// TestGetByIDReturns200 verifies get-by-ID returns data for existing records.
func TestGetByIDReturns200(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Establishment 1 was seeded in setup.
	req := httptest.NewRequest("GET", "/api/establishments/1", nil)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("GET /api/establishments/1 = %d, want 200; body: %s", w.Code, w.Body.String())
	}

	var row database.Row
	if err := json.NewDecoder(w.Body).Decode(&row); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if row["name"] != "Test Facility" {
		t.Errorf("name = %v, want Test Facility", row["name"])
	}
}

// TestPermitsSummary verifies the per-module Summary endpoint for
// permits buckets active permits by expiry window, picks the correct
// status, and reports Empty when no active permits exist.
func TestPermitsSummary(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Empty case: no active permits → Empty=true, no metrics.
	req := httptest.NewRequest("GET", "/api/permits/summary", nil)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("empty case: status = %d; body: %s", w.Code, w.Body.String())
	}
	var resp map[string]any
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("decode empty: %v", err)
	}
	if empty, _ := resp["empty"].(bool); !empty {
		t.Errorf("empty case: empty = %v, want true", resp["empty"])
	}
	if _, hasPrimary := resp["primary"]; hasPrimary {
		t.Errorf("empty case: should not include primary, got %v", resp["primary"])
	}

	// Seed: a second establishment for the facility-filter check.
	if err := tc.srv.db.ExecParams(
		`INSERT INTO establishments (id, name, street_address, city, state, zip, naics_code)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		2, "Other Facility", "456 Other Way", "Springfield", "IL", "62701", "325199",
	); err != nil {
		t.Fatalf("seed establishment 2: %v", err)
	}

	// Permits: 5 at fac 1 (3 in ≤30d → alert, 1 in 31-60d, 1 outside),
	// 1 at fac 2 (in ≤30d). Expired permit doesn't count.
	insert := func(estID int, num string, daysOut int, status string) {
		t.Helper()
		expr := "date('now', '+" + strconv.Itoa(daysOut) + " days')"
		if daysOut < 0 {
			expr = "date('now', '" + strconv.Itoa(daysOut) + " days')"
		}
		sql := `INSERT INTO permits
		    (establishment_id, permit_type_id, permit_number, status, expiration_date)
		    VALUES (?, 1, ?, ?, ` + expr + `)`
		if err := tc.srv.db.ExecParams(sql, estID, num, status); err != nil {
			t.Fatalf("insert permit %s: %v", num, err)
		}
	}
	insert(1, "P-30A", 5, "active")    // bucket_30
	insert(1, "P-30B", 15, "active")   // bucket_30
	insert(1, "P-30C", 28, "active")   // bucket_30
	insert(1, "P-60", 45, "active")    // bucket_60
	insert(1, "P-FAR", 200, "active")  // outside windows
	insert(1, "P-DEAD", -10, "expired") // not active — ignored
	insert(2, "Q-30", 10, "active")    // facility 2 only

	// Org-wide: 3+1=4 in ≤30d → alert; 1 in 31-60d.
	req = httptest.NewRequest("GET", "/api/permits/summary", nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("org-wide: status = %d; body: %s", w.Code, w.Body.String())
	}
	resp = nil
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("decode org: %v", err)
	}
	if empty, _ := resp["empty"].(bool); empty {
		t.Errorf("org-wide: empty=true; want false")
	}
	if got := resp["status"]; got != "alert" {
		t.Errorf("org-wide: status = %v, want alert (4 in ≤30d)", got)
	}
	if p, _ := resp["primary"].(map[string]any); int(p["value"].(float64)) != 4 {
		t.Errorf("org-wide: primary.value = %v, want 4", p["value"])
	}
	if sec, _ := resp["secondary"].(map[string]any); int(sec["value"].(float64)) != 1 {
		t.Errorf("org-wide: secondary.value = %v, want 1", sec["value"])
	}

	// Facility 1 only: 3 in ≤30d → warn (1-3 range); 1 in 31-60d.
	req = httptest.NewRequest("GET", "/api/permits/summary?facility_id=1", nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	resp = nil
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("decode fac1: %v", err)
	}
	if got := resp["status"]; got != "warn" {
		t.Errorf("fac1: status = %v, want warn (3 in ≤30d)", got)
	}
	if p, _ := resp["primary"].(map[string]any); int(p["value"].(float64)) != 3 {
		t.Errorf("fac1: primary.value = %v, want 3", p["value"])
	}

	// Facility 2 only: 1 in ≤30d → warn; 0 in 31-60d.
	req = httptest.NewRequest("GET", "/api/permits/summary?facility_id=2", nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	resp = nil
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("decode fac2: %v", err)
	}
	if got := resp["status"]; got != "warn" {
		t.Errorf("fac2: status = %v, want warn", got)
	}
	if sec, _ := resp["secondary"].(map[string]any); int(sec["value"].(float64)) != 0 {
		t.Errorf("fac2: secondary.value = %v, want 0", sec["value"])
	}
}

// fetchSummary GETs a summary endpoint and decodes the JSON body. Helper
// keeps the per-handler tests below readable.
func fetchSummary(t *testing.T, tc *testContext, url string) map[string]any {
	t.Helper()
	req := httptest.NewRequest("GET", url, nil)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GET %s = %d; body: %s", url, w.Code, w.Body.String())
	}
	var resp map[string]any
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("decode %s: %v", url, err)
	}
	return resp
}

// summaryValue extracts an int from a {label, value} metric block.
// Returns 0 if the field is missing.
func summaryValue(t *testing.T, resp map[string]any, slot string) int {
	t.Helper()
	m, ok := resp[slot].(map[string]any)
	if !ok {
		return 0
	}
	v, ok := m["value"].(float64)
	if !ok {
		t.Fatalf("%s.value not a number: %v", slot, m["value"])
	}
	return int(v)
}

func TestTrainingSummary(t *testing.T) {
	tc := newTestServerWithDB(t)

	resp := fetchSummary(t, tc, "/api/training/summary")
	if empty, _ := resp["empty"].(bool); !empty {
		t.Errorf("empty case: empty = %v, want true", resp["empty"])
	}

	// Seed: 2 establishments, 1 employee each, 1 course, completions
	// at known relative expiry dates.
	if err := tc.srv.db.ExecParams(
		`INSERT INTO establishments (id, name, street_address, city, state, zip, naics_code)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		2, "Other Facility", "456 Other Way", "Springfield", "IL", "62701", "325199",
	); err != nil {
		t.Fatalf("seed establishment 2: %v", err)
	}
	if err := tc.srv.db.ExecParams(
		`INSERT INTO employees (id, establishment_id, employee_number, first_name, last_name)
		 VALUES (1, 1, 'E1', 'A', 'A'), (2, 2, 'E2', 'B', 'B')`,
	); err != nil {
		t.Fatalf("seed employees: %v", err)
	}
	// training_courses are seeded by the schema migration — id=1 exists.

	insert := func(empID int, daysOut int) {
		t.Helper()
		var expr string
		if daysOut < 0 {
			expr = "date('now', '" + strconv.Itoa(daysOut) + " days')"
		} else {
			expr = "date('now', '+" + strconv.Itoa(daysOut) + " days')"
		}
		sql := `INSERT INTO training_completions (employee_id, course_id, completion_date, expiration_date)
		        VALUES (?, 1, date('now'), ` + expr + `)`
		if err := tc.srv.db.ExecParams(sql, empID); err != nil {
			t.Fatalf("seed completion: %v", err)
		}
	}
	insert(1, 10)  // emp1, ≤30d
	insert(1, 20)  // emp1, ≤30d
	insert(1, 45)  // emp1, 31-60d
	insert(1, 200) // emp1, outside
	insert(2, 5)   // emp2 (fac 2), ≤30d

	resp = fetchSummary(t, tc, "/api/training/summary")
	if got := resp["status"]; got != "warn" {
		t.Errorf("org-wide: status = %v, want warn (3 in ≤30d)", got)
	}
	if got := summaryValue(t, resp, "primary"); got != 3 {
		t.Errorf("org-wide: primary = %d, want 3", got)
	}
	if got := summaryValue(t, resp, "secondary"); got != 1 {
		t.Errorf("org-wide: secondary = %d, want 1", got)
	}

	resp = fetchSummary(t, tc, "/api/training/summary?facility_id=2")
	if got := summaryValue(t, resp, "primary"); got != 1 {
		t.Errorf("fac2: primary = %d, want 1", got)
	}
	if got := summaryValue(t, resp, "secondary"); got != 0 {
		t.Errorf("fac2: secondary = %d, want 0", got)
	}
}

func TestAuditsSummary(t *testing.T) {
	tc := newTestServerWithDB(t)

	resp := fetchSummary(t, tc, "/api/audits/summary")
	if empty, _ := resp["empty"].(bool); !empty {
		t.Errorf("empty case: empty = %v, want true", resp["empty"])
	}

	if err := tc.srv.db.ExecParams(
		`INSERT INTO establishments (id, name, street_address, city, state, zip, naics_code)
		 VALUES (2, 'F2', '1', 'C', 'I', '62701', '325199')`,
	); err != nil {
		t.Fatalf("seed est 2: %v", err)
	}
	if err := tc.srv.db.ExecParams(
		`INSERT INTO audits (id, establishment_id, audit_number, audit_title, audit_type)
		 VALUES (1, 1, 'A-1', 'Audit 1', 'internal'), (2, 2, 'A-2', 'Audit 2', 'internal')`,
	); err != nil {
		t.Fatalf("seed audits: %v", err)
	}
	insert := func(auditID int, num, ftype, status string) {
		t.Helper()
		if err := tc.srv.db.ExecParams(
			`INSERT INTO audit_findings (audit_id, finding_number, finding_type, finding_statement, status)
			 VALUES (?, ?, ?, 'stmt', ?)`,
			auditID, num, ftype, status,
		); err != nil {
			t.Fatalf("seed finding %s: %v", num, err)
		}
	}
	insert(1, "F1", "major_nc", "open")              // open + major
	insert(1, "F2", "minor_nc", "open")              // open
	insert(1, "F3", "minor_nc", "corrective_action_issued") // open
	insert(1, "F4", "major_nc", "verified")          // closed-side
	insert(2, "F5", "major_nc", "open")              // fac 2 only

	resp = fetchSummary(t, tc, "/api/audits/summary")
	if got := summaryValue(t, resp, "primary"); got != 4 {
		t.Errorf("org-wide: primary = %d, want 4 (3 fac1 + 1 fac2)", got)
	}
	if got := summaryValue(t, resp, "secondary"); got != 2 {
		t.Errorf("org-wide: secondary (major NCs) = %d, want 2", got)
	}
	if got := resp["status"]; got != "alert" {
		t.Errorf("org-wide: status = %v, want alert (4 open)", got)
	}

	resp = fetchSummary(t, tc, "/api/audits/summary?facility_id=2")
	if got := summaryValue(t, resp, "primary"); got != 1 {
		t.Errorf("fac2: primary = %d, want 1", got)
	}
	if got := resp["status"]; got != "warn" {
		t.Errorf("fac2: status = %v, want warn", got)
	}
}

func TestIncidentsSummary(t *testing.T) {
	tc := newTestServerWithDB(t)

	resp := fetchSummary(t, tc, "/api/incidents/summary")
	if empty, _ := resp["empty"].(bool); !empty {
		t.Errorf("empty case: empty = %v, want true", resp["empty"])
	}

	if err := tc.srv.db.ExecParams(
		`INSERT INTO establishments (id, name, street_address, city, state, zip, naics_code)
		 VALUES (2, 'F2', '1', 'C', 'I', '62701', '325199')`,
	); err != nil {
		t.Fatalf("seed est 2: %v", err)
	}
	insert := func(estID int, num, severity, status string) {
		t.Helper()
		if err := tc.srv.db.ExecParams(
			`INSERT INTO incidents (establishment_id, case_number, incident_date, incident_description, severity_code, status)
			 VALUES (?, ?, date('now'), 'd', ?, ?)`,
			estID, num, severity, status,
		); err != nil {
			t.Fatalf("seed incident %s: %v", num, err)
		}
	}
	insert(1, "I1", "FIRST_AID", "reported")     // open
	insert(1, "I2", "LOST_TIME", "investigating") // open + severe
	insert(1, "I3", "FATALITY", "pending_review") // open + severe
	insert(1, "I4", "MEDICAL_TX", "closed") // closed
	insert(2, "I5", "RESTRICTED", "reported")    // fac 2, open + severe

	resp = fetchSummary(t, tc, "/api/incidents/summary")
	if got := summaryValue(t, resp, "primary"); got != 4 {
		t.Errorf("org-wide: primary = %d, want 4 (3 fac1 open + 1 fac2 open)", got)
	}
	if got := summaryValue(t, resp, "secondary"); got != 3 {
		t.Errorf("org-wide: secondary (severe) = %d, want 3", got)
	}
	if got := resp["status"]; got != "alert" {
		t.Errorf("org-wide: status = %v, want alert", got)
	}

	resp = fetchSummary(t, tc, "/api/incidents/summary?facility_id=2")
	if got := summaryValue(t, resp, "primary"); got != 1 {
		t.Errorf("fac2: primary = %d, want 1", got)
	}
	if got := summaryValue(t, resp, "secondary"); got != 1 {
		t.Errorf("fac2: secondary = %d, want 1", got)
	}
}

func TestSampleEventsSummary(t *testing.T) {
	tc := newTestServerWithDB(t)

	resp := fetchSummary(t, tc, "/api/ww-sample-events/summary")
	if empty, _ := resp["empty"].(bool); !empty {
		t.Errorf("empty case: empty = %v, want true", resp["empty"])
	}

	if err := tc.srv.db.ExecParams(
		`INSERT INTO establishments (id, name, street_address, city, state, zip, naics_code)
		 VALUES (2, 'F2', '1', 'C', 'I', '62701', '325199')`,
	); err != nil {
		t.Fatalf("seed est 2: %v", err)
	}
	if err := tc.srv.db.ExecParams(
		`INSERT INTO ww_monitoring_locations (id, establishment_id, location_code, location_name, location_type)
		 VALUES (1, 1, 'L1', 'Loc 1', 'effluent'), (2, 2, 'L2', 'Loc 2', 'effluent')`,
	); err != nil {
		t.Fatalf("seed monitoring locations: %v", err)
	}
	insert := func(estID, locID int, num string, daysAgo int, status string) {
		t.Helper()
		expr := "date('now', '-" + strconv.Itoa(daysAgo) + " days')"
		sql := `INSERT INTO ww_sampling_events (establishment_id, location_id, event_number, sample_date, status)
		        VALUES (?, ?, ?, ` + expr + `, ?)`
		if err := tc.srv.db.ExecParams(sql, estID, locID, num, status); err != nil {
			t.Fatalf("seed event %s: %v", num, err)
		}
	}
	insert(1, 1, "E1", 5, "in_progress")   // open, recent
	insert(1, 1, "E2", 20, "in_progress")  // open, overdue (>14d)
	insert(1, 1, "E3", 30, "finalized")    // not open
	insert(2, 2, "E4", 25, "in_progress")  // fac 2, open + overdue

	resp = fetchSummary(t, tc, "/api/ww-sample-events/summary")
	if got := summaryValue(t, resp, "primary"); got != 3 {
		t.Errorf("org-wide: primary = %d, want 3 (in_progress)", got)
	}
	if got := summaryValue(t, resp, "secondary"); got != 2 {
		t.Errorf("org-wide: secondary (overdue) = %d, want 2", got)
	}

	resp = fetchSummary(t, tc, "/api/ww-sample-events/summary?facility_id=2")
	if got := summaryValue(t, resp, "primary"); got != 1 {
		t.Errorf("fac2: primary = %d, want 1", got)
	}
	if got := summaryValue(t, resp, "secondary"); got != 1 {
		t.Errorf("fac2: secondary = %d, want 1", got)
	}
}

func TestOSHA300Summary(t *testing.T) {
	tc := newTestServerWithDB(t)

	resp := fetchSummary(t, tc, "/api/osha-300/summary")
	if empty, _ := resp["empty"].(bool); !empty {
		t.Errorf("empty case: empty = %v, want true", resp["empty"])
	}

	// Seed: incidents this year, no 300A row → status='' (neutral).
	insert := func(num, severity string, daysAgo int) {
		t.Helper()
		expr := "date('now', '-" + strconv.Itoa(daysAgo) + " days')"
		sql := `INSERT INTO incidents (establishment_id, case_number, incident_date, incident_description, severity_code, status)
		        VALUES (1, ?, ` + expr + `, 'd', ?, 'closed')`
		if err := tc.srv.db.ExecParams(sql, num, severity); err != nil {
			t.Fatalf("seed incident %s: %v", num, err)
		}
	}
	insert("Y1", "FIRST_AID", 30)         // not recordable
	insert("Y2", "MEDICAL_TX", 45) // recordable
	insert("Y3", "LOST_TIME", 90)         // recordable + severe
	insert("Y4", "RESTRICTED", 120)       // recordable + severe

	resp = fetchSummary(t, tc, "/api/osha-300/summary")
	if got := summaryValue(t, resp, "primary"); got != 3 {
		t.Errorf("primary (recordable YTD) = %d, want 3", got)
	}
	if got := summaryValue(t, resp, "secondary"); got != 2 {
		t.Errorf("secondary (severe YTD) = %d, want 2", got)
	}
	if got, _ := resp["status"].(string); got != "" {
		t.Errorf("no-300A: status = %q, want '' (no submission row yet)", got)
	}

	// Submit the prior-year 300A → status='ok'.
	if err := tc.srv.db.ExecParams(
		`INSERT INTO osha_300a_summaries (establishment_id, year, ita_submitted_date)
		 VALUES (1, CAST(strftime('%Y', date('now', '-1 year')) AS INTEGER), date('now', '-30 days'))`,
	); err != nil {
		t.Fatalf("seed 300A: %v", err)
	}
	resp = fetchSummary(t, tc, "/api/osha-300/summary")
	if got, _ := resp["status"].(string); got != "ok" {
		t.Errorf("submitted: status = %q, want ok", got)
	}
}

// TestDashboardCounts verifies the dashboard endpoint returns counts.
func TestDashboardCounts(t *testing.T) {
	tc := newTestServerWithDB(t)

	req := httptest.NewRequest("GET", "/api/dashboard/counts", nil)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("GET /api/dashboard/counts = %d; body: %s", w.Code, w.Body.String())
	}

	var counts map[string]any
	if err := json.NewDecoder(w.Body).Decode(&counts); err != nil {
		t.Fatalf("decode: %v", err)
	}

	// Should have all expected keys.
	expected := []string{"establishments", "employees", "open_incidents", "open_cas", "chemicals", "active_permits", "expiring_permits"}
	for _, key := range expected {
		if _, ok := counts[key]; !ok {
			t.Errorf("missing key %q in dashboard counts", key)
		}
	}
}

// TestPagination verifies pagination parameters work.
func TestPagination(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Training courses were seeded (13 courses for establishment 1).
	req := httptest.NewRequest("GET", "/api/training/courses?page=1&per_page=5", nil)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d; body: %s", w.Code, w.Body.String())
	}

	var result database.PagedResult
	if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
		t.Fatalf("decode: %v", err)
	}

	if result.PerPage != 5 {
		t.Errorf("per_page = %d, want 5", result.PerPage)
	}
	if result.Page != 1 {
		t.Errorf("page = %d, want 1", result.Page)
	}
	if len(result.Data) > 5 {
		t.Errorf("got %d rows, want <= 5", len(result.Data))
	}
	if result.Total != 13 {
		t.Errorf("total = %d, want 13 (seeded training courses)", result.Total)
	}
	if result.TotalPages != 3 {
		t.Errorf("total_pages = %d, want 3", result.TotalPages)
	}
}

// TestWriteRequiresAuth verifies write endpoints return 401 without auth.
func TestWriteRequiresAuth(t *testing.T) {
	tc := newTestServerWithDB(t)

	req := httptest.NewRequest("POST", "/api/establishments", bytes.NewBufferString(`{"name":"Test"}`))
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("POST without auth = %d, want 401", w.Code)
	}
}
