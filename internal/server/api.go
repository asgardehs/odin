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
		`SELECT id, chemical_id, storage_location_id, container_type, container_count,
		        quantity, unit, snapshot_date, snapshot_type, created_at
		 FROM chemical_inventory ORDER BY snapshot_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM chemical_inventory`,
		`SELECT * FROM chemical_inventory WHERE id = ?`,
	)

	s.entityRoutes("/api/storage-locations", "storage location",
		`SELECT id, establishment_id, building, room, area,
		        grid_reference, is_indoor, storage_pressure, storage_temperature,
		        container_types, max_capacity_gallons, is_active, created_at
		 FROM storage_locations ORDER BY building, room, area LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM storage_locations`,
		`SELECT * FROM storage_locations WHERE id = ?`,
		"building", "room", "area",
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

	s.entityRoutes("/api/inspection-findings", "inspection finding",
		`SELECT id, inspection_id, finding_number, finding_type, severity,
		        finding_description, location, regulatory_citation,
		        immediate_action, status, closed_date, corrective_action_id,
		        incident_id, created_at
		 FROM inspection_findings ORDER BY created_at DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM inspection_findings`,
		`SELECT * FROM inspection_findings WHERE id = ?`,
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

	s.entityRoutes("/api/audit-findings", "audit finding",
		`SELECT id, audit_id, finding_number, finding_type,
		        clause_number, clause_title, finding_statement,
		        process_area, risk_level, status,
		        verified_date, corrective_action_id, created_at
		 FROM audit_findings ORDER BY created_at DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM audit_findings`,
		`SELECT * FROM audit_findings WHERE id = ?`,
	)

	s.entityRoutes("/api/iso-standards", "iso standard",
		`SELECT id, standard_code, standard_name, full_title, current_version, is_active
		 FROM iso_standards ORDER BY standard_code LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM iso_standards`,
		`SELECT * FROM iso_standards WHERE id = ?`,
		"standard_code", "standard_name",
	)

	s.entityRoutes("/api/air-stacks", "air stack",
		`SELECT id, establishment_id, stack_name, stack_number,
		        height_ft, diameter_in, is_active
		 FROM air_stacks ORDER BY stack_name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM air_stacks`,
		`SELECT * FROM air_stacks WHERE id = ?`,
		"stack_name", "stack_number",
	)

	s.entityRoutes("/api/air-permit-types", "air permit type",
		`SELECT code, name, description, cfr_reference
		 FROM air_permit_types ORDER BY name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM air_permit_types`,
		`SELECT * FROM air_permit_types WHERE code = ?`,
		"name", "code",
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

	// -- Module D: Clean Water --

	s.entityRoutes("/api/discharge-points", "discharge point",
		`SELECT id, establishment_id, outfall_code, outfall_name,
		        discharge_type, receiving_waterbody, receiving_waterbody_type,
		        permit_id, stormwater_sector_code, swppp_id, status,
		        is_impaired_water, tmdl_applies
		 FROM discharge_points ORDER BY outfall_code LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM discharge_points`,
		`SELECT * FROM discharge_points WHERE id = ?`,
		"outfall_code", "outfall_name", "receiving_waterbody",
	)

	s.entityRoutes("/api/ww-monitoring-locations", "monitoring location",
		`SELECT id, establishment_id, location_code, location_name,
		        location_type, discharge_point_id, permit_id, emission_unit_id,
		        is_active, latitude, longitude
		 FROM ww_monitoring_locations ORDER BY location_code LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM ww_monitoring_locations`,
		`SELECT * FROM ww_monitoring_locations WHERE id = ?`,
		"location_code", "location_name",
	)

	s.entityRoutes("/api/ww-parameters", "water parameter",
		`SELECT id, parameter_code, parameter_name, parameter_category,
		        pollutant_type_code, cas_number, typical_units, typical_method,
		        priority_pollutant, toxic_pollutant
		 FROM ww_parameters ORDER BY parameter_category, parameter_name LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM ww_parameters`,
		`SELECT * FROM ww_parameters WHERE id = ?`,
		"parameter_code", "parameter_name", "cas_number",
	)

	s.entityRoutes("/api/ww-sample-events", "water sample event",
		`SELECT id, establishment_id, location_id, event_number,
		        sample_date, sample_time, sample_type, weather_conditions,
		        lab_submission_id, status, sampled_by_employee_id
		 FROM ww_sampling_events ORDER BY sample_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM ww_sampling_events`,
		`SELECT * FROM ww_sampling_events WHERE id = ?`,
		"event_number",
	)

	// Results don't have a top-level list page — they're accessed via the
	// parent event — but the /api/ww-sample-results/{id} GET is still useful
	// for audit trail links.
	s.entityRoutes("/api/ww-sample-results", "water sample result",
		`SELECT id, event_id, parameter_id, result_value, result_units,
		        result_qualifier, detection_limit, analyzed_date, analyzed_by
		 FROM ww_sample_results ORDER BY id DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM ww_sample_results`,
		`SELECT * FROM ww_sample_results WHERE id = ?`,
	)

	s.entityRoutes("/api/swpps", "SWPPP",
		`SELECT id, establishment_id, revision_number, effective_date,
		        next_annual_review_due, pollution_prevention_team_lead_employee_id,
		        permit_id, status, supersedes_swppp_id
		 FROM sw_swpps ORDER BY effective_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM sw_swpps`,
		`SELECT * FROM sw_swpps WHERE id = ?`,
		"revision_number",
	)

	s.entityRoutes("/api/bmps", "BMP",
		`SELECT id, swppp_id, establishment_id, bmp_code, bmp_name,
		        bmp_type, bmp_subtype, inspection_frequency,
		        responsible_role, status, next_inspection_due
		 FROM sw_bmps ORDER BY bmp_code LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM sw_bmps`,
		`SELECT * FROM sw_bmps WHERE id = ?`,
		"bmp_code", "bmp_name",
	)

	s.entityRoutes("/api/sw-industrial-sectors", "MSGP industrial sector",
		`SELECT code, sic_prefix, name, msgp_part
		 FROM sw_industrial_sectors ORDER BY code LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM sw_industrial_sectors`,
		`SELECT * FROM sw_industrial_sectors WHERE code = ?`,
		"code", "name",
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

	s.entityRoutes("/api/ppe/inspections", "PPE inspection",
		`SELECT id, ppe_item_id, inspection_date, inspected_by_employee_id,
		        passed, condition, next_inspection_due, removed_from_service, created_at
		 FROM ppe_inspections ORDER BY inspection_date DESC LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM ppe_inspections`,
		`SELECT * FROM ppe_inspections WHERE id = ?`,
	)

	s.entityRoutes("/api/ppe/types", "PPE type",
		`SELECT id, type_code, type_name, requires_fit_test
		 FROM ppe_types ORDER BY type_code LIMIT ? OFFSET ?`,
		`SELECT COUNT(*) FROM ppe_types`,
		`SELECT * FROM ppe_types WHERE id = ?`,
		"type_code", "type_name",
	)

	// -- Dashboard summary --
	s.mux.HandleFunc("GET /api/dashboard/counts", s.handleDashboardCounts)

	// -- Lookups (dropdown reference data) --
	// Server-side whitelist of allowed tables lives in
	// internal/repository/lookup.go; unknown tables return 404.
	s.mux.HandleFunc("GET /api/lookup/{table}", func(w http.ResponseWriter, r *http.Request) {
		table := r.PathValue("table")
		rows, err := s.repo.ListLookup(table)
		if err != nil {
			writeError(w, err.Error(), http.StatusNotFound)
			return
		}
		writeJSON(w, map[string]any{"items": rows, "total": int64(len(rows))})
	})

	// -- OSHA ITA CSV export (admin-only, audit-logged) --
	s.registerOSHAITARoutes()
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
