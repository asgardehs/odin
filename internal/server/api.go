package server

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/asgardehs/odin/internal/database"
)

// JSON helpers

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

// entityRoutes registers standard list + get-by-ID routes for a table.
// List supports pagination (?page=N&per_page=N) and, when searchCols is
// non-empty, a simple ?q= full-text filter that LIKEs against each
// listed column (joined with OR).
func (s *Server) entityRoutes(pattern, label, listSQL, countSQL, getSQL string, searchCols ...string) {
	s.mux.HandleFunc("GET "+pattern, func(w http.ResponseWriter, r *http.Request) {
		p := database.PageFromRequest(r)

		activeListSQL := listSQL
		activeCountSQL := countSQL
		var args []any

		if q := strings.TrimSpace(r.URL.Query().Get("q")); q != "" && len(searchCols) > 0 {
			where, qArgs := buildSearchWhere(searchCols, q)
			activeListSQL = injectWhere(listSQL, where)
			activeCountSQL = countSQL + " " + where
			args = qArgs
		}

		result, err := s.db.QueryPaged(p, activeCountSQL, activeListSQL, args...)
		if err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, result)
	})

	s.mux.HandleFunc("GET "+pattern+"/{id}", func(w http.ResponseWriter, r *http.Request) {
		id := r.PathValue("id")
		row, err := s.db.QueryRow(getSQL, id)
		if err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}
		if row == nil {
			writeError(w, label+" not found", http.StatusNotFound)
			return
		}
		writeJSON(w, row)
	})
}

// buildSearchWhere returns a SQL WHERE clause that LIKEs each column
// against the query, joined with OR, plus the bind arguments.
func buildSearchWhere(cols []string, q string) (string, []any) {
	pattern := "%" + q + "%"
	parts := make([]string, 0, len(cols))
	args := make([]any, 0, len(cols))
	for _, c := range cols {
		parts = append(parts, c+" LIKE ?")
		args = append(args, pattern)
	}
	return "WHERE (" + strings.Join(parts, " OR ") + ")", args
}

// injectWhere inserts a WHERE clause immediately before " ORDER BY "
// in a list SQL statement. Falls back to appending if ORDER BY is absent.
func injectWhere(sql, where string) string {
	idx := strings.Index(sql, " ORDER BY ")
	if idx == -1 {
		return sql + " " + where
	}
	return sql[:idx] + " " + where + sql[idx:]
}

// apiRoutes registers all data API routes.
func (s *Server) apiRoutes() {
	if s.db == nil {
		return
	}

	// -- Core Foundation (Module C) --

	s.entityRoutes("/api/establishments", "establishment",
		`SELECT id, name, street_address, city, state, zip, naics_code, sic_code,
		        peak_employees, annual_avg_employees, is_active, created_at
		 FROM establishments ORDER BY name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM establishments`,
		`SELECT * FROM establishments WHERE id = ?`,
		"name", "city", "naics_code",
	)

	s.entityRoutes("/api/employees", "employee",
		`SELECT id, establishment_id, employee_number, first_name, last_name,
		        job_title, department, date_hired, is_active, created_at
		 FROM employees ORDER BY last_name, first_name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM employees`,
		`SELECT * FROM employees WHERE id = ?`,
		"first_name", "last_name", "employee_number",
	)

	s.entityRoutes("/api/incidents", "incident",
		`SELECT id, establishment_id, case_number, employee_id, incident_date,
		        incident_time, location_description, incident_description,
		        case_classification_code, severity_code, status, created_at
		 FROM incidents ORDER BY incident_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM incidents`,
		`SELECT * FROM incidents WHERE id = ?`,
		"case_number", "incident_description", "location_description",
	)

	s.entityRoutes("/api/corrective-actions", "corrective action",
		`SELECT id, investigation_id, description, hierarchy_level,
		        assigned_to, due_date, status, completed_date, verified_date,
		        created_at
		 FROM corrective_actions ORDER BY created_at DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM corrective_actions`,
		`SELECT * FROM corrective_actions WHERE id = ?`,
	)

	// -- Module A: EPCRA / TRI --

	s.entityRoutes("/api/chemicals", "chemical",
		`SELECT id, establishment_id, primary_cas_number, product_name,
		        manufacturer, is_ehs, is_sara_313, is_pbt,
		        physical_state, is_active, created_at
		 FROM chemicals ORDER BY product_name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM chemicals`,
		`SELECT * FROM chemicals WHERE id = ?`,
		"product_name", "primary_cas_number", "manufacturer",
	)

	s.entityRoutes("/api/chemical-inventory", "chemical inventory",
		`SELECT id, chemical_id, storage_location_id, container_type,
		        quantity, unit, snapshot_date, snapshot_type
		 FROM chemical_inventory ORDER BY snapshot_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM chemical_inventory`,
		`SELECT * FROM chemical_inventory WHERE id = ?`,
	)

	// -- Module B: Title V / CAA --

	s.entityRoutes("/api/emission-units", "emission unit",
		`SELECT id, establishment_id, unit_name, unit_description,
		        source_category, scc_code, is_fugitive, is_active
		 FROM air_emission_units ORDER BY unit_name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM air_emission_units`,
		`SELECT * FROM air_emission_units WHERE id = ?`,
		"unit_name", "scc_code",
	)

	// -- Training --

	s.entityRoutes("/api/training/courses", "training course",
		`SELECT id, establishment_id, course_code, course_name, description,
		        duration_minutes, delivery_method, has_test, passing_score,
		        validity_months, is_active
		 FROM training_courses ORDER BY course_code LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM training_courses`,
		`SELECT * FROM training_courses WHERE id = ?`,
		"course_code", "course_name",
	)

	s.entityRoutes("/api/training/completions", "training completion",
		`SELECT id, employee_id, course_id, completion_date, expiration_date,
		        score, passed, instructor, delivery_method, created_at
		 FROM training_completions ORDER BY completion_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM training_completions`,
		`SELECT * FROM training_completions WHERE id = ?`,
	)

	s.entityRoutes("/api/training/assignments", "training assignment",
		`SELECT id, employee_id, course_id, due_date, priority, status,
		        assigned_by, assigned_date, created_at
		 FROM training_assignments ORDER BY due_date LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM training_assignments`,
		`SELECT * FROM training_assignments WHERE id = ?`,
	)

	// -- Inspections & Audits --

	s.entityRoutes("/api/inspections", "inspection",
		`SELECT id, establishment_id, inspection_type_id, inspection_number,
		        scheduled_date, inspection_date, inspector_id,
		        status, overall_result, created_at
		 FROM inspections ORDER BY inspection_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM inspections`,
		`SELECT * FROM inspections WHERE id = ?`,
		"inspection_number",
	)

	s.entityRoutes("/api/inspection-types", "inspection type",
		`SELECT id, type_code, type_name, default_frequency, is_active
		 FROM inspection_types ORDER BY type_code LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM inspection_types`,
		`SELECT * FROM inspection_types WHERE id = ?`,
		"type_code", "type_name",
	)

	s.entityRoutes("/api/audits", "audit",
		`SELECT id, establishment_id, audit_number, audit_title, audit_type,
		        standard_id, scheduled_start_date, actual_start_date,
		        lead_auditor_id, status, created_at
		 FROM audits ORDER BY scheduled_start_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM audits`,
		`SELECT * FROM audits WHERE id = ?`,
		"audit_number", "audit_title",
	)

	// -- Permits & Licenses --

	s.entityRoutes("/api/permits", "permit",
		`SELECT id, establishment_id, permit_type_id, permit_number,
		        permit_name, issuing_agency_id,
		        effective_date, expiration_date, status, created_at
		 FROM permits ORDER BY expiration_date LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM permits`,
		`SELECT * FROM permits WHERE id = ?`,
		"permit_number", "permit_name",
	)

	// Lookup tables backing permit_type_id and issuing_agency_id
	// FKs. Read-only from the UI — admin UIs for these come later.
	s.entityRoutes("/api/permit-types", "permit type",
		`SELECT id, type_code, type_name, category, federal_authority
		 FROM permit_types ORDER BY category, type_name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM permit_types`,
		`SELECT * FROM permit_types WHERE id = ?`,
		"type_code", "type_name", "category",
	)

	s.entityRoutes("/api/regulatory-agencies", "regulatory agency",
		`SELECT id, agency_code, agency_name, agency_type,
		        jurisdiction_state, jurisdiction_region
		 FROM regulatory_agencies ORDER BY agency_name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM regulatory_agencies`,
		`SELECT * FROM regulatory_agencies WHERE id = ?`,
		"agency_code", "agency_name",
	)

	// -- Industrial Waste --

	s.entityRoutes("/api/waste-streams", "waste stream",
		`SELECT id, establishment_id, stream_code, stream_name,
		        waste_category, waste_stream_type_code, physical_form,
		        is_active, created_at
		 FROM waste_streams ORDER BY stream_name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM waste_streams`,
		`SELECT * FROM waste_streams WHERE id = ?`,
		"stream_code", "stream_name",
	)

	// -- PPE --

	s.entityRoutes("/api/ppe/items", "PPE item",
		`SELECT id, establishment_id, ppe_type_id, serial_number, asset_tag,
		        manufacturer, model, size, in_service_date, expiration_date,
		        status, current_employee_id, created_at
		 FROM ppe_items ORDER BY created_at DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM ppe_items`,
		`SELECT * FROM ppe_items WHERE id = ?`,
		"serial_number", "asset_tag", "model",
	)

	s.entityRoutes("/api/ppe/assignments", "PPE assignment",
		`SELECT id, ppe_item_id, employee_id, assigned_date,
		        returned_date, returned_condition, employee_acknowledged, created_at
		 FROM ppe_assignments ORDER BY assigned_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM ppe_assignments`,
		`SELECT * FROM ppe_assignments WHERE id = ?`,
	)

	// -- Dashboard summary --
	s.mux.HandleFunc("GET /api/dashboard/counts", s.handleDashboardCounts)
}

func (s *Server) handleDashboardCounts(w http.ResponseWriter, r *http.Request) {
	queries := map[string]string{
		"establishments":   "SELECT COUNT(*) FROM establishments",
		"employees":        "SELECT COUNT(*) FROM employees WHERE is_active = 1",
		"open_incidents":   "SELECT COUNT(*) FROM incidents WHERE status != 'closed'",
		"open_cas":         "SELECT COUNT(*) FROM corrective_actions WHERE status NOT IN ('completed', 'verified')",
		"chemicals":        "SELECT COUNT(*) FROM chemicals WHERE is_active = 1",
		"active_permits":   "SELECT COUNT(*) FROM permits WHERE status = 'active'",
		"expiring_permits": "SELECT COUNT(*) FROM permits WHERE status = 'active' AND expiration_date <= date('now', '+90 days')",
	}

	counts := make(map[string]any, len(queries))
	for key, sql := range queries {
		val, err := s.db.QueryVal(sql)
		if err != nil {
			counts[key] = nil
			continue
		}
		counts[key] = val
	}
	writeJSON(w, counts)
}
