package server

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
)

func TestCreateEstablishment(t *testing.T) {
	tc := newTestServerWithDB(t)

	body := `{
		"name": "Acme Chemical Plant",
		"street_address": "500 Industrial Dr",
		"city": "Houston",
		"state": "TX",
		"zip": "77001",
		"naics_code": "325199"
	}`

	req := httptest.NewRequest("POST", "/api/establishments", bytes.NewBufferString(body))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("POST /api/establishments = %d; body: %s", w.Code, w.Body.String())
	}

	var result map[string]any
	json.NewDecoder(w.Body).Decode(&result)
	id := result["id"].(float64)
	if id < 1 {
		t.Fatalf("expected id > 0, got %v", id)
	}

	// Verify it shows up in the list.
	req = httptest.NewRequest("GET", "/api/establishments", nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	var list struct {
		Total int64 `json:"total"`
	}
	json.NewDecoder(w.Body).Decode(&list)
	// Seeded establishment + the one we just created.
	if list.Total != 2 {
		t.Errorf("expected 2 establishments, got %d", list.Total)
	}
}

func TestUpdateEstablishment(t *testing.T) {
	tc := newTestServerWithDB(t)

	body := `{
		"name": "Test Facility UPDATED",
		"street_address": "123 Industrial Pkwy",
		"city": "Springfield",
		"state": "IL",
		"zip": "62701"
	}`

	req := httptest.NewRequest("PUT", "/api/establishments/1", bytes.NewBufferString(body))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("PUT = %d; body: %s", w.Code, w.Body.String())
	}

	// Verify the update.
	req = httptest.NewRequest("GET", "/api/establishments/1", nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	var row map[string]any
	json.NewDecoder(w.Body).Decode(&row)
	if row["name"] != "Test Facility UPDATED" {
		t.Errorf("name = %v, want Test Facility UPDATED", row["name"])
	}
}

func TestDeleteEstablishment(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Create one to delete (don't delete the seeded one, it has FK deps).
	createBody := `{
		"name": "Temporary Site",
		"street_address": "1 Temp Rd",
		"city": "Nowhere",
		"state": "KS",
		"zip": "66002"
	}`
	req := httptest.NewRequest("POST", "/api/establishments", bytes.NewBufferString(createBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	var created map[string]any
	json.NewDecoder(w.Body).Decode(&created)
	id := int(created["id"].(float64))

	// Delete it.
	req = httptest.NewRequest("DELETE", "/api/establishments/"+itoa(id), nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("DELETE = %d; body: %s", w.Code, w.Body.String())
	}

	// Verify it's gone.
	req = httptest.NewRequest("GET", "/api/establishments/"+itoa(id), nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("GET after DELETE = %d, want 404", w.Code)
	}
}

func TestCreateAndCloseIncident(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Seed an employee first.
	empBody := `{
		"establishment_id": 1,
		"first_name": "Jane",
		"last_name": "Doe",
		"job_title": "Operator"
	}`
	req := httptest.NewRequest("POST", "/api/employees", bytes.NewBufferString(empBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create employee = %d; %s", w.Code, w.Body.String())
	}
	var emp map[string]any
	json.NewDecoder(w.Body).Decode(&emp)
	empID := int(emp["id"].(float64))

	// Create an incident.
	incBody := `{
		"establishment_id": 1,
		"employee_id": ` + itoa(empID) + `,
		"incident_date": "2026-04-10",
		"incident_description": "Chemical splash to face near tank 3",
		"severity_code": "FIRST_AID",
		"location_description": "Tank farm area B",
		"reported_by": "testuser"
	}`
	req = httptest.NewRequest("POST", "/api/incidents", bytes.NewBufferString(incBody))
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create incident = %d; %s", w.Code, w.Body.String())
	}
	var inc map[string]any
	json.NewDecoder(w.Body).Decode(&inc)
	incID := int(inc["id"].(float64))

	// Verify it was created with status 'reported'.
	req = httptest.NewRequest("GET", "/api/incidents/"+itoa(incID), nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	var incRow map[string]any
	json.NewDecoder(w.Body).Decode(&incRow)
	if incRow["status"] != "reported" {
		t.Errorf("initial status = %v, want reported", incRow["status"])
	}

	// Close it.
	req = httptest.NewRequest("POST", "/api/incidents/"+itoa(incID)+"/close", nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("close incident = %d; %s", w.Code, w.Body.String())
	}

	// Verify status changed.
	req = httptest.NewRequest("GET", "/api/incidents/"+itoa(incID), nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	json.NewDecoder(w.Body).Decode(&incRow)
	if incRow["status"] != "closed" {
		t.Errorf("closed status = %v, want closed", incRow["status"])
	}
	if incRow["closed_by"] != "testuser" {
		t.Errorf("closed_by = %v, want testuser", incRow["closed_by"])
	}
}

func TestCorrectiveActionLifecycle(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Need an investigation to FK against. Seed the chain:
	// employee -> incident -> investigation -> corrective action

	tc.srv.repo.DB.ExecParams(
		`INSERT INTO employees (id, establishment_id, first_name, last_name) VALUES (?, ?, ?, ?)`,
		1, 1, "Test", "Worker",
	)
	tc.srv.repo.DB.ExecParams(
		`INSERT INTO incidents (id, establishment_id, employee_id, incident_date, incident_description, severity_code)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		1, 1, 1, "2026-04-10", "Test incident", "FIRST_AID",
	)
	tc.srv.repo.DB.ExecParams(
		`INSERT INTO incident_investigations (id, incident_id, lead_investigator, initiated_date, status)
		 VALUES (?, ?, ?, ?, ?)`,
		1, 1, "Test Worker", "2026-04-10", "in_progress",
	)

	// Create corrective action.
	caBody := `{
		"investigation_id": 1,
		"description": "Install splash guard on tank 3 transfer valve",
		"hierarchy_level": "engineering",
		"assigned_to": "testuser",
		"due_date": "2026-05-01"
	}`
	req := httptest.NewRequest("POST", "/api/corrective-actions", bytes.NewBufferString(caBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create CA = %d; %s", w.Code, w.Body.String())
	}
	var ca map[string]any
	json.NewDecoder(w.Body).Decode(&ca)
	caID := int(ca["id"].(float64))

	// Complete it.
	req = httptest.NewRequest("POST", "/api/corrective-actions/"+itoa(caID)+"/complete", nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("complete CA = %d; %s", w.Code, w.Body.String())
	}

	// Verify it.
	verifyBody := `{"notes": "Splash guard installed and tested with water flow. No splashing observed."}`
	req = httptest.NewRequest("POST", "/api/corrective-actions/"+itoa(caID)+"/verify", bytes.NewBufferString(verifyBody))
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("verify CA = %d; %s", w.Code, w.Body.String())
	}

	// Check final state.
	req = httptest.NewRequest("GET", "/api/corrective-actions/"+itoa(caID), nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	var caRow map[string]any
	json.NewDecoder(w.Body).Decode(&caRow)
	if caRow["status"] != "verified" {
		t.Errorf("status = %v, want verified", caRow["status"])
	}
	if caRow["verified_by"] != "testuser" {
		t.Errorf("verified_by = %v, want testuser", caRow["verified_by"])
	}
}

func TestCreateChemical(t *testing.T) {
	tc := newTestServerWithDB(t)

	body := `{
		"establishment_id": 1,
		"product_name": "Sulfuric Acid 93%",
		"manufacturer": "ChemCorp",
		"primary_cas_number": "7664-93-9",
		"signal_word": "Danger",
		"is_corrosive_to_metal": 1,
		"is_skin_corrosion": 1,
		"is_eye_damage": 1,
		"is_acute_toxic": 1,
		"is_ehs": 1,
		"ehs_tpq_lbs": 1000,
		"ehs_rq_lbs": 1000,
		"physical_state": "liquid",
		"storage_requirements": "Separate from organics and metals. Secondary containment required.",
		"ppe_required": "Face shield, chemical goggles, acid-resistant gloves, rubber apron"
	}`

	req := httptest.NewRequest("POST", "/api/chemicals", bytes.NewBufferString(body))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("POST /api/chemicals = %d; body: %s", w.Code, w.Body.String())
	}

	var result map[string]any
	json.NewDecoder(w.Body).Decode(&result)
	id := int(result["id"].(float64))

	// Verify it shows up.
	req = httptest.NewRequest("GET", "/api/chemicals/"+itoa(id), nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	var chem map[string]any
	json.NewDecoder(w.Body).Decode(&chem)
	if chem["product_name"] != "Sulfuric Acid 93%" {
		t.Errorf("product_name = %v", chem["product_name"])
	}
	if chem["primary_cas_number"] != "7664-93-9" {
		t.Errorf("cas = %v", chem["primary_cas_number"])
	}

	// Discontinue it.
	discBody := `{"reason": "Switched to less hazardous alternative"}`
	req = httptest.NewRequest("POST", "/api/chemicals/"+itoa(id)+"/discontinue", bytes.NewBufferString(discBody))
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("discontinue = %d; %s", w.Code, w.Body.String())
	}

	// Verify discontinued.
	req = httptest.NewRequest("GET", "/api/chemicals/"+itoa(id), nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	json.NewDecoder(w.Body).Decode(&chem)
	if chem["is_active"].(float64) != 0 {
		t.Errorf("is_active = %v, want 0", chem["is_active"])
	}
	if chem["discontinued_reason"] != "Switched to less hazardous alternative" {
		t.Errorf("discontinued_reason = %v", chem["discontinued_reason"])
	}
}

func itoa(i int) string {
	return strconv.Itoa(i)
}
