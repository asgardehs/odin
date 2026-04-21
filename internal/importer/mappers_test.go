package importer

import (
	"bytes"
	"testing"
)

func TestChemicalsMapperHappyPath(t *testing.T) {
	engine, db := newTestEngine(t)
	estID := int64(1)

	csv := "Product Name,Manufacturer,CAS #,Signal Word,State,Flash Pt,pH,Flammable,Carcinogen\n" +
		"Acetone,Acme Solvents,67-64-1,Danger,liquid,0,7,Y,N\n" +
		"MEK,Acme Solvents,78-93-3,Danger,liquid,16,7,Yes,No\n"
	preview, err := engine.Upload("chemicals", "testuser", "c.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if len(preview.ValidationErrors) != 0 {
		t.Errorf("unexpected validation errors: %+v", preview.ValidationErrors)
	}
	if preview.Mapping["Product Name"] != "product_name" || preview.Mapping["CAS #"] != "primary_cas_number" {
		t.Errorf("mapping: %v", preview.Mapping)
	}

	result, err := engine.Commit(preview.Token, "testuser", false)
	if err != nil {
		t.Fatalf("Commit: %v", err)
	}
	if result.InsertedCount != 2 {
		t.Errorf("inserted = %d, want 2", result.InsertedCount)
	}

	// Spot-check one row landed with the expected shape.
	row, _ := db.QueryRow(`SELECT product_name, signal_word, physical_state, is_flammable FROM chemicals WHERE product_name = 'Acetone'`)
	if row["signal_word"] != "Danger" {
		t.Errorf("signal_word = %v, want Danger", row["signal_word"])
	}
	if row["physical_state"] != "liquid" {
		t.Errorf("physical_state = %v, want liquid", row["physical_state"])
	}
	if row["is_flammable"].(int64) != 1 {
		t.Errorf("is_flammable = %v, want 1", row["is_flammable"])
	}
}

func TestChemicalsMapperValidation(t *testing.T) {
	engine, _ := newTestEngine(t)
	estID := int64(1)

	// Bad CAS, bad signal word, bad state, bad pH, bad flammable.
	csv := "Product Name,CAS #,Signal Word,State,pH,Flammable\n" +
		"BadCAS,not-a-cas,Danger,liquid,7,Y\n" +
		"BadSignal,67-64-1,Maybe,liquid,7,Y\n" +
		"BadState,67-64-1,Danger,plasma,7,Y\n" +
		"BadPH,67-64-1,Danger,liquid,20,Y\n" +
		"BadFlam,67-64-1,Danger,liquid,7,Sometimes\n"
	preview, err := engine.Upload("chemicals", "testuser", "c.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if len(preview.ValidationErrors) < 5 {
		t.Errorf("expected >=5 validation errors, got %d: %+v",
			len(preview.ValidationErrors), preview.ValidationErrors)
	}
}

func TestTrainingCompletionsMapperResolvesFKs(t *testing.T) {
	engine, db := newTestEngine(t)
	estID := int64(1)

	// Seed two employees + one training course.
	if err := db.ExecParams(
		`INSERT INTO employees (id, establishment_id, employee_number, first_name, last_name)
		 VALUES (1, 1, 'E001', 'Alice', 'Anderson'),
		        (2, 1, 'E002', 'Bob', 'Burton')`,
	); err != nil {
		t.Fatalf("seed employees: %v", err)
	}
	// Don't set id explicitly — module_training.sql seeds some built-in
	// courses so autoincrement starts above 1.
	if err := db.ExecParams(
		`INSERT INTO training_courses (establishment_id, course_code, course_name)
		 VALUES (1, 'HAZWOPER-24', 'HAZWOPER 24-hour')`,
	); err != nil {
		t.Fatalf("seed course: %v", err)
	}
	courseIDVal, _ := db.QueryVal(`SELECT id FROM training_courses WHERE course_code = 'HAZWOPER-24'`)
	courseID := courseIDVal.(int64)

	csv := "Employee Number,Course Code,Completion Date,Score,Passed\n" +
		"E001,HAZWOPER-24,2024-03-15,95,Y\n" +
		"E002,HAZWOPER-24,3/15/2024,88,Y\n"
	preview, err := engine.Upload("training_completions", "testuser", "tc.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if len(preview.ValidationErrors) != 0 {
		t.Errorf("unexpected validation errors: %+v", preview.ValidationErrors)
	}

	result, err := engine.Commit(preview.Token, "testuser", false)
	if err != nil {
		t.Fatalf("Commit: %v", err)
	}
	if result.InsertedCount != 2 {
		t.Errorf("inserted = %d, want 2", result.InsertedCount)
	}

	// Spot-check that FK resolution worked + date normalized.
	row, _ := db.QueryRow(
		`SELECT employee_id, course_id, completion_date, passed FROM training_completions
		  WHERE employee_id = 2`,
	)
	if row["course_id"].(int64) != courseID {
		t.Errorf("course_id = %v, want %d", row["course_id"], courseID)
	}
	if row["completion_date"] != "2024-03-15" {
		t.Errorf("completion_date = %v, want 2024-03-15", row["completion_date"])
	}
	if row["passed"].(int64) != 1 {
		t.Errorf("passed = %v, want 1", row["passed"])
	}
}

func TestTrainingCompletionsMapperFlagsUnknownFKs(t *testing.T) {
	engine, _ := newTestEngine(t)
	estID := int64(1)

	csv := "Employee Number,Course Code,Completion Date\n" +
		"E999,UNKNOWN-COURSE,2024-03-15\n"
	preview, err := engine.Upload("training_completions", "testuser", "tc.csv", bytes.NewBufferString(csv), &estID)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	// Expect errors on both employee_number and course_code.
	var empErr, courseErr bool
	for _, v := range preview.ValidationErrors {
		if v.Column == "employee_number" {
			empErr = true
		}
		if v.Column == "course_code" {
			courseErr = true
		}
	}
	if !empErr {
		t.Errorf("expected validation error on employee_number; got %+v", preview.ValidationErrors)
	}
	if !courseErr {
		t.Errorf("expected validation error on course_code; got %+v", preview.ValidationErrors)
	}
}
