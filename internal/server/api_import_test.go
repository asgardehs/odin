package server

import (
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// uploadCSV builds a multipart/form-data request with a CSV payload in
// the 'file' field and the given target establishment.
func uploadCSV(t *testing.T, tc *testContext, module, filename, csv string, estID int64) *httptest.ResponseRecorder {
	t.Helper()

	var body bytes.Buffer
	mw := multipart.NewWriter(&body)

	if estID != 0 {
		_ = mw.WriteField("target_establishment_id", itoa(int(estID)))
	}
	part, err := mw.CreateFormFile("file", filename)
	if err != nil {
		t.Fatalf("CreateFormFile: %v", err)
	}
	if _, err := part.Write([]byte(csv)); err != nil {
		t.Fatalf("write csv: %v", err)
	}
	if err := mw.Close(); err != nil {
		t.Fatalf("multipart close: %v", err)
	}

	req := httptest.NewRequest("POST", "/api/import/csv/"+module, &body)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	return w
}

func TestImportModulesListingRequiresAdmin(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Unauthenticated
	req := httptest.NewRequest("GET", "/api/import/modules", nil)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("unauth GET /api/import/modules = %d, want 401", w.Code)
	}

	// Admin
	req = httptest.NewRequest("GET", "/api/import/modules", nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("admin GET = %d; %s", w.Code, w.Body.String())
	}
	var body struct {
		Modules []struct {
			Slug         string `json:"slug"`
			Label        string `json:"label"`
			TargetFields []struct {
				Name  string `json:"name"`
				Label string `json:"label"`
			} `json:"target_fields"`
		} `json:"modules"`
	}
	json.NewDecoder(w.Body).Decode(&body)
	if len(body.Modules) == 0 {
		t.Fatalf("expected at least one registered module, got 0")
	}
	found := false
	for _, m := range body.Modules {
		if m.Slug == "employees" {
			found = true
			if len(m.TargetFields) < 5 {
				t.Errorf("employees target_fields = %d, want >=5", len(m.TargetFields))
			}
			break
		}
	}
	if !found {
		t.Errorf("employees module not in listing: %+v", body.Modules)
	}
}

func TestImportLifecycleEmployees(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Upload.
	csv := "First Name,Surname,Emp ID,Started,State,Zip\n" +
		"Alice,Anderson,E001,2024-03-15,IL,62701\n" +
		"Bob,Burton,E002,03/15/2024,WI,53703\n"
	up := uploadCSV(t, tc, "employees", "emps.csv", csv, 1)
	if up.Code != http.StatusCreated {
		t.Fatalf("upload = %d; %s", up.Code, up.Body.String())
	}
	var preview struct {
		Token            string            `json:"token"`
		Status           string            `json:"status"`
		Mapping          map[string]string `json:"mapping"`
		RowCount         int               `json:"row_count"`
		ValidationErrors []map[string]any  `json:"validation_errors"`
	}
	json.NewDecoder(up.Body).Decode(&preview)
	if preview.Token == "" {
		t.Fatal("no token returned")
	}
	if preview.RowCount != 2 {
		t.Errorf("row_count = %d, want 2", preview.RowCount)
	}
	if preview.Mapping["First Name"] != "first_name" || preview.Mapping["Emp ID"] != "employee_number" {
		t.Errorf("mapping: %v", preview.Mapping)
	}
	if len(preview.ValidationErrors) != 0 {
		t.Errorf("unexpected validation errors: %+v", preview.ValidationErrors)
	}

	// Status.
	req := httptest.NewRequest("GET", "/api/import/csv/employees/"+preview.Token, nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d; %s", w.Code, w.Body.String())
	}

	// Commit.
	req = httptest.NewRequest("POST", "/api/import/csv/employees/"+preview.Token+"/commit", nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("commit = %d; %s", w.Code, w.Body.String())
	}
	var result struct {
		InsertedCount int    `json:"inserted_count"`
		SkippedCount  int    `json:"skipped_count"`
		AuditSummary  string `json:"audit_summary"`
	}
	json.NewDecoder(w.Body).Decode(&result)
	if result.InsertedCount != 2 || result.SkippedCount != 0 {
		t.Errorf("result = %+v", result)
	}
	if !strings.Contains(result.AuditSummary, "Imported 2 rows into employees") {
		t.Errorf("audit summary = %q", result.AuditSummary)
	}

	// Confirm rows actually landed.
	row, _ := tc.srv.db.QueryRow(`SELECT COUNT(*) AS c FROM employees`)
	if row["c"].(int64) != 2 {
		t.Errorf("employees count = %v, want 2", row["c"])
	}

	// Commit again → already committed.
	req = httptest.NewRequest("POST", "/api/import/csv/employees/"+preview.Token+"/commit", nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusConflict {
		t.Errorf("double-commit = %d, want 409", w.Code)
	}
}

func TestImportUpdateMappingRoute(t *testing.T) {
	tc := newTestServerWithDB(t)

	// "Stage Name" won't auto-map — we'll correct it via PUT.
	csv := "Stage Name,Last\nAlice,Anderson\n"
	up := uploadCSV(t, tc, "employees", "x.csv", csv, 1)
	if up.Code != http.StatusCreated {
		t.Fatalf("upload: %s", up.Body.String())
	}
	var preview struct {
		Token            string           `json:"token"`
		ValidationErrors []map[string]any `json:"validation_errors"`
	}
	json.NewDecoder(up.Body).Decode(&preview)
	if len(preview.ValidationErrors) == 0 {
		t.Fatal("expected validation errors for missing first_name")
	}

	putBody := `{"mapping":{"Stage Name":"first_name","Last":"last_name"}}`
	req := httptest.NewRequest("PUT",
		"/api/import/csv/employees/"+preview.Token+"/mapping",
		strings.NewReader(putBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("PUT mapping = %d; %s", w.Code, w.Body.String())
	}
	var updated struct {
		ValidationErrors []map[string]any `json:"validation_errors"`
	}
	json.NewDecoder(w.Body).Decode(&updated)
	if len(updated.ValidationErrors) != 0 {
		t.Errorf("post-remap errors: %+v", updated.ValidationErrors)
	}

	// Commit now succeeds.
	req = httptest.NewRequest("POST",
		"/api/import/csv/employees/"+preview.Token+"/commit", nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("commit after remap = %d; %s", w.Code, w.Body.String())
	}
}

func TestImportCommitSkipInvalid(t *testing.T) {
	tc := newTestServerWithDB(t)

	csv := "First Name,Last Name,State\n" +
		"Alice,Anderson,IL\n" +
		"Bob,Burton,Illinois\n" + // bad: state not 2 letters
		"Carol,Carter,WI\n"
	up := uploadCSV(t, tc, "employees", "x.csv", csv, 1)
	if up.Code != http.StatusCreated {
		t.Fatalf("upload: %s", up.Body.String())
	}
	var preview struct {
		Token string `json:"token"`
	}
	json.NewDecoder(up.Body).Decode(&preview)

	// Without skip_invalid, commit should fail (400).
	req := httptest.NewRequest("POST",
		"/api/import/csv/employees/"+preview.Token+"/commit", nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusBadRequest {
		t.Errorf("commit without skip_invalid = %d, want 400", w.Code)
	}

	// With skip_invalid, 2 valid rows land.
	req = httptest.NewRequest("POST",
		"/api/import/csv/employees/"+preview.Token+"/commit?skip_invalid=1", nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("commit skip_invalid = %d; %s", w.Code, w.Body.String())
	}
	var result struct {
		InsertedCount int `json:"inserted_count"`
		SkippedCount  int `json:"skipped_count"`
	}
	json.NewDecoder(w.Body).Decode(&result)
	if result.InsertedCount != 2 || result.SkippedCount != 1 {
		t.Errorf("result = %+v, want inserted=2 skipped=1", result)
	}
}

func TestImportUnknownTokenIs404(t *testing.T) {
	tc := newTestServerWithDB(t)
	req := httptest.NewRequest("GET", "/api/import/csv/employees/notarealtoken", nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusNotFound {
		t.Errorf("unknown token = %d, want 404", w.Code)
	}
}

func TestImportUnknownModuleIs404(t *testing.T) {
	tc := newTestServerWithDB(t)
	w := uploadCSV(t, tc, "not-a-module", "x.csv", "a,b\n1,2\n", 1)
	if w.Code != http.StatusNotFound {
		t.Errorf("unknown module = %d, want 404; body=%s", w.Code, w.Body.String())
	}
}

func TestImportDiscardRoute(t *testing.T) {
	tc := newTestServerWithDB(t)
	up := uploadCSV(t, tc, "employees", "x.csv",
		"First Name,Last Name\nAlice,Anderson\n", 1)
	var preview struct {
		Token string `json:"token"`
	}
	json.NewDecoder(up.Body).Decode(&preview)

	req := httptest.NewRequest("DELETE",
		"/api/import/csv/employees/"+preview.Token, nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("discard = %d; %s", w.Code, w.Body.String())
	}

	// Commit after discard → 409.
	req = httptest.NewRequest("POST",
		"/api/import/csv/employees/"+preview.Token+"/commit", nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusConflict {
		t.Errorf("commit after discard = %d, want 409", w.Code)
	}
}
