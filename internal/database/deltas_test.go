package database

import (
	"os"
	"testing"
	"testing/fstest"
)

// TestApplyDeltas_PreV33DB simulates the real migration scenario: a
// database created before Phase 4a.2 (no ITA lookup tables, no ITA
// columns on establishments / incidents). Running the v3.3 delta
// should bring it up to current shape.
func TestApplyDeltas_PreV33DB(t *testing.T) {
	db, err := Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	// Hand-seed a minimal pre-v3.3 schema: just the tables the delta
	// will touch (establishments + incidents), in their pre-widening
	// shape. No ITA columns, no ITA lookup tables. _migrations must
	// exist because the delta runner writes to it.
	ddl := `
		CREATE TABLE _migrations (name TEXT PRIMARY KEY, applied TEXT DEFAULT (datetime('now')));

		CREATE TABLE establishments (
		    id INTEGER PRIMARY KEY AUTOINCREMENT,
		    name TEXT NOT NULL
		);

		-- case_classifications + incident_severity_levels are FK targets
		-- for the v3.3 mapping tables. Seed the full row set that
		-- module_c_osha300.sql ships with so the delta's mapping-table
		-- INSERTs don't hit FK violations.
		CREATE TABLE case_classifications (
		    code TEXT PRIMARY KEY,
		    name TEXT NOT NULL
		);
		INSERT INTO case_classifications (code, name) VALUES
		    ('INJURY', 'Injury'), ('SKIN', 'Skin'), ('RESP', 'Respiratory'),
		    ('POISON', 'Poisoning'), ('HEARING', 'Hearing Loss'), ('OTHER_ILL', 'Other Illness');

		CREATE TABLE incident_severity_levels (
		    code TEXT PRIMARY KEY,
		    name TEXT NOT NULL
		);
		INSERT INTO incident_severity_levels (code, name) VALUES
		    ('FATALITY', 'Fatality'), ('LOST_TIME', 'Lost Time'),
		    ('RESTRICTED', 'Restricted'), ('MEDICAL_TX', 'Medical Treatment'),
		    ('FIRST_AID', 'First Aid'), ('NEAR_MISS', 'Near Miss'),
		    ('PROPERTY', 'Property'), ('ENVIRONMENTAL', 'Environmental');

		CREATE TABLE incidents (
		    id INTEGER PRIMARY KEY AUTOINCREMENT,
		    establishment_id INTEGER NOT NULL REFERENCES establishments(id),
		    case_number TEXT,
		    severity_code TEXT REFERENCES incident_severity_levels(code)
		);
	`
	if err := db.Exec(ddl); err != nil {
		t.Fatalf("seed pre-v3.3 schema: %v", err)
	}

	// Point the delta runner at the real delta file on disk.
	deltaFS := os.DirFS("../../docs/database-design/sql/deltas")
	if err := ApplyDeltas(db, deltaFS); err != nil {
		t.Fatalf("ApplyDeltas: %v", err)
	}

	// New columns on establishments.
	for _, col := range []string{"ein", "company_name", "size_code", "establishment_type_code"} {
		exists, err := columnExists(db, "establishments", col)
		if err != nil {
			t.Fatalf("column check %s: %v", col, err)
		}
		if !exists {
			t.Errorf("establishments is missing column %q after delta", col)
		}
	}
	// New columns on incidents.
	for _, col := range []string{
		"treatment_facility_type_code", "days_away_from_work",
		"days_restricted_or_transferred", "date_of_death",
		"time_unknown", "injury_illness_description",
	} {
		exists, err := columnExists(db, "incidents", col)
		if err != nil {
			t.Fatalf("column check %s: %v", col, err)
		}
		if !exists {
			t.Errorf("incidents is missing column %q after delta", col)
		}
	}

	// Lookup tables created + seeded.
	tableCounts := map[string]int{
		"ita_establishment_sizes":      3,
		"ita_establishment_types":      3,
		"ita_treatment_facility_types": 7,
		"ita_incident_outcomes":        4,
		"ita_incident_types":           6,
		"ita_outcome_mapping":          4,
		"ita_case_type_mapping":        6,
	}
	for table, want := range tableCounts {
		val, err := db.QueryVal("SELECT COUNT(*) FROM " + table)
		if err != nil {
			t.Errorf("count %s: %v", table, err)
			continue
		}
		if n, _ := val.(int64); int(n) != want {
			t.Errorf("%s row count = %d, want %d", table, n, want)
		}
	}

	// _migrations tracks the delta by name.
	appliedVal, err := db.QueryVal(`SELECT name FROM _migrations WHERE name = ?`, "2026-04-22-v3.3-osha-ita.sql")
	if err != nil {
		t.Fatalf("check _migrations: %v", err)
	}
	if appliedVal == nil {
		t.Error("delta not recorded in _migrations")
	}
}

// TestApplyDeltas_IdempotentOnReRun confirms that running the same
// delta twice is a no-op the second time (pragma_table_info guard on
// ALTER + IF NOT EXISTS on CREATE + INSERT OR IGNORE on seeds).
func TestApplyDeltas_IdempotentOnReRun(t *testing.T) {
	db, err := Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	// Apply the full module_c schema first — this is the "fresh install"
	// scenario where the delta would be a total no-op.
	migrations, err := CollectMigrations(os.DirFS("../../docs/database-design/sql"))
	if err != nil {
		t.Fatalf("collect migrations: %v", err)
	}
	if err := Migrate(db, migrations); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	deltaFS := os.DirFS("../../docs/database-design/sql/deltas")

	// First run — delta marks applied. (No-op data-wise because the
	// module already created everything.)
	if err := ApplyDeltas(db, deltaFS); err != nil {
		t.Fatalf("first ApplyDeltas: %v", err)
	}

	// Second run — must not re-execute (tracked in _migrations), but
	// even if re-executed (forced via a different path) the statements
	// would all no-op. Safest case.
	if err := ApplyDeltas(db, deltaFS); err != nil {
		t.Fatalf("second ApplyDeltas: %v", err)
	}

	// Lookup tables should have exactly their seeded row count — no
	// duplication.
	val, _ := db.QueryVal("SELECT COUNT(*) FROM ita_establishment_sizes")
	if n, _ := val.(int64); n != 3 {
		t.Errorf("ita_establishment_sizes count = %d after double-apply, want 3", n)
	}
}

// TestApplyDeltas_SkipsAlreadyApplied confirms that a delta marked
// applied doesn't re-execute even if forced to.
func TestApplyDeltas_SkipsAlreadyApplied(t *testing.T) {
	db, err := Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	if err := db.Exec(`
		CREATE TABLE _migrations (name TEXT PRIMARY KEY, applied TEXT DEFAULT (datetime('now')));
		INSERT INTO _migrations (name) VALUES ('already-applied.sql');
	`); err != nil {
		t.Fatalf("seed: %v", err)
	}

	// Craft an in-memory delta that would blow up if executed. The
	// runner must skip it entirely because it's already in _migrations.
	bad := fstest.MapFS{
		"already-applied.sql": &fstest.MapFile{
			Data: []byte(`CREATE TABLE would_fail_if_run (invalid INVALID);`),
		},
	}
	if err := ApplyDeltas(db, bad); err != nil {
		t.Errorf("skipped delta shouldn't error, got: %v", err)
	}
}

// --- parser-level tests --------------------------------------------------

func TestParseAlterAddColumn(t *testing.T) {
	cases := []struct {
		in        string
		wantTable string
		wantCol   string
		wantOK    bool
	}{
		{"ALTER TABLE foo ADD COLUMN bar TEXT", "foo", "bar", true},
		{"ALTER TABLE foo ADD bar TEXT", "foo", "bar", true},
		{"  alter   table   users   add  column   ein   TEXT", "users", "ein", true},
		{"ALTER TABLE t ADD COLUMN c REFERENCES x(y)", "t", "c", true},
		{"CREATE TABLE foo (bar TEXT)", "", "", false},
		{"UPDATE establishments SET ein = ?", "", "", false},
		{"ALTER TABLE foo DROP COLUMN bar", "", "", false},
	}
	for _, tc := range cases {
		table, col, ok := parseAlterAddColumn(tc.in)
		if ok != tc.wantOK || table != tc.wantTable || col != tc.wantCol {
			t.Errorf("parseAlterAddColumn(%q) = (%q, %q, %v); want (%q, %q, %v)",
				tc.in, table, col, ok, tc.wantTable, tc.wantCol, tc.wantOK)
		}
	}
}

func TestSplitSQLStatements(t *testing.T) {
	in := `
		-- This is a comment; it should be stripped.
		CREATE TABLE foo (a TEXT);
		INSERT INTO foo VALUES ('one ; two; three');  -- note the semicolons in the string
		ALTER TABLE foo ADD COLUMN b INT;
	`
	stmts := splitSQLStatements(in)
	if len(stmts) != 3 {
		t.Fatalf("got %d statements, want 3: %+v", len(stmts), stmts)
	}
	// Semicolons inside string literal should be preserved intact.
	wantInSecond := "'one ; two; three'"
	found := false
	for _, s := range stmts {
		if contains(s, wantInSecond) {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("string literal not preserved; got statements: %+v", stmts)
	}
}

func contains(haystack, needle string) bool {
	return len(haystack) >= len(needle) && indexOf(haystack, needle) >= 0
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}
