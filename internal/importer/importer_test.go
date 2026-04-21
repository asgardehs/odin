package importer

import (
	"bytes"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/asgardehs/odin/internal/audit"
	"github.com/asgardehs/odin/internal/database"
)

// ---- Fuzzy match ----------------------------------------------------------

func TestSuggestMappingExactAndFuzzy(t *testing.T) {
	fields := (&employeesImporter{}).TargetFields()

	headers := []string{
		"First Name",   // exact on label -> first_name
		"Emp ID",       // alias of employee_number
		"Started",      // alias of date_hired
		"Surname",      // alias of last_name
		"Favorite Color", // no match
	}
	got := SuggestMapping(headers, fields)

	assertMapping := func(src, wantTarget string) {
		t.Helper()
		if got[src] != wantTarget {
			t.Errorf("mapping[%q] = %q, want %q", src, got[src], wantTarget)
		}
	}
	assertMapping("First Name", "first_name")
	assertMapping("Emp ID", "employee_number")
	assertMapping("Started", "date_hired")
	assertMapping("Surname", "last_name")
	assertMapping("Favorite Color", IgnoreMarker)
}

func TestSuggestMappingDoesNotDoubleBind(t *testing.T) {
	// Two source headers both look like a job_title alias. Only one
	// should claim the target; the other falls back to IgnoreMarker.
	fields := []TargetField{
		{Name: "job_title", Label: "Job Title", Aliases: []string{"title", "position"}},
	}
	got := SuggestMapping([]string{"Title", "Position"}, fields)

	claimed := 0
	for _, v := range got {
		if v == "job_title" {
			claimed++
		}
	}
	if claimed != 1 {
		t.Errorf("job_title claimed %d times, want 1; got=%v", claimed, got)
	}
}

// ---- CSV parsing ----------------------------------------------------------

func TestParseCSVHandlesBOMAndRaggedRows(t *testing.T) {
	csv := "\ufefffirst_name,last_name,extra\nAlice,Anderson,ignored\nBob,Burton\n"
	headers, rows, err := parseCSV(strings.NewReader(csv))
	if err != nil {
		t.Fatalf("parseCSV: %v", err)
	}
	if headers[0] != "first_name" {
		t.Errorf("BOM not stripped: headers[0] = %q", headers[0])
	}
	if len(rows) != 2 {
		t.Fatalf("expected 2 rows, got %d", len(rows))
	}
	if rows[0]["first_name"] != "Alice" || rows[1]["last_name"] != "Burton" {
		t.Errorf("rows mis-parsed: %v", rows)
	}
}

// ---- Engine end-to-end ----------------------------------------------------

// newTestEngine spins up an in-memory DB with the full schema + auth app
// migrations applied, seeds one establishment, and returns an Engine
// ready to accept uploads.
func newTestEngine(t *testing.T) (*Engine, *database.DB) {
	t.Helper()
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	migrations, err := database.CollectMigrations(os.DirFS("../../docs/database-design/sql"))
	if err != nil {
		t.Fatalf("collect: %v", err)
	}
	if err := database.Migrate(db, migrations); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	auditDir := t.TempDir()
	store, err := audit.NewStore(auditDir, &stubAuth{})
	if err != nil {
		t.Fatalf("audit.NewStore: %v", err)
	}

	if err := db.ExecParams(
		`INSERT INTO establishments (id, name, street_address, city, state, zip)
		 VALUES (1, 'Test Facility', '123 Industrial Pkwy', 'Springfield', 'IL', '62701')`,
	); err != nil {
		t.Fatalf("seed establishment: %v", err)
	}

	return &Engine{DB: db, Audit: store, TTL: 5 * time.Minute}, db
}

type stubAuth struct{}

func (*stubAuth) Verify(_, _ string) error { return nil }
func (*stubAuth) CurrentUser() string      { return "test" }

func TestEngineHappyPathEmployees(t *testing.T) {
	engine, db := newTestEngine(t)
	estID := int64(1)

	// Deliberately messy headers to exercise fuzzy mapping + the employees
	// mapper's date parser.
	csv := "First Name,Surname,Emp ID,Started,Dept,State,Zip\n" +
		"Alice,Anderson,E001,2024-03-15,Welding,IL,62701\n" +
		"Bob,Burton,E002,03/15/2024,Paint,WI,53703\n"

	preview, err := engine.Upload("employees", "testuser", "emps.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if preview.RowCount != 2 {
		t.Errorf("RowCount = %d, want 2", preview.RowCount)
	}
	if preview.Mapping["First Name"] != "first_name" {
		t.Errorf("mapping first_name: %v", preview.Mapping)
	}
	if preview.Mapping["Emp ID"] != "employee_number" {
		t.Errorf("mapping employee_number: %v", preview.Mapping)
	}
	if len(preview.ValidationErrors) != 0 {
		t.Errorf("unexpected validation errors: %+v", preview.ValidationErrors)
	}

	result, err := engine.Commit(preview.Token, "testuser", false)
	if err != nil {
		t.Fatalf("Commit: %v", err)
	}
	if result.InsertedCount != 2 || result.SkippedCount != 0 {
		t.Errorf("result = %+v, want inserted=2 skipped=0", result)
	}

	// Confirm the rows actually landed.
	row, err := db.QueryRow(`SELECT COUNT(*) AS c FROM employees`)
	if err != nil || row["c"].(int64) != 2 {
		t.Errorf("employees count = %v (err=%v)", row["c"], err)
	}

	// Confirm dates were normalized to ISO form even though the source
	// used MM/DD/YYYY for row 2.
	row2, _ := db.QueryRow(`SELECT date_hired FROM employees WHERE last_name = 'Burton'`)
	if row2["date_hired"] != "2024-03-15" {
		t.Errorf("date normalized = %v, want 2024-03-15", row2["date_hired"])
	}
}

func TestEngineValidationErrorsBlockCommitUnlessSkipInvalid(t *testing.T) {
	engine, db := newTestEngine(t)
	estID := int64(1)

	csv := "First Name,Surname,State,Zip,Gender\n" +
		"Alice,Anderson,IL,62701,F\n" +
		",Missing,IL,62701,F\n" + // bad: no first_name
		"Carol,Carter,Illinois,62701,F\n" + // bad: state not 2 letters
		"Dan,Doe,IL,BAD,F\n" + // bad: zip
		"Eve,Evans,IL,62701,Q\n" // bad: gender
	preview, err := engine.Upload("employees", "testuser", "emps.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if len(preview.ValidationErrors) < 4 {
		t.Errorf("expected at least 4 validation errors, got %d: %+v",
			len(preview.ValidationErrors), preview.ValidationErrors)
	}

	// Without skip_invalid, the commit must refuse.
	if _, err := engine.Commit(preview.Token, "testuser", false); err == nil {
		t.Fatal("expected Commit to fail without skip_invalid")
	}

	// With skip_invalid, only the one valid row should land.
	result, err := engine.Commit(preview.Token, "testuser", true)
	if err != nil {
		t.Fatalf("Commit with skip_invalid: %v", err)
	}
	if result.InsertedCount != 1 {
		t.Errorf("inserted = %d, want 1", result.InsertedCount)
	}
	if result.SkippedCount != 4 {
		t.Errorf("skipped = %d, want 4", result.SkippedCount)
	}

	row, _ := db.QueryRow(`SELECT COUNT(*) AS c FROM employees`)
	if row["c"].(int64) != 1 {
		t.Errorf("employees count after commit = %v, want 1", row["c"])
	}
}

func TestEngineUpdateMappingAndReValidate(t *testing.T) {
	engine, _ := newTestEngine(t)
	estID := int64(1)

	// Row has "Stage Name" which the fuzzy matcher won't guess.
	csv := "Stage Name,Last\nAlice,Anderson\n"
	preview, err := engine.Upload("employees", "testuser", "x.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	// First pass: first_name unmapped → row should fail on required field.
	if len(preview.ValidationErrors) == 0 {
		t.Fatalf("expected validation error for missing first_name")
	}

	// Point Stage Name → first_name explicitly.
	newMapping := map[string]string{
		"Stage Name": "first_name",
		"Last":       "last_name",
	}
	updated, err := engine.UpdateMapping(preview.Token, "testuser", newMapping)
	if err != nil {
		t.Fatalf("UpdateMapping: %v", err)
	}
	if len(updated.ValidationErrors) != 0 {
		t.Errorf("post-remap errors: %+v", updated.ValidationErrors)
	}
}

func TestEngineExpiredToken(t *testing.T) {
	engine, _ := newTestEngine(t)
	estID := int64(1)

	engine.TTL = 1 * time.Millisecond
	csv := "First Name,Last Name\nAlice,Anderson\n"
	preview, err := engine.Upload("employees", "testuser", "x.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}

	time.Sleep(20 * time.Millisecond)
	if _, err := engine.GetStatus(preview.Token); err != ErrExpired {
		t.Errorf("expected ErrExpired, got %v", err)
	}
}

func TestEngineUnknownModule(t *testing.T) {
	engine, _ := newTestEngine(t)
	estID := int64(1)
	_, err := engine.Upload("not-a-module", "testuser", "x.csv",
		bytes.NewBufferString("a,b\n1,2\n"), &estID)
	if err != ErrUnknownModule {
		t.Errorf("expected ErrUnknownModule, got %v", err)
	}
}

func TestEngineDiscard(t *testing.T) {
	engine, db := newTestEngine(t)
	estID := int64(1)

	preview, _ := engine.Upload("employees", "testuser", "x.csv",
		bytes.NewBufferString("First Name,Last Name\nAlice,Anderson\n"), &estID)
	if err := engine.Discard(preview.Token, "testuser"); err != nil {
		t.Fatalf("Discard: %v", err)
	}
	row, _ := db.QueryRow(`SELECT status FROM _imports WHERE token = ?`, preview.Token)
	if row["status"] != "discarded" {
		t.Errorf("status = %v, want discarded", row["status"])
	}
}
