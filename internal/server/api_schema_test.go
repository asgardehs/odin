package server

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/asgardehs/odin/internal/auth"
)

// ============================================================
// Helpers
// ============================================================

type jsonMap map[string]any

// doJSON sends a JSON request and returns the response + decoded body.
// If body is nil the request has no body.
func (tc *testContext) doJSON(t *testing.T, method, path string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var r io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal: %v", err)
		}
		r = bytes.NewReader(buf)
	}
	req := httptest.NewRequest(method, path, r)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	return w
}

// doJSONAs sends a JSON request using a different session token than
// the default admin one in tc.
func (tc *testContext) doJSONAs(t *testing.T, token, method, path string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var r io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal: %v", err)
		}
		r = bytes.NewReader(buf)
	}
	req := httptest.NewRequest(method, path, r)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	return w
}

// seedNonAdmin creates a second user with role="user" and returns a
// session token for that user.
func seedNonAdmin(t *testing.T, tc *testContext) string {
	t.Helper()
	userStore := auth.NewUserStore(tc.srv.db)
	userID, err := userStore.Create(auth.UserInput{
		Username:    "regular",
		DisplayName: "Regular User",
		Password:    "secret",
		Role:        "user",
	})
	if err != nil {
		t.Fatalf("seed non-admin: %v", err)
	}
	token, err := tc.srv.sessions.Create(userID, "127.0.0.1")
	if err != nil {
		t.Fatalf("session for non-admin: %v", err)
	}
	return token
}

func decodeJSON(t *testing.T, w *httptest.ResponseRecorder, into any) {
	t.Helper()
	if err := json.Unmarshal(w.Body.Bytes(), into); err != nil {
		t.Fatalf("decode JSON: %v (%s)", err, w.Body.String())
	}
}

// ============================================================
// Schema admin routes
// ============================================================

func TestSchemaAPI_CreateTable(t *testing.T) {
	tc := newTestServerWithDB(t)

	w := tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name":         "equipment_checkouts",
		"display_name": "Equipment Checkouts",
		"description":  "Who checked out what and when",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("create table: %d; %s", w.Code, w.Body.String())
	}
	var out jsonMap
	decodeJSON(t, w, &out)
	if out["id"] == nil {
		t.Fatalf("missing id in response")
	}

	// Physical table exists.
	row, _ := tc.srv.db.QueryVal(
		`SELECT name FROM sqlite_master WHERE type='table' AND name=?`,
		"cx_equipment_checkouts",
	)
	if row == nil {
		t.Errorf("cx_equipment_checkouts not created")
	}
}

func TestSchemaAPI_CreateTableRejectsNonAdmin(t *testing.T) {
	tc := newTestServerWithDB(t)
	token := seedNonAdmin(t, tc)

	w := tc.doJSONAs(t, token, "POST", "/api/schema/tables", jsonMap{
		"name":         "projects",
		"display_name": "Projects",
	})
	if w.Code != http.StatusForbidden {
		t.Errorf("expected 403 for non-admin, got %d; %s", w.Code, w.Body.String())
	}
}

func TestSchemaAPI_CreateTableValidationErrors(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Bad regex → 400.
	w := tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name": "Bad-Name", "display_name": "X",
	})
	if w.Code != http.StatusBadRequest {
		t.Errorf("bad regex: want 400, got %d", w.Code)
	}

	// Collision with pre-built → 400.
	w = tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name": "employees", "display_name": "X",
	})
	if w.Code != http.StatusBadRequest {
		t.Errorf("collision: want 400, got %d; %s", w.Code, w.Body.String())
	}
}

func TestSchemaAPI_FullFlow(t *testing.T) {
	tc := newTestServerWithDB(t)

	// 1. Create table.
	w := tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name":         "projects",
		"display_name": "Projects",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("create table: %d; %s", w.Code, w.Body.String())
	}
	var createRes jsonMap
	decodeJSON(t, w, &createRes)
	tableID := int64(createRes["id"].(float64))

	// 2. Add a required text field.
	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/fields", jsonMap{
		"name":         "title",
		"display_name": "Title",
		"field_type":   "text",
		"is_required":  true,
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add field: %d; %s", w.Code, w.Body.String())
	}
	var fieldRes jsonMap
	decodeJSON(t, w, &fieldRes)
	titleID := int64(fieldRes["id"].(float64))

	// 3. Add a relation field + a relation to employees.
	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/fields", jsonMap{
		"name":         "lead",
		"display_name": "Lead",
		"field_type":   "relation",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add relation field: %d; %s", w.Code, w.Body.String())
	}
	var relFieldRes jsonMap
	decodeJSON(t, w, &relFieldRes)
	leadID := int64(relFieldRes["id"].(float64))

	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/relations", jsonMap{
		"source_field_id":   leadID,
		"target_table_name": "employees",
		"display_field":     "last_name",
		"relation_type":     "belongs_to",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add relation: %d; %s", w.Code, w.Body.String())
	}

	// 4. GET the table — fields + relations populated.
	w = tc.doJSON(t, "GET", "/api/schema/tables/"+idPath(tableID), nil)
	if w.Code != http.StatusOK {
		t.Fatalf("get table: %d", w.Code)
	}
	var tbl jsonMap
	decodeJSON(t, w, &tbl)
	fields, _ := tbl["fields"].([]any)
	if len(fields) != 2 {
		t.Errorf("want 2 fields, got %d", len(fields))
	}
	relations, _ := tbl["relations"].([]any)
	if len(relations) != 1 {
		t.Errorf("want 1 relation, got %d", len(relations))
	}

	// 5. Create a record row.
	w = tc.doJSON(t, "POST", "/api/records/projects", jsonMap{
		"title":            "Ship schema builder",
		"establishment_id": 1,
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("create record: %d; %s", w.Code, w.Body.String())
	}
	var rowRes jsonMap
	decodeJSON(t, w, &rowRes)
	rowID := int64(rowRes["id"].(float64))

	// 6. Fetch the record back.
	w = tc.doJSON(t, "GET", "/api/records/projects/"+idPath(rowID), nil)
	if w.Code != http.StatusOK {
		t.Fatalf("get record: %d", w.Code)
	}
	var row jsonMap
	decodeJSON(t, w, &row)
	if row["title"] != "Ship schema builder" {
		t.Errorf("title mismatch: %v", row["title"])
	}

	// 7. Missing required field on create → 400.
	w = tc.doJSON(t, "POST", "/api/records/projects", jsonMap{
		"establishment_id": 1,
	})
	if w.Code != http.StatusBadRequest {
		t.Errorf("missing required: want 400, got %d; %s", w.Code, w.Body.String())
	}

	// 8. Update the record.
	w = tc.doJSON(t, "PUT", "/api/records/projects/"+idPath(rowID), jsonMap{
		"title": "Ship schema builder — phase 1",
	})
	if w.Code != http.StatusOK {
		t.Fatalf("update record: %d; %s", w.Code, w.Body.String())
	}

	// 9. Delete the record.
	w = tc.doJSON(t, "DELETE", "/api/records/projects/"+idPath(rowID), nil)
	if w.Code != http.StatusOK {
		t.Fatalf("delete record: %d; %s", w.Code, w.Body.String())
	}
	w = tc.doJSON(t, "GET", "/api/records/projects/"+idPath(rowID), nil)
	if w.Code != http.StatusNotFound {
		t.Errorf("record should be gone, got %d", w.Code)
	}

	// 10. Deactivate the field → metadata flip, column still exists.
	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/fields/"+idPath(titleID)+"/deactivate", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("deactivate field: %d; %s", w.Code, w.Body.String())
	}
	cols, _ := tc.srv.db.QueryRows(`PRAGMA table_info("cx_projects")`)
	seen := false
	for _, c := range cols {
		if n, _ := c["name"].(string); n == "title" {
			seen = true
		}
	}
	if !seen {
		t.Errorf("title column removed — deactivation should be metadata-only")
	}

	// 11. Version history for the table lists every change.
	w = tc.doJSON(t, "GET", "/api/schema/tables/"+idPath(tableID)+"/versions", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("versions: %d", w.Code)
	}
	var ver jsonMap
	decodeJSON(t, w, &ver)
	versions, _ := ver["versions"].([]any)
	if len(versions) < 5 {
		t.Errorf("want >=5 version rows, got %d", len(versions))
	}
}

func TestSchemaAPI_AuditEntriesWrittenForSchemaAndRecords(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Create table + field.
	w := tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name": "notes", "display_name": "Notes",
	})
	var createRes jsonMap
	decodeJSON(t, w, &createRes)
	tableID := int64(createRes["id"].(float64))
	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/fields", jsonMap{
		"name": "body", "display_name": "Body", "field_type": "text", "is_required": true,
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add field: %d", w.Code)
	}

	// Schema-level audit history is keyed by table id under module=schema.
	schemaHist, err := tc.srv.audit.ReadHistoryAsAdmin("schema", idPath(tableID), "testuser")
	if err != nil {
		t.Fatalf("read schema audit: %v", err)
	}
	if len(schemaHist) < 2 {
		t.Errorf("want >=2 schema audit entries, got %d", len(schemaHist))
	}

	// Create a record.
	w = tc.doJSON(t, "POST", "/api/records/notes", jsonMap{
		"body":             "hello",
		"establishment_id": 1,
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("create record: %d; %s", w.Code, w.Body.String())
	}
	var rowRes jsonMap
	decodeJSON(t, w, &rowRes)
	rowID := int64(rowRes["id"].(float64))

	// Record-level audit is keyed by row id under module=cx_notes.
	rowHist, err := tc.srv.audit.ReadHistoryAsAdmin("cx_notes", idPath(rowID), "testuser")
	if err != nil {
		t.Fatalf("read record audit: %v", err)
	}
	if len(rowHist) < 1 {
		t.Errorf("want >=1 record audit entry, got %d", len(rowHist))
	}

	// Update + delete → more entries.
	w = tc.doJSON(t, "PUT", "/api/records/notes/"+idPath(rowID), jsonMap{"body": "updated"})
	if w.Code != http.StatusOK {
		t.Fatalf("update: %d", w.Code)
	}
	w = tc.doJSON(t, "DELETE", "/api/records/notes/"+idPath(rowID), nil)
	if w.Code != http.StatusOK {
		t.Fatalf("delete: %d", w.Code)
	}
	rowHist, _ = tc.srv.audit.ReadHistoryAsAdmin("cx_notes", idPath(rowID), "testuser")
	if len(rowHist) < 3 {
		t.Errorf("want >=3 (create+update+delete) record entries, got %d", len(rowHist))
	}
}

// ============================================================
// Negative cases — inactive / unknown table, delete blocked
// ============================================================

func TestSchemaAPI_UnknownSlug404(t *testing.T) {
	tc := newTestServerWithDB(t)

	w := tc.doJSON(t, "GET", "/api/records/ghost", nil)
	if w.Code != http.StatusNotFound {
		t.Errorf("unknown slug: want 404, got %d", w.Code)
	}
	w = tc.doJSON(t, "POST", "/api/records/ghost", jsonMap{"x": 1})
	if w.Code != http.StatusNotFound {
		t.Errorf("unknown slug POST: want 404, got %d", w.Code)
	}
}

func TestSchemaAPI_InactiveTableIs404OnRecordRoutes(t *testing.T) {
	tc := newTestServerWithDB(t)

	w := tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name": "projects", "display_name": "Projects",
	})
	var createRes jsonMap
	decodeJSON(t, w, &createRes)
	tableID := int64(createRes["id"].(float64))

	// Add a field so inserts have a target.
	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/fields", jsonMap{
		"name": "title", "display_name": "Title", "field_type": "text",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add field: %d", w.Code)
	}

	// Seed a row while the table is active.
	w = tc.doJSON(t, "POST", "/api/records/projects", jsonMap{
		"title": "seed", "establishment_id": 1,
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("seed row: %d", w.Code)
	}
	var rowRes jsonMap
	decodeJSON(t, w, &rowRes)
	rowID := int64(rowRes["id"].(float64))

	// Deactivate the table.
	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/deactivate", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("deactivate: %d", w.Code)
	}

	// GET /api/records/projects → 404 (inactive).
	w = tc.doJSON(t, "GET", "/api/records/projects", nil)
	if w.Code != http.StatusNotFound {
		t.Errorf("list inactive: want 404, got %d", w.Code)
	}
	// GET row → 404.
	w = tc.doJSON(t, "GET", "/api/records/projects/"+idPath(rowID), nil)
	if w.Code != http.StatusNotFound {
		t.Errorf("get row on inactive: want 404, got %d", w.Code)
	}
	// DELETE row → 404 (can't mutate orphaned data through the API).
	w = tc.doJSON(t, "DELETE", "/api/records/projects/"+idPath(rowID), nil)
	if w.Code != http.StatusNotFound {
		t.Errorf("delete row on inactive: want 404, got %d", w.Code)
	}

	// Admin schema route for the table still works (metadata is readable).
	w = tc.doJSON(t, "GET", "/api/schema/tables/"+idPath(tableID), nil)
	if w.Code != http.StatusOK {
		t.Errorf("get schema for inactive table: want 200, got %d", w.Code)
	}
}

// Repro for user-reported "socket hang up" on GET record with a real
// relation id set: create table → relation field → relation →
// seed employee → create record owner=empID → GET the record.
func TestSchemaAPI_RecordWithRelationRoundTrip(t *testing.T) {
	tc := newTestServerWithDB(t)

	w := tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name": "tasks", "display_name": "Tasks",
	})
	var createRes jsonMap
	decodeJSON(t, w, &createRes)
	tableID := int64(createRes["id"].(float64))

	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/fields", jsonMap{
		"name": "title", "display_name": "Title",
		"field_type": "text", "is_required": true,
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add title: %d; %s", w.Code, w.Body.String())
	}

	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/fields", jsonMap{
		"name": "owner", "display_name": "Owner", "field_type": "relation",
	})
	var ownerRes jsonMap
	decodeJSON(t, w, &ownerRes)
	ownerFieldID := int64(ownerRes["id"].(float64))

	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/relations", jsonMap{
		"source_field_id":   ownerFieldID,
		"target_table_name": "employees",
		"display_field":     "last_name",
		"relation_type":     "belongs_to",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add relation: %d; %s", w.Code, w.Body.String())
	}

	// Seed an employee to point at.
	w = tc.doJSON(t, "POST", "/api/employees", jsonMap{
		"establishment_id": 1,
		"first_name":       "Alice",
		"last_name":        "Anderson",
		"employee_number":  "E-001",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("seed employee: %d; %s", w.Code, w.Body.String())
	}
	var empRes jsonMap
	decodeJSON(t, w, &empRes)
	empID := int64(empRes["id"].(float64))

	// Create a record with the relation set.
	w = tc.doJSON(t, "POST", "/api/records/tasks", jsonMap{
		"title":            "Ship it",
		"owner":            empID,
		"establishment_id": 1,
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("create record: %d; %s", w.Code, w.Body.String())
	}
	var rowRes jsonMap
	decodeJSON(t, w, &rowRes)
	rowID := int64(rowRes["id"].(float64))

	// GET the record — user reports the proxy got "socket hang up" here.
	w = tc.doJSON(t, "GET", "/api/records/tasks/"+idPath(rowID), nil)
	if w.Code != http.StatusOK {
		t.Fatalf("get record: %d; %s", w.Code, w.Body.String())
	}
	var row jsonMap
	decodeJSON(t, w, &row)
	if row["owner__label"] != "Anderson" {
		t.Errorf("relation label mismatch: %+v", row)
	}
}

func TestSchemaAPI_RecordSchemaEndpointAccessibleToAnyAuthedUser(t *testing.T) {
	tc := newTestServerWithDB(t)
	token := seedNonAdmin(t, tc)

	w := tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name": "projects", "display_name": "Projects",
	})
	var createRes jsonMap
	decodeJSON(t, w, &createRes)
	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(int64(createRes["id"].(float64)))+"/fields", jsonMap{
		"name": "title", "display_name": "Title", "field_type": "text",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add field: %d", w.Code)
	}

	// Non-admin hits /api/records/projects/_schema → 200 with metadata.
	w = tc.doJSONAs(t, token, "GET", "/api/records/projects/_schema", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("want 200, got %d; %s", w.Code, w.Body.String())
	}
	var tbl jsonMap
	decodeJSON(t, w, &tbl)
	if tbl["name"] != "projects" {
		t.Errorf("bad metadata: %+v", tbl)
	}
	fields, _ := tbl["fields"].([]any)
	if len(fields) != 1 {
		t.Errorf("want 1 field, got %d", len(fields))
	}

	// Unknown slug → 404 via this endpoint too.
	w = tc.doJSONAs(t, token, "GET", "/api/records/ghost/_schema", nil)
	if w.Code != http.StatusNotFound {
		t.Errorf("unknown slug: want 404, got %d", w.Code)
	}
}

func TestSchemaAPI_ColumnsEndpoint(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Happy path: a whitelisted pre-built target.
	w := tc.doJSON(t, "GET", "/api/schema/columns?table=employees", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("employees columns: %d; %s", w.Code, w.Body.String())
	}
	var out jsonMap
	decodeJSON(t, w, &out)
	cols, _ := out["columns"].([]any)
	foundLastName := false
	for _, c := range cols {
		if m, ok := c.(map[string]any); ok {
			if m["name"] == "last_name" {
				foundLastName = true
			}
		}
	}
	if !foundLastName {
		t.Errorf("expected employees to have last_name column; got %+v", cols)
	}

	// Non-whitelisted target rejected with 400.
	w = tc.doJSON(t, "GET", "/api/schema/columns?table=app_users", nil)
	if w.Code != http.StatusBadRequest {
		t.Errorf("app_users (not whitelisted): want 400, got %d", w.Code)
	}

	// Allowed shape but doesn't exist → 404.
	w = tc.doJSON(t, "GET", "/api/schema/columns?table=cx_nonexistent", nil)
	if w.Code != http.StatusNotFound {
		t.Errorf("cx_nonexistent: want 404, got %d", w.Code)
	}

	// Missing param → 400.
	w = tc.doJSON(t, "GET", "/api/schema/columns", nil)
	if w.Code != http.StatusBadRequest {
		t.Errorf("missing table param: want 400, got %d", w.Code)
	}

	// Non-admin → 403.
	token := seedNonAdmin(t, tc)
	w = tc.doJSONAs(t, token, "GET", "/api/schema/columns?table=employees", nil)
	if w.Code != http.StatusForbidden {
		t.Errorf("non-admin: want 403, got %d", w.Code)
	}

	// An existing cx_ table is also valid.
	w = tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name": "widgets", "display_name": "Widgets",
	})
	var createRes jsonMap
	decodeJSON(t, w, &createRes)
	tableID := int64(createRes["id"].(float64))
	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/fields", jsonMap{
		"name": "label", "display_name": "Label", "field_type": "text",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add label: %d", w.Code)
	}
	w = tc.doJSON(t, "GET", "/api/schema/columns?table=cx_widgets", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("cx_widgets: %d; %s", w.Code, w.Body.String())
	}
	decodeJSON(t, w, &out)
	cols, _ = out["columns"].([]any)
	if len(cols) < 5 { // id, establishment_id, created_at, updated_at, label
		t.Errorf("cx_widgets should have >=5 columns, got %d", len(cols))
	}
}

func TestSchemaAPI_NonAdminCannotListVersionsOrGetSchema(t *testing.T) {
	tc := newTestServerWithDB(t)
	token := seedNonAdmin(t, tc)

	w := tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name": "notes", "display_name": "Notes",
	})
	var createRes jsonMap
	decodeJSON(t, w, &createRes)
	tableID := int64(createRes["id"].(float64))

	// Non-admin hitting schema routes → 403.
	w = tc.doJSONAs(t, token, "GET", "/api/schema/tables/"+idPath(tableID), nil)
	if w.Code != http.StatusForbidden {
		t.Errorf("non-admin get schema: want 403, got %d", w.Code)
	}
	w = tc.doJSONAs(t, token, "GET", "/api/schema/tables/"+idPath(tableID)+"/versions", nil)
	if w.Code != http.StatusForbidden {
		t.Errorf("non-admin versions: want 403, got %d", w.Code)
	}
}

// ============================================================
// Search + pagination on record list
// ============================================================

func TestRecordList_SearchAndPagination(t *testing.T) {
	tc := newTestServerWithDB(t)

	w := tc.doJSON(t, "POST", "/api/schema/tables", jsonMap{
		"name": "items", "display_name": "Items",
	})
	var createRes jsonMap
	decodeJSON(t, w, &createRes)
	tableID := int64(createRes["id"].(float64))
	w = tc.doJSON(t, "POST", "/api/schema/tables/"+idPath(tableID)+"/fields", jsonMap{
		"name": "title", "display_name": "Title", "field_type": "text",
	})
	if w.Code != http.StatusCreated {
		t.Fatalf("add field: %d", w.Code)
	}

	seeds := []string{"alpha", "beta", "gamma", "delta", "epsilon"}
	for _, s := range seeds {
		w := tc.doJSON(t, "POST", "/api/records/items", jsonMap{
			"title": s, "establishment_id": 1,
		})
		if w.Code != http.StatusCreated {
			t.Fatalf("seed %s: %d", s, w.Code)
		}
	}

	// Search for 'a': alpha ✓, beta ✓, gamma ✓, delta ✓, epsilon ✗ → 4.
	w = tc.doJSON(t, "GET", "/api/records/items?q=a", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("search: %d", w.Code)
	}
	var page jsonMap
	decodeJSON(t, w, &page)
	total := int(page["total"].(float64))
	if total != 4 {
		t.Errorf("search 'a': want 4, got %d", total)
	}

	// Paginate per_page=2 → first page has 2 items, total=5.
	w = tc.doJSON(t, "GET", "/api/records/items?per_page=2", nil)
	decodeJSON(t, w, &page)
	data, _ := page["data"].([]any)
	if len(data) != 2 {
		t.Errorf("per_page=2: want 2 items, got %d", len(data))
	}
	if int(page["total"].(float64)) != 5 {
		t.Errorf("total: want 5, got %v", page["total"])
	}
}

// idPath formats an int64 id for path interpolation. Kept local to
// avoid colliding with the existing idPath(int) helper in api_write_test.go.
func idPath(n int64) string {
	return strconv.FormatInt(n, 10)
}
