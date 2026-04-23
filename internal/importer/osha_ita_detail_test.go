package importer

import (
	"bytes"
	"testing"
)

// Column order matches the ITA detail CSV spec so any row of fixture
// data we assemble matches what /api/osha/ita/detail.csv would emit.
const itaDetailHeader = "establishment_name,year_of_filing,case_number,job_title,date_of_incident,incident_location,incident_description,incident_outcome,dafw_num_away,djtr_num_tr,type_of_incident,date_of_birth,date_of_hire,sex,treatment_facility_type,treatment_in_patient,time_started_work,time_of_incident,time_unknown,nar_before_incident,nar_what_happened,nar_injury_illness,nar_object_substance,date_of_death"

func TestOSHAITADetailMapperHappyPath(t *testing.T) {
	engine, db := newTestEngine(t)
	estID := int64(1)

	row := "Acme Test Plant,2025,2025-001,Process Operator,2025-03-10,Tank farm area B,Crushed by forklift during drum loading.,Death,,,Injury,1985-03-15,2018-06-01,F,Hospital Emergency Room,Y,,,N,,,,,2025-03-10"
	csv := itaDetailHeader + "\n" + row + "\n"

	preview, err := engine.Upload("osha_ita_detail", "testuser", "ita.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if len(preview.ValidationErrors) != 0 {
		t.Fatalf("unexpected validation errors: %+v", preview.ValidationErrors)
	}

	result, err := engine.Commit(preview.Token, "testuser", false)
	if err != nil {
		t.Fatalf("Commit: %v", err)
	}
	if result.InsertedCount != 1 {
		t.Errorf("inserted = %d, want 1", result.InsertedCount)
	}

	// Verify the incident landed with the correct reverse-mapped codes
	// and demographic fields dropped (no employee linkage).
	inc, err := db.QueryRow(
		`SELECT case_number, severity_code, case_classification_code,
		        treatment_facility_type_code, was_hospitalized, date_of_death,
		        employee_id, incident_description
		   FROM incidents WHERE case_number = ?`,
		"2025-001",
	)
	if err != nil {
		t.Fatalf("query incident: %v", err)
	}
	if inc == nil {
		t.Fatal("incident not found after import")
	}

	checks := map[string]any{
		"severity_code":                "FATALITY",
		"case_classification_code":     "INJURY",
		"treatment_facility_type_code": "HOSPITAL_ER",
		"was_hospitalized":             int64(1),
		"date_of_death":                "2025-03-10",
		"employee_id":                  nil,
		"incident_description":         "Crushed by forklift during drum loading.",
	}
	for col, want := range checks {
		if inc[col] != want {
			t.Errorf("%s = %v (%T), want %v (%T)", col, inc[col], inc[col], want, want)
		}
	}
}

func TestOSHAITADetailMapperUpsertsExistingCase(t *testing.T) {
	engine, db := newTestEngine(t)
	estID := int64(1)

	// Pre-seed an incident with case_number 2025-001 — pretend a prior
	// import dropped it in. Re-importing the same case should UPDATE
	// (not duplicate) and preserve the existing employee_id.
	if err := db.ExecParams(
		`INSERT INTO incidents (
		     id, establishment_id, case_number, employee_id,
		     incident_date, incident_description, severity_code)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		500, estID, "2025-001", nil,
		"2025-01-01", "Placeholder", "FIRST_AID",
	); err != nil {
		t.Fatalf("seed existing incident: %v", err)
	}

	// Re-import via CSV with updated values (date + severity + description).
	row := "Acme Test Plant,2025,2025-001,,2025-03-10,,Chemical burn treated at ER.,Days Away From Work,7,,Injury,,,,Hospital Emergency Room,Y,,,N,,,,,"
	csv := itaDetailHeader + "\n" + row + "\n"

	preview, err := engine.Upload("osha_ita_detail", "testuser", "ita.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if len(preview.ValidationErrors) != 0 {
		t.Fatalf("unexpected validation errors: %+v", preview.ValidationErrors)
	}
	result, err := engine.Commit(preview.Token, "testuser", false)
	if err != nil {
		t.Fatalf("Commit: %v", err)
	}

	// The engine reports inserted_count = 1 because our InsertRow signature
	// doesn't distinguish insert-vs-update (it returns an id either way).
	// What we care about is that we still have ONE incident (not two)
	// with the updated fields.
	countVal, err := db.QueryVal(`SELECT COUNT(*) FROM incidents WHERE case_number = ?`, "2025-001")
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if n, _ := countVal.(int64); n != 1 {
		t.Errorf("incident count = %d, want 1 (upsert should not duplicate)", n)
	}
	_ = result

	inc, _ := db.QueryRow(
		`SELECT id, severity_code, incident_date, incident_description, days_away_from_work
		   FROM incidents WHERE case_number = ?`,
		"2025-001",
	)
	if inc == nil {
		t.Fatal("incident not found after re-import")
	}
	if id, _ := inc["id"].(int64); id != 500 {
		t.Errorf("id = %v, want 500 (existing row should have been updated)", inc["id"])
	}
	if inc["severity_code"] != "LOST_TIME" {
		t.Errorf("severity_code = %v, want LOST_TIME", inc["severity_code"])
	}
	if inc["incident_date"] != "2025-03-10" {
		t.Errorf("incident_date = %v, want 2025-03-10", inc["incident_date"])
	}
	if inc["incident_description"] != "Chemical burn treated at ER." {
		t.Errorf("incident_description = %v, want updated text", inc["incident_description"])
	}
	if inc["days_away_from_work"].(int64) != 7 {
		t.Errorf("days_away_from_work = %v, want 7", inc["days_away_from_work"])
	}
}

func TestOSHAITADetailMapperValidation(t *testing.T) {
	engine, _ := newTestEngine(t)
	estID := int64(1)

	// Row 1: missing case_number
	// Row 2: unknown outcome "Maimed"
	// Row 3: bad date format
	// Row 4: unknown type_of_incident
	// Row 5: valid baseline
	csv := itaDetailHeader + "\n" +
		"A,2025,,Op,2025-01-01,,What happened 1,Death,,,Injury,,,,,,,,,,,,,," + "\n" +
		"A,2025,C2,Op,2025-01-02,,What happened 2,Maimed,,,Injury,,,,,,,,,,,,,," + "\n" +
		"A,2025,C3,Op,not-a-date,,What happened 3,Death,,,Injury,,,,,,,,,,,,,," + "\n" +
		"A,2025,C4,Op,2025-01-04,,What happened 4,Death,,,Teleportation,,,,,,,,,,,,,," + "\n" +
		"A,2025,C5,Op,2025-01-05,,What happened 5,Death,,,Injury,,,,,,,,,,,,,," + "\n"

	preview, err := engine.Upload("osha_ita_detail", "testuser", "ita.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}

	// Expect errors on rows 1, 2, 3, 4. Row 5 is valid.
	byRow := map[int][]string{}
	for _, e := range preview.ValidationErrors {
		byRow[e.Row] = append(byRow[e.Row], e.Column+": "+e.Message)
	}
	for _, r := range []int{1, 2, 3, 4} {
		if len(byRow[r]) == 0 {
			t.Errorf("row %d expected at least one validation error, got none", r)
		}
	}
	if len(byRow[5]) != 0 {
		t.Errorf("row 5 unexpectedly errored: %+v", byRow[5])
	}
}
