package server

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"testing/iotest"
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

// --- Reactivate endpoints ---

// postAction is a tiny helper: POST /api/path/{id}/action, expect 200.
func postAction(t *testing.T, tc *testContext, path string) {
	t.Helper()
	req := httptest.NewRequest("POST", path, nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("%s = %d; %s", path, w.Code, w.Body.String())
	}
}

// fetchRow GETs /api/path/{id} and decodes into a map.
func fetchRow(t *testing.T, tc *testContext, path string) map[string]any {
	t.Helper()
	req := httptest.NewRequest("GET", path, nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GET %s = %d; %s", path, w.Code, w.Body.String())
	}
	var row map[string]any
	json.NewDecoder(w.Body).Decode(&row)
	return row
}

func TestEstablishmentDeactivateReactivate(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Create one (don't touch seeded id=1 — has FK deps).
	createBody := `{
		"name": "Secondary Site",
		"street_address": "2 Lane",
		"city": "Topeka",
		"state": "KS",
		"zip": "66603"
	}`
	req := httptest.NewRequest("POST", "/api/establishments", bytes.NewBufferString(createBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	var created map[string]any
	json.NewDecoder(w.Body).Decode(&created)
	id := int(created["id"].(float64))

	postAction(t, tc, "/api/establishments/"+itoa(id)+"/deactivate")
	if row := fetchRow(t, tc, "/api/establishments/"+itoa(id)); row["is_active"].(float64) != 0 {
		t.Errorf("after deactivate is_active = %v, want 0", row["is_active"])
	}

	postAction(t, tc, "/api/establishments/"+itoa(id)+"/reactivate")
	if row := fetchRow(t, tc, "/api/establishments/"+itoa(id)); row["is_active"].(float64) != 1 {
		t.Errorf("after reactivate is_active = %v, want 1", row["is_active"])
	}
}

func TestEmployeeDeactivateReactivate(t *testing.T) {
	tc := newTestServerWithDB(t)

	empBody := `{"establishment_id": 1, "first_name": "Ada", "last_name": "Lovelace"}`
	req := httptest.NewRequest("POST", "/api/employees", bytes.NewBufferString(empBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	var created map[string]any
	json.NewDecoder(w.Body).Decode(&created)
	id := int(created["id"].(float64))

	postAction(t, tc, "/api/employees/"+itoa(id)+"/deactivate")
	row := fetchRow(t, tc, "/api/employees/"+itoa(id))
	if row["is_active"].(float64) != 0 {
		t.Errorf("after deactivate is_active = %v, want 0", row["is_active"])
	}
	if row["termination_date"] == nil {
		t.Errorf("expected termination_date to be set after deactivate")
	}

	postAction(t, tc, "/api/employees/"+itoa(id)+"/reactivate")
	row = fetchRow(t, tc, "/api/employees/"+itoa(id))
	if row["is_active"].(float64) != 1 {
		t.Errorf("after reactivate is_active = %v, want 1", row["is_active"])
	}
	if row["termination_date"] != nil {
		t.Errorf("expected termination_date cleared after reactivate, got %v", row["termination_date"])
	}
}

func TestWasteStreamDeactivateReactivate(t *testing.T) {
	tc := newTestServerWithDB(t)

	wsBody := `{
		"establishment_id": 1,
		"stream_code": "WS-001",
		"stream_name": "Spent acid",
		"waste_category": "hazardous"
	}`
	req := httptest.NewRequest("POST", "/api/waste-streams", bytes.NewBufferString(wsBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create waste stream = %d; %s", w.Code, w.Body.String())
	}
	var created map[string]any
	json.NewDecoder(w.Body).Decode(&created)
	id := int(created["id"].(float64))

	postAction(t, tc, "/api/waste-streams/"+itoa(id)+"/deactivate")
	if row := fetchRow(t, tc, "/api/waste-streams/"+itoa(id)); row["is_active"].(float64) != 0 {
		t.Errorf("after deactivate is_active = %v, want 0", row["is_active"])
	}

	postAction(t, tc, "/api/waste-streams/"+itoa(id)+"/reactivate")
	if row := fetchRow(t, tc, "/api/waste-streams/"+itoa(id)); row["is_active"].(float64) != 1 {
		t.Errorf("after reactivate is_active = %v, want 1", row["is_active"])
	}
}

func TestChemicalDiscontinueReactivate(t *testing.T) {
	tc := newTestServerWithDB(t)

	chemBody := `{
		"establishment_id": 1,
		"product_name": "Acetone"
	}`
	req := httptest.NewRequest("POST", "/api/chemicals", bytes.NewBufferString(chemBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create chemical = %d; %s", w.Code, w.Body.String())
	}
	var created map[string]any
	json.NewDecoder(w.Body).Decode(&created)
	id := int(created["id"].(float64))

	// Discontinue with a reason.
	req = httptest.NewRequest("POST", "/api/chemicals/"+itoa(id)+"/discontinue",
		bytes.NewBufferString(`{"reason":"Replaced"}`))
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("discontinue = %d; %s", w.Code, w.Body.String())
	}

	row := fetchRow(t, tc, "/api/chemicals/"+itoa(id))
	if row["is_active"].(float64) != 0 {
		t.Errorf("after discontinue is_active = %v, want 0", row["is_active"])
	}
	if row["discontinued_reason"] != "Replaced" {
		t.Errorf("discontinued_reason = %v", row["discontinued_reason"])
	}

	postAction(t, tc, "/api/chemicals/"+itoa(id)+"/reactivate")
	row = fetchRow(t, tc, "/api/chemicals/"+itoa(id))
	if row["is_active"].(float64) != 1 {
		t.Errorf("after reactivate is_active = %v, want 1", row["is_active"])
	}
	if row["discontinued_reason"] != nil {
		t.Errorf("expected discontinued_reason cleared, got %v", row["discontinued_reason"])
	}
	if row["discontinued_date"] != nil {
		t.Errorf("expected discontinued_date cleared, got %v", row["discontinued_date"])
	}
}

func TestUserDeactivateReactivate(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Create a second user.
	userBody := `{"username":"alice","display_name":"Alice","password":"alicepass","role":"user"}`
	req := httptest.NewRequest("POST", "/api/users", bytes.NewBufferString(userBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create user = %d; %s", w.Code, w.Body.String())
	}
	var created map[string]any
	json.NewDecoder(w.Body).Decode(&created)
	id := int(created["id"].(float64))

	postAction(t, tc, "/api/users/"+itoa(id)+"/deactivate")
	if row := fetchRow(t, tc, "/api/users/"+itoa(id)); row["is_active"].(bool) != false {
		t.Errorf("after deactivate is_active = %v, want false", row["is_active"])
	}

	postAction(t, tc, "/api/users/"+itoa(id)+"/reactivate")
	if row := fetchRow(t, tc, "/api/users/"+itoa(id)); row["is_active"].(bool) != true {
		t.Errorf("after reactivate is_active = %v, want true", row["is_active"])
	}
}

// --- Clean Water (Module D) ---

// createResource POSTs JSON body to path, asserts 201, and returns the new id.
func createResource(t *testing.T, tc *testContext, path, body string) int64 {
	t.Helper()
	req := httptest.NewRequest("POST", path, bytes.NewBufferString(body))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("POST %s = %d; %s", path, w.Code, w.Body.String())
	}
	var result map[string]any
	json.NewDecoder(w.Body).Decode(&result)
	return int64(result["id"].(float64))
}

// createNPDESPermit seeds an NPDES permit (permit_type_id = 10) on
// establishment 1 and returns its id.
func createNPDESPermit(t *testing.T, tc *testContext, permitNumber string) int64 {
	t.Helper()
	body := `{
		"establishment_id": 1,
		"permit_type_id": 10,
		"permit_number": "` + permitNumber + `",
		"permit_name": "NPDES Permit — test",
		"effective_date": "2026-01-01",
		"expiration_date": "2031-01-01"
	}`
	return createResource(t, tc, "/api/permits", body)
}

func TestCleanWaterDischargePointLifecycle(t *testing.T) {
	tc := newTestServerWithDB(t)

	permitID := createNPDESPermit(t, tc, "TX0012345")

	// Create a discharge point attached to the permit.
	createBody := `{
		"establishment_id": 1,
		"outfall_code": "OUTFALL-001",
		"outfall_name": "Main process wastewater outfall",
		"discharge_type": "process_wastewater",
		"receiving_waterbody": "Cedar Creek",
		"receiving_waterbody_type": "surface_water",
		"permit_id": ` + itoa(int(permitID)) + `,
		"latitude": 32.2831,
		"longitude": -96.0908
	}`
	id := createResource(t, tc, "/api/discharge-points", createBody)

	// Update.
	updateBody := `{
		"establishment_id": 1,
		"outfall_code": "OUTFALL-001-R",
		"outfall_name": "Main process outfall (renamed)",
		"discharge_type": "process_wastewater",
		"receiving_waterbody": "Cedar Creek",
		"receiving_waterbody_type": "surface_water",
		"permit_id": ` + itoa(int(permitID)) + `
	}`
	req := httptest.NewRequest("PUT", "/api/discharge-points/"+itoa(int(id)), bytes.NewBufferString(updateBody))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("PUT = %d; %s", w.Code, w.Body.String())
	}
	if row := fetchRow(t, tc, "/api/discharge-points/"+itoa(int(id))); row["outfall_code"] != "OUTFALL-001-R" {
		t.Errorf("after update outfall_code = %v, want OUTFALL-001-R", row["outfall_code"])
	}

	// Decommission → status flips + decommission_date stamped.
	postAction(t, tc, "/api/discharge-points/"+itoa(int(id))+"/decommission")
	row := fetchRow(t, tc, "/api/discharge-points/"+itoa(int(id)))
	if row["status"] != "decommissioned" {
		t.Errorf("after decommission status = %v, want decommissioned", row["status"])
	}
	if row["decommission_date"] == nil {
		t.Errorf("after decommission expected decommission_date to be set")
	}

	// Reactivate → status flips back + decommission_date cleared.
	postAction(t, tc, "/api/discharge-points/"+itoa(int(id))+"/reactivate")
	row = fetchRow(t, tc, "/api/discharge-points/"+itoa(int(id)))
	if row["status"] != "active" {
		t.Errorf("after reactivate status = %v, want active", row["status"])
	}
	if row["decommission_date"] != nil {
		t.Errorf("after reactivate decommission_date = %v, want nil", row["decommission_date"])
	}

	// Delete.
	req = httptest.NewRequest("DELETE", "/api/discharge-points/"+itoa(int(id)), nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("DELETE = %d; %s", w.Code, w.Body.String())
	}

	// Confirm gone.
	req = httptest.NewRequest("GET", "/api/discharge-points/"+itoa(int(id)), nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusNotFound {
		t.Errorf("after delete GET = %d, want 404", w.Code)
	}
}

func TestCleanWaterSampleEventChain(t *testing.T) {
	tc := newTestServerWithDB(t)

	permitID := createNPDESPermit(t, tc, "TX0099999")

	// Seed a monitoring location directly — there is no write endpoint for
	// ww_monitoring_locations in the MVP (configuration table, admin-seeded
	// via schema builder).
	if err := tc.srv.db.ExecParams(
		`INSERT INTO ww_monitoring_locations (establishment_id, location_code, location_name, location_type, permit_id)
		 VALUES (?, ?, ?, ?, ?)`,
		1, "MON-OUT-001", "Outfall 001 monitoring point", "outfall", permitID,
	); err != nil {
		t.Fatalf("seed ww_monitoring_locations: %v", err)
	}
	locationID := int64(1)

	// Create a sample event.
	eventBody := `{
		"establishment_id": 1,
		"location_id": ` + itoa(int(locationID)) + `,
		"event_number": "SE-2026-001",
		"sample_date": "2026-04-15",
		"sample_time": "09:30",
		"sample_type": "grab",
		"weather_conditions": "dry"
	}`
	eventID := createResource(t, tc, "/api/ww-sample-events", eventBody)

	// Add two results (using seed parameter ids: 1 = Cadmium Total, 20 = BOD5).
	result1Body := `{
		"event_id": ` + itoa(int(eventID)) + `,
		"parameter_id": 1,
		"result_value": 0.004,
		"result_units": "mg/L",
		"detection_limit": 0.001,
		"reporting_limit": 0.002,
		"analyzed_by": "Acme Labs",
		"analysis_method": "EPA 200.7"
	}`
	r1 := createResource(t, tc, "/api/ww-sample-results", result1Body)

	result2Body := `{
		"event_id": ` + itoa(int(eventID)) + `,
		"parameter_id": 20,
		"result_value": 25.4,
		"result_units": "mg/L",
		"analyzed_by": "Acme Labs",
		"analysis_method": "EPA 405.1"
	}`
	createResource(t, tc, "/api/ww-sample-results", result2Body)

	// Finalize the event. Empty body should work (no employee mapping).
	req := httptest.NewRequest("POST", "/api/ww-sample-events/"+itoa(int(eventID))+"/finalize", nil)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("finalize = %d; %s", w.Code, w.Body.String())
	}
	row := fetchRow(t, tc, "/api/ww-sample-events/"+itoa(int(eventID)))
	if row["status"] != "finalized" {
		t.Errorf("after finalize status = %v, want finalized", row["status"])
	}
	if row["finalized_date"] == nil {
		t.Errorf("after finalize expected finalized_date to be set")
	}

	// Delete one result (the cadmium one).
	req = httptest.NewRequest("DELETE", "/api/ww-sample-results/"+itoa(int(r1)), nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("delete result = %d; %s", w.Code, w.Body.String())
	}

	// Confirm gone.
	req = httptest.NewRequest("GET", "/api/ww-sample-results/"+itoa(int(r1)), nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusNotFound {
		t.Errorf("after result delete GET = %d, want 404", w.Code)
	}

	// Delete the event — cascades the remaining result via ON DELETE CASCADE.
	req = httptest.NewRequest("DELETE", "/api/ww-sample-events/"+itoa(int(eventID)), nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("delete event = %d; %s", w.Code, w.Body.String())
	}
}

func TestCleanWaterSWPPPAndBMPs(t *testing.T) {
	tc := newTestServerWithDB(t)

	// SWPPP — MSGP typically, but permit is optional for this test.
	swpppBody := `{
		"establishment_id": 1,
		"revision_number": "v1.0",
		"effective_date": "2026-01-01",
		"next_annual_review_due": "2027-01-01",
		"document_path": "/docs/swppp/v1.0.pdf",
		"site_description_summary": "Fabricated metal products facility, Sector AA."
	}`
	swpppID := createResource(t, tc, "/api/swpps", swpppBody)

	// Two BMPs.
	bmp1Body := `{
		"swppp_id": ` + itoa(int(swpppID)) + `,
		"establishment_id": 1,
		"bmp_code": "BMP-COVER-001",
		"bmp_name": "Cover outside material storage",
		"bmp_type": "structural",
		"bmp_subtype": "physical_coverage",
		"description": "Tarp or roof over scrap metal storage piles.",
		"inspection_frequency": "monthly",
		"inspection_frequency_days": 30,
		"responsible_role": "Facility Operator"
	}`
	bmp1ID := createResource(t, tc, "/api/bmps", bmp1Body)

	bmp2Body := `{
		"swppp_id": ` + itoa(int(swpppID)) + `,
		"establishment_id": 1,
		"bmp_code": "BMP-HSKP-001",
		"bmp_name": "Good housekeeping — loading dock",
		"bmp_type": "non_structural",
		"bmp_subtype": "good_housekeeping",
		"description": "Sweep and pick up debris daily from the loading dock area.",
		"inspection_frequency": "weekly",
		"inspection_frequency_days": 7,
		"responsible_role": "EHS Manager"
	}`
	bmp2ID := createResource(t, tc, "/api/bmps", bmp2Body)

	// Update BMP 1 — change inspection cadence.
	bmp1Update := `{
		"swppp_id": ` + itoa(int(swpppID)) + `,
		"establishment_id": 1,
		"bmp_code": "BMP-COVER-001",
		"bmp_name": "Cover outside material storage (updated)",
		"bmp_type": "structural",
		"description": "Tarp or roof over scrap metal storage piles. Inspect after every rain event.",
		"inspection_frequency": "storm_event",
		"inspection_frequency_days": 1,
		"responsible_role": "Facility Operator"
	}`
	req := httptest.NewRequest("PUT", "/api/bmps/"+itoa(int(bmp1ID)), bytes.NewBufferString(bmp1Update))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("PUT bmp = %d; %s", w.Code, w.Body.String())
	}
	if row := fetchRow(t, tc, "/api/bmps/"+itoa(int(bmp1ID))); row["inspection_frequency"] != "storm_event" {
		t.Errorf("after BMP update inspection_frequency = %v, want storm_event", row["inspection_frequency"])
	}

	// Delete BMP 2.
	req = httptest.NewRequest("DELETE", "/api/bmps/"+itoa(int(bmp2ID)), nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("DELETE bmp = %d; %s", w.Code, w.Body.String())
	}

	// SWPPP list should show the one we created.
	req = httptest.NewRequest("GET", "/api/swpps", nil)
	tc.authRequest(req)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GET /api/swpps = %d; %s", w.Code, w.Body.String())
	}
	var list struct {
		Total int64 `json:"total"`
	}
	json.NewDecoder(w.Body).Decode(&list)
	if list.Total < 1 {
		t.Errorf("expected >=1 SWPPP, got %d", list.Total)
	}
}

// TestCreateEstablishmentWithITAFields — Phase 4a.3 round-trip on the
// 4 new OSHA ITA reporting columns (ein, company_name, size_code,
// establishment_type_code).
func TestCreateEstablishmentWithITAFields(t *testing.T) {
	tc := newTestServerWithDB(t)

	body := `{
		"name": "Acme ITA Test Plant",
		"street_address": "900 Compliance Blvd",
		"city": "Detroit",
		"state": "MI",
		"zip": "48201",
		"naics_code": "325199",
		"ein": "12-3456789",
		"company_name": "Acme Chemical Holdings Inc.",
		"size_code": "LARGE",
		"establishment_type_code": "PRIVATE"
	}`

	req := httptest.NewRequest("POST", "/api/establishments", bytes.NewBufferString(body))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("POST /api/establishments = %d; body: %s", w.Code, w.Body.String())
	}

	var created map[string]any
	json.NewDecoder(w.Body).Decode(&created)
	id := int(created["id"].(float64))

	// Round-trip: read it back and verify each ITA field landed.
	req = httptest.NewRequest("GET", "/api/establishments/"+itoa(id), nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GET = %d; %s", w.Code, w.Body.String())
	}

	var row map[string]any
	json.NewDecoder(w.Body).Decode(&row)

	checks := map[string]string{
		"ein":                     "12-3456789",
		"company_name":            "Acme Chemical Holdings Inc.",
		"size_code":               "LARGE",
		"establishment_type_code": "PRIVATE",
	}
	for field, want := range checks {
		if row[field] != want {
			t.Errorf("%s = %v, want %q", field, row[field], want)
		}
	}
}

// TestCreateIncidentWithITAFields — Phase 4a.3 round-trip on the 6
// new OSHA ITA per-incident columns (treatment_facility_type_code,
// days_away_from_work, days_restricted_or_transferred, date_of_death,
// time_unknown, injury_illness_description).
func TestCreateIncidentWithITAFields(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Seed an employee.
	empBody := `{
		"establishment_id": 1,
		"first_name": "Alex",
		"last_name": "Ramirez",
		"job_title": "Process Operator"
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

	// Incident with all new ITA fields populated.
	incBody := `{
		"establishment_id": 1,
		"employee_id": ` + itoa(empID) + `,
		"incident_date": "2026-03-15",
		"incident_description": "Fall from scaffold; fracture to left wrist.",
		"severity_code": "LOST_TIME",
		"case_classification_code": "INJURY",
		"treatment_facility_type_code": "HOSPITAL_ER",
		"days_away_from_work": 12,
		"days_restricted_or_transferred": 0,
		"time_unknown": 0,
		"injury_illness_description": "Closed fracture of the left radius; splint applied; referred to orthopedic follow-up.",
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

	// Round-trip.
	req = httptest.NewRequest("GET", "/api/incidents/"+itoa(incID), nil)
	w = httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GET = %d; %s", w.Code, w.Body.String())
	}
	var row map[string]any
	json.NewDecoder(w.Body).Decode(&row)

	if row["treatment_facility_type_code"] != "HOSPITAL_ER" {
		t.Errorf("treatment_facility_type_code = %v, want HOSPITAL_ER", row["treatment_facility_type_code"])
	}
	if row["days_away_from_work"].(float64) != 12 {
		t.Errorf("days_away_from_work = %v, want 12", row["days_away_from_work"])
	}
	if row["days_restricted_or_transferred"].(float64) != 0 {
		t.Errorf("days_restricted_or_transferred = %v, want 0", row["days_restricted_or_transferred"])
	}
	if row["time_unknown"].(float64) != 0 {
		t.Errorf("time_unknown = %v, want 0", row["time_unknown"])
	}
	wantDesc := "Closed fracture of the left radius; splint applied; referred to orthopedic follow-up."
	if row["injury_illness_description"] != wantDesc {
		t.Errorf("injury_illness_description = %v, want %q", row["injury_illness_description"], wantDesc)
	}
	// date_of_death is nullable — not sent, not populated. Confirm null.
	if row["date_of_death"] != nil {
		t.Errorf("date_of_death = %v, want nil", row["date_of_death"])
	}
}

// TestLookupRoute — Phase 4a.3.3 smoke test for GET /api/lookup/{table}.
// Verifies whitelist behavior (known = OK, unknown = 404) and the
// normalized (code, name, description) row shape.
func TestLookupRoute(t *testing.T) {
	tc := newTestServerWithDB(t)

	tests := []struct {
		table    string
		wantRows int
	}{
		{"ita_establishment_sizes", 3},
		{"ita_establishment_types", 3},
		{"ita_treatment_facility_types", 7},
		{"case_classifications", 6},
		{"incident_severity_levels", 8},
	}

	for _, tt := range tests {
		req := httptest.NewRequest("GET", "/api/lookup/"+tt.table, nil)
		w := httptest.NewRecorder()
		tc.srv.mux.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Errorf("GET /api/lookup/%s = %d; body: %s", tt.table, w.Code, w.Body.String())
			continue
		}

		var resp struct {
			Total int64 `json:"total"`
			Items []map[string]any `json:"items"`
		}
		json.NewDecoder(w.Body).Decode(&resp)

		if int(resp.Total) != tt.wantRows {
			t.Errorf("%s: total = %d, want %d", tt.table, resp.Total, tt.wantRows)
		}
		if len(resp.Items) != tt.wantRows {
			t.Errorf("%s: len(items) = %d, want %d", tt.table, len(resp.Items), tt.wantRows)
		}
		// Confirm each row has the normalized (code, name, description) shape.
		for i, item := range resp.Items {
			if _, ok := item["code"]; !ok {
				t.Errorf("%s[%d]: missing 'code' field", tt.table, i)
			}
			if _, ok := item["name"]; !ok {
				t.Errorf("%s[%d]: missing 'name' field", tt.table, i)
			}
			if _, ok := item["description"]; !ok {
				t.Errorf("%s[%d]: missing 'description' field", tt.table, i)
			}
		}
	}

	// Unknown table → 404.
	req := httptest.NewRequest("GET", "/api/lookup/no_such_table", nil)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)
	if w.Code != http.StatusNotFound {
		t.Errorf("GET /api/lookup/no_such_table = %d, want 404", w.Code)
	}
}

// TestReadBody_OversizedReturns413 verifies that bodies exceeding
// MaxRequestBody are rejected with 413 Payload Too Large rather than
// being silently truncated.
func TestReadBody_OversizedReturns413(t *testing.T) {
	tc := newTestServerWithDB(t)

	// Build a JSON payload whose `name` field alone is bigger than the cap.
	huge := strings.Repeat("A", MaxRequestBody+1024)
	body := `{"name":"` + huge + `","street_address":"x","city":"x","state":"TX","zip":"77001","naics_code":"325199"}`

	req := httptest.NewRequest("POST", "/api/establishments", strings.NewReader(body))
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("oversized POST = %d, want 413; body: %s", w.Code, w.Body.String())
	}
}

// TestReadBody_MultiReadBodySucceeds guards against the regression
// where readBody used a single r.Body.Read() call and silently truncated
// any body that arrived in multiple chunks. Wrapping the body in
// iotest.OneByteReader forces every Read() to return exactly one byte,
// so the old implementation would have lost everything past byte 1.
func TestReadBody_MultiReadBodySucceeds(t *testing.T) {
	tc := newTestServerWithDB(t)

	body := `{"name":"Chunked Plant","street_address":"1 Slow Lane","city":"Reno","state":"NV","zip":"89501","naics_code":"325199"}`

	req := httptest.NewRequest(
		"POST", "/api/establishments",
		io.NopCloser(iotest.OneByteReader(strings.NewReader(body))),
	)
	tc.authRequest(req)
	w := httptest.NewRecorder()
	tc.srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("chunked POST = %d, want 201; body: %s", w.Code, w.Body.String())
	}
}
