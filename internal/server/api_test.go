package server

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"testing/fstest"

	"github.com/asgardehs/odin/internal/audit"
	"github.com/asgardehs/odin/internal/database"
)

// newTestServerWithDB creates a server backed by an in-memory database
// with all EHS schema modules applied.
func newTestServerWithDB(t *testing.T) *Server {
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

	sqlDir := os.DirFS("../../docs/database-design/sql")
	migrations, err := database.CollectMigrations(sqlDir)
	if err != nil {
		t.Fatalf("collect: %v", err)
	}
	if err := database.Migrate(db, migrations); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	// Seed a test establishment so FK-dependent queries work.
	if err := db.ExecParams(
		`INSERT INTO establishments (id, name, street_address, city, state, zip, naics_code)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		1, "Test Facility", "123 Industrial Pkwy", "Springfield", "IL", "62701", "325199",
	); err != nil {
		t.Fatalf("seed establishment: %v", err)
	}

	return New(frontend, a, store, db)
}

// TestListEndpointsReturn200 verifies all list endpoints respond with
// valid paginated JSON, even when tables are empty.
func TestListEndpointsReturn200(t *testing.T) {
	srv := newTestServerWithDB(t)

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
			srv.mux.ServeHTTP(w, req)

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
	srv := newTestServerWithDB(t)

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
			srv.mux.ServeHTTP(w, req)

			if w.Code != http.StatusNotFound {
				t.Errorf("GET %s = %d, want 404", ep, w.Code)
			}
		})
	}
}

// TestGetByIDReturns200 verifies get-by-ID returns data for existing records.
func TestGetByIDReturns200(t *testing.T) {
	srv := newTestServerWithDB(t)

	// Establishment 1 was seeded in setup.
	req := httptest.NewRequest("GET", "/api/establishments/1", nil)
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

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

// TestDashboardCounts verifies the dashboard endpoint returns counts.
func TestDashboardCounts(t *testing.T) {
	srv := newTestServerWithDB(t)

	req := httptest.NewRequest("GET", "/api/dashboard/counts", nil)
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

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
	srv := newTestServerWithDB(t)

	// Training courses were seeded (13 courses for establishment 1).
	req := httptest.NewRequest("GET", "/api/training/courses?page=1&per_page=5", nil)
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

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
