package importer

import (
	"bytes"
	"testing"
)

const itaSummaryHeader = "establishment_name,ein,company_name,street_address,city,state,zip,naics_code,industry_description,size,establishment_type,year_filing_for,annual_average_employees,total_hours_worked,no_injuries_illnesses,total_deaths,total_dafw_cases,total_djtr_cases,total_other_cases,total_dafw_days,total_djtr_days,total_injuries,total_skin_disorders,total_respiratory_conditions,total_poisonings,total_hearing_loss,total_other_illnesses,change_reason"

func TestOSHAITASummaryMapperUpdatesEstablishmentOnly(t *testing.T) {
	engine, db := newTestEngine(t)
	estID := int64(1)

	// Baseline: establishment exists with no annual_avg / hours yet.
	// Confirm those columns are currently NULL.
	before, err := db.QueryRow(
		`SELECT annual_avg_employees, total_hours_worked FROM establishments WHERE id = ?`, estID,
	)
	if err != nil {
		t.Fatalf("before query: %v", err)
	}
	if before["annual_avg_employees"] != nil {
		t.Errorf("baseline annual_avg_employees = %v, want nil", before["annual_avg_employees"])
	}

	row := "Test Facility,12-3456789,Test Holdings,123 Industrial Pkwy,Springfield,IL,62701,325199,Test,Large (≥ 250 employees),Private Industry,2025,300,600000,N,1,1,1,0,10,5,2,0,1,0,0,0,"
	csv := itaSummaryHeader + "\n" + row + "\n"

	preview, err := engine.Upload("osha_ita_summary", "testuser", "ita-summary.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if len(preview.ValidationErrors) != 0 {
		t.Fatalf("unexpected validation errors: %+v", preview.ValidationErrors)
	}
	if _, err := engine.Commit(preview.Token, "testuser", false); err != nil {
		t.Fatalf("Commit: %v", err)
	}

	// After: the establishment's two scoped fields updated; the 12 total_*
	// counts and establishment-identifying fields untouched.
	after, err := db.QueryRow(
		`SELECT annual_avg_employees, total_hours_worked, name, ein FROM establishments WHERE id = ?`, estID,
	)
	if err != nil {
		t.Fatalf("after query: %v", err)
	}
	if after["annual_avg_employees"].(int64) != 300 {
		t.Errorf("annual_avg_employees = %v, want 300", after["annual_avg_employees"])
	}
	if after["total_hours_worked"].(int64) != 600000 {
		t.Errorf("total_hours_worked = %v, want 600000", after["total_hours_worked"])
	}
	// name should be unchanged from the test-engine seed.
	if after["name"] != "Test Facility" {
		t.Errorf("name = %v, want unchanged 'Test Facility'", after["name"])
	}
	// ein was never set and should stay NULL (CSV's ein value is declared-but-dropped).
	if after["ein"] != nil {
		t.Errorf("ein = %v, want nil (declared-but-dropped)", after["ein"])
	}

	// No new incidents landed — this importer only updates establishments.
	countVal, _ := db.QueryVal(`SELECT COUNT(*) FROM incidents`)
	if n, _ := countVal.(int64); n != 0 {
		t.Errorf("incident count = %d, want 0 (summary must not create incidents)", n)
	}
}

func TestOSHAITASummaryMapperRejectsEmptyRow(t *testing.T) {
	engine, _ := newTestEngine(t)
	estID := int64(1)

	// Row with both annual_average_employees and total_hours_worked blank
	// — nothing to update. Should flag a validation error so the user
	// isn't surprised by a silently-successful no-op.
	row := "Test Facility,,,,,,,,,,,2025,,,N,0,0,0,0,0,0,0,0,0,0,0,0,"
	csv := itaSummaryHeader + "\n" + row + "\n"

	preview, err := engine.Upload("osha_ita_summary", "testuser", "ita-summary.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if len(preview.ValidationErrors) == 0 {
		t.Fatal("expected at least one validation error for empty row, got none")
	}
}

func TestOSHAITASummaryMapperPartialUpdate(t *testing.T) {
	engine, db := newTestEngine(t)
	estID := int64(1)

	// Set a baseline total_hours_worked directly on the establishment.
	if err := db.ExecParams(
		`UPDATE establishments SET total_hours_worked = ? WHERE id = ?`,
		400000, estID,
	); err != nil {
		t.Fatalf("seed total_hours_worked: %v", err)
	}

	// Import a CSV that sets only annual_average_employees (hours blank).
	// The existing total_hours_worked must NOT be wiped to 0 / NULL.
	row := "Test Facility,,,,,,,,,,,2025,150,,N,0,0,0,0,0,0,0,0,0,0,0,0,"
	csv := itaSummaryHeader + "\n" + row + "\n"

	preview, err := engine.Upload("osha_ita_summary", "testuser", "ita-summary.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if len(preview.ValidationErrors) != 0 {
		t.Fatalf("unexpected errors: %+v", preview.ValidationErrors)
	}
	if _, err := engine.Commit(preview.Token, "testuser", false); err != nil {
		t.Fatalf("Commit: %v", err)
	}

	after, _ := db.QueryRow(
		`SELECT annual_avg_employees, total_hours_worked FROM establishments WHERE id = ?`, estID,
	)
	if after["annual_avg_employees"].(int64) != 150 {
		t.Errorf("annual_avg_employees = %v, want 150", after["annual_avg_employees"])
	}
	if after["total_hours_worked"].(int64) != 400000 {
		t.Errorf("total_hours_worked = %v, want 400000 (preserved); partial update must not wipe unprovided fields", after["total_hours_worked"])
	}
}
