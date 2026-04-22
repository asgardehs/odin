//go:build ratatoskr_embed

// XLSX upload lifecycle test. Gated behind `ratatoskr_embed` because
// the test requires the embedded Python distribution + openpyxl install
// to produce a real workbook and parse it back through the server.
//
// Runs after a one-time pip install (~5-10s cold); subsequent runs hit
// the cache in ~/.cache/odin/pylibs.
package server

import (
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/asgardehs/odin/internal/ratatoskr"
)

// makeXLSXFixture writes a small employees workbook via ratatoskr's
// embedded Python and returns the file bytes. The script lives here
// (not in testdata/) so the test is self-contained.
func makeXLSXFixture(t *testing.T) []byte {
	t.Helper()
	parser, err := ratatoskr.New()
	if err != nil {
		t.Skipf("ratatoskr unavailable: %v", err)
	}

	dir := t.TempDir()
	path := filepath.Join(dir, "employees.xlsx")
	// Write via the same embedded python ratatoskr uses to parse. We
	// access the internal `ep` field by spawning the command through the
	// public parser package — but since XLSX is an opaque handle here,
	// we use a small script file and hand it off via parser.ParseXLSX's
	// underlying command. Instead, shell out to the embedded python via
	// a tiny script written to the same tempdir.
	//
	// To avoid reaching into ratatoskr internals from another package,
	// we drive the subprocess via a generator script embedded inline
	// below: write an openpyxl-using script to disk, invoke it, remove.
	scriptPath := filepath.Join(dir, "gen.py")
	script := `
import sys
from openpyxl import Workbook
wb = Workbook()
ws = wb.active
ws.title = "Employees"
ws.append(["First Name", "Surname", "Emp ID", "Started", "State", "Zip"])
ws.append(["Alice", "Anderson", "E001", "2024-03-15", "IL", "62701"])
ws.append(["Bob",   "Burton",   "E002", "2024-04-01", "WI", "53703"])
wb.save(sys.argv[1])
`
	if err := os.WriteFile(scriptPath, []byte(script), 0o644); err != nil {
		t.Fatalf("write gen script: %v", err)
	}
	// parser.ParseXLSX can't run arbitrary scripts; we need a direct
	// PythonCmd. Reach for that via the exported helper we add in
	// internal/ratatoskr (RunScript). If the helper isn't there yet this
	// test won't compile — that's the signal to add it.
	if _, err := parser.RunScript([]byte(script), path); err != nil {
		t.Fatalf("generate fixture: %v", err)
	}
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	return b
}

func uploadXLSX(t *testing.T, tc *testContext, module, filename string, payload []byte, estID int64) *httptest.ResponseRecorder {
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
	if _, err := part.Write(payload); err != nil {
		t.Fatalf("write payload: %v", err)
	}
	if err := mw.Close(); err != nil {
		t.Fatalf("multipart close: %v", err)
	}

	req := httptest.NewRequest("POST", "/api/import/xlsx/"+module, &body)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	return w
}

func TestImportLifecycleEmployeesXLSX(t *testing.T) {
	tc := newTestServerWithDB(t)
	payload := makeXLSXFixture(t)

	// Upload the xlsx.
	up := uploadXLSX(t, tc, "employees", "emps.xlsx", payload, 1)
	if up.Code != http.StatusCreated {
		t.Fatalf("xlsx upload = %d; %s", up.Code, up.Body.String())
	}
	var preview struct {
		Token    string            `json:"token"`
		Mapping  map[string]string `json:"mapping"`
		RowCount int               `json:"row_count"`
	}
	json.NewDecoder(up.Body).Decode(&preview)
	if preview.Token == "" {
		t.Fatal("no token returned")
	}
	if preview.RowCount != 2 {
		t.Errorf("row_count = %d, want 2", preview.RowCount)
	}
	if preview.Mapping["First Name"] != "first_name" {
		t.Errorf("mapping first_name: %v", preview.Mapping)
	}

	// Commit through the shared CSV route (lifecycle routes are shared).
	req := httptest.NewRequest("POST", "/api/import/csv/employees/"+preview.Token+"/commit", nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("commit = %d; %s", w.Code, w.Body.String())
	}
	var result struct {
		InsertedCount int `json:"inserted_count"`
		SkippedCount  int `json:"skipped_count"`
	}
	json.NewDecoder(w.Body).Decode(&result)
	if result.InsertedCount != 2 || result.SkippedCount != 0 {
		t.Errorf("result = %+v, want inserted=2 skipped=0", result)
	}

	// Confirm rows landed in the employees table.
	row, _ := tc.srv.db.QueryRow(`SELECT COUNT(*) AS c FROM employees`)
	if row["c"].(int64) != 2 {
		t.Errorf("employees count = %v, want 2", row["c"])
	}
}

func TestImportXLSXUnknownModuleIs404(t *testing.T) {
	tc := newTestServerWithDB(t)
	payload := makeXLSXFixture(t)
	w := uploadXLSX(t, tc, "not-a-module", "x.xlsx", payload, 1)
	if w.Code != http.StatusNotFound {
		t.Errorf("unknown module = %d, want 404; body=%s", w.Code, w.Body.String())
	}
}
