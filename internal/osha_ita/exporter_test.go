package osha_ita

import (
	"encoding/csv"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/asgardehs/odin/internal/database"
)

// seedExportTestDB creates an in-memory DB, applies the schema
// migrations, and seeds a test fixture designed to exercise the ITA
// export path. Returns the DB (closed on t.Cleanup) and the establishment
// ID used for seeding.
func seedExportTestDB(t *testing.T) (*database.DB, int64) {
	t.Helper()

	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	sqlDir := os.DirFS("../../docs/database-design/sql")
	migrations, err := database.CollectMigrations(sqlDir)
	if err != nil {
		t.Fatalf("collect migrations: %v", err)
	}
	if err := database.Migrate(db, migrations); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	deltaDir := os.DirFS("../../docs/database-design/sql/deltas")
	if err := database.ApplyDeltas(db, deltaDir); err != nil {
		t.Fatalf("apply deltas: %v", err)
	}
	// Views live in a sibling directory, re-executed every startup in prod.
	viewsDir := os.DirFS("../../docs/database-design/sql/views")
	if err := database.LoadViews(db, viewsDir); err != nil {
		t.Fatalf("load views: %v", err)
	}

	// Establishment with all ITA fields populated.
	if err := db.ExecParams(
		`INSERT INTO establishments (id, name, street_address, city, state, zip,
		        naics_code, industry_description,
		        annual_avg_employees, total_hours_worked,
		        ein, company_name, size_code, establishment_type_code)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		1, "Acme Test Plant", "100 Test Way", "Detroit", "MI", "48201",
		"325199", "Test Industrial Chemicals",
		300, 600000,
		"12-3456789", "Acme Holdings", "LARGE", "PRIVATE",
	); err != nil {
		t.Fatalf("seed establishment: %v", err)
	}

	// Three employees spanning three job titles + demographics.
	employees := []struct {
		id       int64
		first    string
		last     string
		dob      string
		hired    string
		gender   string
		jobTitle string
	}{
		{1, "Jane", "Smith", "1985-03-15", "2018-06-01", "F", "Process Operator"},
		{2, "John", "Doe", "1972-11-02", "2010-01-15", "M", "Maintenance Tech"},
		{3, "Alex", "Chen", "1990-08-22", "2020-05-10", "X", "Lab Tech"},
	}
	for _, e := range employees {
		if err := db.ExecParams(
			`INSERT INTO employees (id, establishment_id, first_name, last_name,
			        date_of_birth, date_hired, gender, job_title)
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			e.id, 1, e.first, e.last, e.dob, e.hired, e.gender, e.jobTitle,
		); err != nil {
			t.Fatalf("seed employee %d: %v", e.id, err)
		}
	}

	// Four incidents: three recordable (each mapping to a distinct ITA
	// outcome), one non-recordable (FIRST_AID) to verify filtering.
	type seedIncident struct {
		id           int64
		employeeID   int64
		date         string
		caseNumber   string
		severity     string
		caseClass    string
		description  string
		location     string
		daysAway     *int
		daysRestrict *int
	}
	twoAway := 10
	fiveRestrict := 5
	incidents := []seedIncident{
		{101, 1, "2025-03-10", "2025-001", "FATALITY", "INJURY",
			"Crushed by forklift during drum loading.", "Loading dock",
			nil, nil},
		{102, 2, "2025-06-15", "2025-002", "LOST_TIME", "RESP",
			"Chronic bronchitis after solvent exposure.", "Compounding room",
			&twoAway, nil},
		{103, 3, "2025-09-20", "2025-003", "RESTRICTED", "INJURY",
			"Lower back strain from repeated lifting.", "Packaging line",
			nil, &fiveRestrict},
		{104, 1, "2025-11-05", "2025-004", "FIRST_AID", "INJURY",
			"Minor cut treated with bandage.", "Shipping dock",
			nil, nil},
	}
	for _, inc := range incidents {
		if err := db.ExecParams(
			`INSERT INTO incidents (id, establishment_id, employee_id, case_number,
			        incident_date, incident_description, location_description,
			        severity_code, case_classification_code,
			        days_away_from_work, days_restricted_or_transferred)
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			inc.id, 1, inc.employeeID, inc.caseNumber,
			inc.date, inc.description, inc.location,
			inc.severity, inc.caseClass,
			inc.daysAway, inc.daysRestrict,
		); err != nil {
			t.Fatalf("seed incident %d: %v", inc.id, err)
		}
	}

	return db, 1
}

// --- ExportDetail ---

func TestExportDetail_FiltersNonRecordableAndEmitsFullShape(t *testing.T) {
	db, estID := seedExportTestDB(t)

	r, err := ExportDetail(db, estID, "2025")
	if err != nil {
		t.Fatalf("ExportDetail: %v", err)
	}
	records := mustReadCSV(t, r)

	// Header + 3 recordable rows (FIRST_AID excluded). FIRST_AID, NEAR_MISS,
	// PROPERTY, ENVIRONMENTAL are non-mapping in ita_outcome_mapping and
	// should not appear in the CSV.
	if got, want := len(records), 4; got != want {
		t.Fatalf("len(records) = %d, want %d (header + 3 recordable rows)", got, want)
	}

	// Header row must match the 24-column ITA spec order.
	if got, want := len(records[0]), 24; got != want {
		t.Errorf("header has %d cols, want %d", got, want)
	}
	expectedHeaders := DetailColumns()
	for i, want := range expectedHeaders {
		if records[0][i] != want {
			t.Errorf("header[%d] = %q, want %q", i, records[0][i], want)
		}
	}

	// Spot-check specific columns on the three recordable rows. Rows come
	// back in whatever order the view emits; build a map by case_number.
	rowsByCaseNumber := map[string][]string{}
	for _, row := range records[1:] {
		rowsByCaseNumber[row[indexOf(expectedHeaders, "case_number")]] = row
	}

	cases := []struct {
		caseNumber   string
		wantOutcome  string
		wantType     string
		wantDafw     string
		wantDjtr     string
		wantTreatIn  string // treatment_in_patient defaults to 'N' when was_hospitalized not set
		wantTimeUnk  string // time_unknown defaults to 'N'
		wantSex      string
	}{
		{"2025-001", "Death", "Injury", "", "", "N", "N", "F"},
		{"2025-002", "Days Away From Work", "Respiratory Condition", "10", "", "N", "N", "M"},
		{"2025-003", "Job Transfer or Restriction", "Injury", "", "5", "N", "N", "X"},
	}
	for _, c := range cases {
		row, ok := rowsByCaseNumber[c.caseNumber]
		if !ok {
			t.Errorf("case %s not in CSV", c.caseNumber)
			continue
		}
		check := func(col, want string) {
			t.Helper()
			got := row[indexOf(expectedHeaders, col)]
			if got != want {
				t.Errorf("case %s: %s = %q, want %q", c.caseNumber, col, got, want)
			}
		}
		check("incident_outcome", c.wantOutcome)
		check("type_of_incident", c.wantType)
		check("dafw_num_away", c.wantDafw)
		check("djtr_num_tr", c.wantDjtr)
		check("treatment_in_patient", c.wantTreatIn)
		check("time_unknown", c.wantTimeUnk)
		check("sex", c.wantSex)
		check("year_of_filing", "2025")
	}
}

// --- ExportSummary ---

func TestExportSummary_AggregatesAcrossIncidents(t *testing.T) {
	db, estID := seedExportTestDB(t)

	r, err := ExportSummary(db, estID, "2025")
	if err != nil {
		t.Fatalf("ExportSummary: %v", err)
	}
	records := mustReadCSV(t, r)

	if got, want := len(records), 2; got != want {
		t.Fatalf("len(records) = %d, want 2 (header + 1 summary row)", got)
	}
	if got, want := len(records[0]), 28; got != want {
		t.Errorf("header has %d cols, want %d", got, want)
	}
	headers := SummaryColumns()
	row := records[1]

	check := func(col, want string) {
		t.Helper()
		got := row[indexOf(headers, col)]
		if got != want {
			t.Errorf("%s = %q, want %q", col, got, want)
		}
	}
	// Establishment info
	check("establishment_name", "Acme Test Plant")
	check("ein", "12-3456789")
	check("company_name", "Acme Holdings")
	// Labels come from the SQL seed (ita_establishment_sizes.name and
	// ita_establishment_types.name), not the ontology's rdfs:label —
	// intentional: the SQL is the source of truth for what the CSV emits.
	check("size", "Large (≥ 250 employees)")
	check("establishment_type", "Private Industry")
	check("year_filing_for", "2025")
	check("annual_average_employees", "300")
	check("total_hours_worked", "600000")

	// At least one recordable → no_injuries_illnesses='N'.
	check("no_injuries_illnesses", "N")

	// Outcome-bucket counts. Exactly one each of DEATH, DAYS_AWAY,
	// JOB_TRANSFER_RESTRICTION; zero OTHER_RECORDABLE.
	check("total_deaths", "1")
	check("total_dafw_cases", "1")
	check("total_djtr_cases", "1")
	check("total_other_cases", "0")

	// Day-sum totals (seeded 10 + 5).
	check("total_dafw_days", "10")
	check("total_djtr_days", "5")

	// Type-bucket counts. Two INJURY (case 2025-001 + 2025-003), one
	// RESPIRATORY_CONDITION (case 2025-002).
	check("total_injuries", "2")
	check("total_respiratory_conditions", "1")
	check("total_skin_disorders", "0")
	check("total_poisonings", "0")
	check("total_hearing_loss", "0")
	check("total_other_illnesses", "0")

	// change_reason NULL → empty string.
	check("change_reason", "")
}

func TestExportSummary_EmptyYear_SynthesizesZeroRow(t *testing.T) {
	db, estID := seedExportTestDB(t)

	// Request a year with zero recordable incidents.
	r, err := ExportSummary(db, estID, "2099")
	if err != nil {
		t.Fatalf("ExportSummary (empty year): %v", err)
	}
	records := mustReadCSV(t, r)

	if got, want := len(records), 2; got != want {
		t.Fatalf("len(records) = %d, want 2 (header + 1 synthesized row)", got)
	}
	headers := SummaryColumns()
	row := records[1]
	check := func(col, want string) {
		t.Helper()
		got := row[indexOf(headers, col)]
		if got != want {
			t.Errorf("%s = %q, want %q", col, got, want)
		}
	}

	// Establishment info still populated from the establishments table.
	check("establishment_name", "Acme Test Plant")
	check("ein", "12-3456789")
	check("year_filing_for", "2099")

	// no_injuries_illnesses='Y'; all counts/days zero.
	check("no_injuries_illnesses", "Y")
	check("total_deaths", "0")
	check("total_dafw_cases", "0")
	check("total_djtr_cases", "0")
	check("total_other_cases", "0")
	check("total_dafw_days", "0")
	check("total_djtr_days", "0")
	check("total_injuries", "0")
	check("total_respiratory_conditions", "0")
	check("change_reason", "")
}

// --- Preview ---

func TestPreview_ReturnsCountsAndHeaders(t *testing.T) {
	db, estID := seedExportTestDB(t)

	preview, err := Preview(db, estID, "2025")
	if err != nil {
		t.Fatalf("Preview: %v", err)
	}
	if !preview.EstablishmentKnown {
		t.Error("EstablishmentKnown = false, want true")
	}
	if preview.EstablishmentName != "Acme Test Plant" {
		t.Errorf("EstablishmentName = %q, want Acme Test Plant", preview.EstablishmentName)
	}
	if preview.DetailRowCount != 3 {
		t.Errorf("DetailRowCount = %d, want 3", preview.DetailRowCount)
	}
	if preview.NoInjuriesFlag != "N" {
		t.Errorf("NoInjuriesFlag = %q, want N", preview.NoInjuriesFlag)
	}
	if len(preview.DetailColumns) != 24 {
		t.Errorf("len(DetailColumns) = %d, want 24", len(preview.DetailColumns))
	}
	if len(preview.SummaryColumns) != 28 {
		t.Errorf("len(SummaryColumns) = %d, want 28", len(preview.SummaryColumns))
	}
}

func TestPreview_EmptyYearFlagsY(t *testing.T) {
	db, estID := seedExportTestDB(t)

	preview, err := Preview(db, estID, "2099")
	if err != nil {
		t.Fatalf("Preview: %v", err)
	}
	if preview.DetailRowCount != 0 {
		t.Errorf("DetailRowCount = %d, want 0", preview.DetailRowCount)
	}
	if preview.NoInjuriesFlag != "Y" {
		t.Errorf("NoInjuriesFlag = %q, want Y", preview.NoInjuriesFlag)
	}
}

func TestPreview_UnknownEstablishment(t *testing.T) {
	db, _ := seedExportTestDB(t)

	preview, err := Preview(db, 9999, "2025")
	if err != nil {
		t.Fatalf("Preview: %v", err)
	}
	if preview.EstablishmentKnown {
		t.Error("EstablishmentKnown = true, want false")
	}
}

// --- Helpers ---

func mustReadCSV(t *testing.T, r io.Reader) [][]string {
	t.Helper()
	reader := csv.NewReader(r)
	records, err := reader.ReadAll()
	if err != nil {
		t.Fatalf("csv read: %v", err)
	}
	return records
}

func indexOf(cols []string, want string) int {
	for i, c := range cols {
		if c == want {
			return i
		}
	}
	panic("column not in list: " + want + " (have: " + strings.Join(cols, ",") + ")")
}
