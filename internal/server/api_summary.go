package server

import (
	"net/http"
	"strconv"
	"time"
)

// Summary is the response shape for /api/{module}/summary endpoints. Each
// endpoint feeds a single KPICard on a hub. Phase 2 ships stubs returning
// zero-valued Summary; Phase 3+ replaces stubs with live aggregates.
//
// Stub responses are intentionally minimal — frontend code reads a stub
// the same way it reads a live aggregate, so the KPICard renders its
// empty/loading state until each module's aggregate lands.
type Summary struct {
	Primary   *SummaryMetric `json:"primary,omitempty"`
	Secondary *SummaryMetric `json:"secondary,omitempty"`
	// Status drives the KPI card color band. One of "ok", "warn", "alert".
	// Empty string = neutral / no signal yet.
	Status string `json:"status,omitempty"`
	// Empty signals the underlying table has no records — KPICard renders
	// the "No records yet — add your first" CTA when true.
	Empty bool `json:"empty"`
}

// SummaryMetric is a single labelled count rendered inside a KPICard slot.
type SummaryMetric struct {
	Label string `json:"label"`
	Value int64  `json:"value"`
}

// registerSummaryRoutes wires per-module summary endpoints. Each accepts an
// optional ?facility_id=X query param (ignored by stubs; honored once each
// module's aggregate lands in a later phase).
func (s *Server) registerSummaryRoutes() {
	if s.db == nil {
		return
	}

	// Top-level Dashboard + Facilities hub
	s.mux.HandleFunc("GET /api/permits/summary", s.handlePermitsSummary)
	s.mux.HandleFunc("GET /api/emission-units/summary", s.summaryStub("air_emission_units"))
	s.mux.HandleFunc("GET /api/waste-streams/summary", s.summaryStub("waste_streams"))
	s.mux.HandleFunc("GET /api/chemicals/summary", s.summaryStub("chemicals"))
	s.mux.HandleFunc("GET /api/storage-locations/summary", s.summaryStub("storage_locations"))
	s.mux.HandleFunc("GET /api/discharge-points/summary", s.summaryStub("discharge_points"))

	// Employees hub
	s.mux.HandleFunc("GET /api/training/summary", s.handleTrainingSummary)
	s.mux.HandleFunc("GET /api/ppe/summary", s.summaryStub("ppe_items"))
	s.mux.HandleFunc("GET /api/incidents/summary", s.handleIncidentsSummary)

	// Inspections hub
	s.mux.HandleFunc("GET /api/audits/summary", s.handleAuditsSummary)
	s.mux.HandleFunc("GET /api/ww-sample-events/summary", s.handleSampleEventsSummary)

	// Top-level Dashboard only — has no list page or hub of its own.
	s.mux.HandleFunc("GET /api/osha-300/summary", s.handleOSHA300Summary)
}

// summaryStub returns a handler that derives only the Empty flag from a
// COUNT(*) on the given table. Phase 3+ replaces each stub with a real
// aggregate; the Empty-from-count behavior carries forward unchanged.
//
// table is a hard-coded literal at every call site (never user input), so
// concatenation into the query is safe.
func (s *Server) summaryStub(table string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		val, err := s.db.QueryVal("SELECT COUNT(*) FROM " + table)
		if err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}
		n, _ := val.(int64)
		writeJSON(w, Summary{Empty: n == 0})
	}
}

// facilityFilter pulls ?facility_id=X off the request and returns a SQL
// fragment + args appendable to an existing WHERE clause. Returns ("",
// nil) when the param is absent or invalid.
//
// column is hard-coded at every call site (never user input), so
// concatenation into the query is safe.
func facilityFilter(r *http.Request, column string) (string, []any) {
	raw := r.URL.Query().Get("facility_id")
	if raw == "" {
		return "", nil
	}
	id, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || id <= 0 {
		return "", nil
	}
	return " AND " + column + " = ?", []any{id}
}

// statusForOpenItems applies the project-wide convention for "open work
// item" KPIs (counts where 0 is good and higher is worse):
//
//	0   → ok    (green)
//	1-3 → warn  (yellow)
//	4+  → alert (red)
//
// Mirror of frontend/src/utils/status.ts. Keep in sync.
func statusForOpenItems(count int64) string {
	switch {
	case count == 0:
		return "ok"
	case count <= 3:
		return "warn"
	default:
		return "alert"
	}
}

// handleTrainingSummary aggregates expiring-training counts for the
// top-level Dashboard / Employees hub card.
//
//   - primary   = completions whose retraining is due in ≤30 days
//   - secondary = completions due in 31-60 days
//   - status    = derived from primary via statusForOpenItems
//   - empty     = true when the scope has no training_completions at all
//
// Facility scope joins through employees (training_completions.employee_id
// → employees.establishment_id).
func (s *Server) handleTrainingSummary(w http.ResponseWriter, r *http.Request) {
	where, args := facilityFilter(r, "e.establishment_id")
	row, err := s.db.QueryRow(`
		SELECT
		  CAST(COALESCE(SUM(CASE WHEN tc.expiration_date IS NOT NULL
		         AND tc.expiration_date >= date('now')
		         AND tc.expiration_date <= date('now', '+30 days') THEN 1 ELSE 0 END), 0) AS INTEGER) AS bucket_30,
		  CAST(COALESCE(SUM(CASE WHEN tc.expiration_date IS NOT NULL
		         AND tc.expiration_date >  date('now', '+30 days')
		         AND tc.expiration_date <= date('now', '+60 days') THEN 1 ELSE 0 END), 0) AS INTEGER) AS bucket_60,
		  COUNT(*) AS total
		FROM training_completions tc
		JOIN employees e ON tc.employee_id = e.id
		WHERE 1=1`+where, args...)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	total, _ := row["total"].(int64)
	if total == 0 {
		writeJSON(w, Summary{Empty: true})
		return
	}
	bucket30, _ := row["bucket_30"].(int64)
	bucket60, _ := row["bucket_60"].(int64)
	writeJSON(w, Summary{
		Primary:   &SummaryMetric{Label: "due ≤30 days", Value: bucket30},
		Secondary: &SummaryMetric{Label: "in 31-60 days", Value: bucket60},
		Status:    statusForOpenItems(bucket30),
	})
}

// handleAuditsSummary aggregates open audit findings for the Inspections
// hub card.
//
//   - primary   = open findings (status NOT IN 'verified', 'closed')
//   - secondary = open major non-conformances (finding_type='major_nc')
//   - status    = derived from primary via statusForOpenItems
//   - empty     = true when no audit_findings exist in scope
//
// Facility scope joins through audits (audit_findings.audit_id →
// audits.establishment_id).
func (s *Server) handleAuditsSummary(w http.ResponseWriter, r *http.Request) {
	where, args := facilityFilter(r, "a.establishment_id")
	row, err := s.db.QueryRow(`
		SELECT
		  CAST(COALESCE(SUM(CASE WHEN af.status NOT IN ('verified','closed') THEN 1 ELSE 0 END), 0) AS INTEGER) AS open_total,
		  CAST(COALESCE(SUM(CASE WHEN af.status NOT IN ('verified','closed')
		         AND af.finding_type = 'major_nc' THEN 1 ELSE 0 END), 0) AS INTEGER) AS open_major,
		  COUNT(*) AS total
		FROM audit_findings af
		JOIN audits a ON af.audit_id = a.id
		WHERE 1=1`+where, args...)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	total, _ := row["total"].(int64)
	if total == 0 {
		writeJSON(w, Summary{Empty: true})
		return
	}
	openTotal, _ := row["open_total"].(int64)
	openMajor, _ := row["open_major"].(int64)
	writeJSON(w, Summary{
		Primary:   &SummaryMetric{Label: "open findings", Value: openTotal},
		Secondary: &SummaryMetric{Label: "major NCs", Value: openMajor},
		Status:    statusForOpenItems(openTotal),
	})
}

// handleIncidentsSummary aggregates open incidents for the top-level
// Dashboard / Employees hub card.
//
//   - primary   = open incidents (status != 'closed')
//   - secondary = open high-severity (FATALITY / LOST_TIME / RESTRICTED)
//   - status    = derived from primary via statusForOpenItems
//   - empty     = true when the scope has no incidents
func (s *Server) handleIncidentsSummary(w http.ResponseWriter, r *http.Request) {
	where, args := facilityFilter(r, "establishment_id")
	row, err := s.db.QueryRow(`
		SELECT
		  CAST(COALESCE(SUM(CASE WHEN status != 'closed' THEN 1 ELSE 0 END), 0) AS INTEGER) AS open_total,
		  CAST(COALESCE(SUM(CASE WHEN status != 'closed'
		         AND severity_code IN ('FATALITY','LOST_TIME','RESTRICTED') THEN 1 ELSE 0 END), 0) AS INTEGER) AS open_severe,
		  COUNT(*) AS total
		FROM incidents
		WHERE 1=1`+where, args...)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	total, _ := row["total"].(int64)
	if total == 0 {
		writeJSON(w, Summary{Empty: true})
		return
	}
	openTotal, _ := row["open_total"].(int64)
	openSevere, _ := row["open_severe"].(int64)
	writeJSON(w, Summary{
		Primary:   &SummaryMetric{Label: "open", Value: openTotal},
		Secondary: &SummaryMetric{Label: "high-severity open", Value: openSevere},
		Status:    statusForOpenItems(openTotal),
	})
}

// handleSampleEventsSummary aggregates open WW sampling events for the
// top-level Dashboard / Inspections hub card.
//
// "Due" interpretation: ww_sampling_events has no scheduled_date, so
// "due" means "not yet finalized for DMR submission" (status = 'in_progress').
// The secondary surfaces the urgent subset — in_progress events whose
// sample was taken more than 14 days ago, which likely means the lab
// results came back and finalization is overdue.
//
//   - primary   = in_progress events
//   - secondary = in_progress events with sample_date > 14 days old
//   - status    = derived from primary via statusForOpenItems
//   - empty     = true when the scope has no sampling events at all
func (s *Server) handleSampleEventsSummary(w http.ResponseWriter, r *http.Request) {
	where, args := facilityFilter(r, "establishment_id")
	row, err := s.db.QueryRow(`
		SELECT
		  CAST(COALESCE(SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END), 0) AS INTEGER) AS open_events,
		  CAST(COALESCE(SUM(CASE WHEN status = 'in_progress'
		         AND sample_date < date('now', '-14 days') THEN 1 ELSE 0 END), 0) AS INTEGER) AS overdue_events,
		  COUNT(*) AS total
		FROM ww_sampling_events
		WHERE 1=1`+where, args...)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	total, _ := row["total"].(int64)
	if total == 0 {
		writeJSON(w, Summary{Empty: true})
		return
	}
	openEvents, _ := row["open_events"].(int64)
	overdueEvents, _ := row["overdue_events"].(int64)
	writeJSON(w, Summary{
		Primary:   &SummaryMetric{Label: "needing finalization", Value: openEvents},
		Secondary: &SummaryMetric{Label: "overdue 14d+", Value: overdueEvents},
		Status:    statusForOpenItems(openEvents),
	})
}

// handleOSHA300Summary surfaces year-to-date OSHA 300 recordable activity
// plus the prior year's ITA submission state. Distinct from the other
// summaries: this is an info card, not an open-work-item card.
//
//   - primary   = recordable incidents YTD (anything except FIRST_AID)
//   - secondary = high-severity YTD (FATALITY / LOST_TIME / RESTRICTED)
//   - status    = derived from prior-year ITA submission vs March 2 deadline:
//       'ok'    if a 300A row for prior year has ita_submitted_date set
//       'alert' if today is past March 2 and no submission recorded
//       ''      otherwise (pre-deadline window — not yet actionable)
//   - empty     = true only when no incidents have ever been logged in
//                 scope (a fresh DB; "0 recordable YTD" on an established
//                 site is information, not an empty CTA)
func (s *Server) handleOSHA300Summary(w http.ResponseWriter, r *http.Request) {
	where, args := facilityFilter(r, "establishment_id")
	row, err := s.db.QueryRow(`
		SELECT
		  CAST(COALESCE(SUM(CASE WHEN incident_date >= date('now', 'start of year')
		         AND severity_code != 'FIRST_AID' THEN 1 ELSE 0 END), 0) AS INTEGER) AS recordable_ytd,
		  CAST(COALESCE(SUM(CASE WHEN incident_date >= date('now', 'start of year')
		         AND severity_code IN ('FATALITY','LOST_TIME','RESTRICTED') THEN 1 ELSE 0 END), 0) AS INTEGER) AS severe_ytd,
		  COUNT(*) AS total
		FROM incidents
		WHERE 1=1`+where, args...)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	total, _ := row["total"].(int64)
	if total == 0 {
		writeJSON(w, Summary{Empty: true})
		return
	}
	recordable, _ := row["recordable_ytd"].(int64)
	severe, _ := row["severe_ytd"].(int64)

	// ITA submission state for prior year. If facility-scoped, look at
	// that facility's 300A row; otherwise check whether all establishments
	// with prior-year recordables have submitted.
	itaWhere, itaArgs := facilityFilter(r, "establishment_id")
	itaRow, _ := s.db.QueryRow(`
		SELECT
		  CAST(COUNT(*) AS INTEGER) AS rows_for_year,
		  CAST(COALESCE(SUM(CASE WHEN ita_submitted_date IS NOT NULL THEN 1 ELSE 0 END), 0) AS INTEGER) AS submitted_count
		FROM osha_300a_summaries
		WHERE year = CAST(strftime('%Y', date('now', '-1 year')) AS INTEGER)`+itaWhere, itaArgs...)

	status := ""
	if itaRow != nil {
		rowsForYear, _ := itaRow["rows_for_year"].(int64)
		submitted, _ := itaRow["submitted_count"].(int64)
		// 29 CFR 1904.41(c)(2): 300A summary for year Y is due by March 2
		// of year Y+1. Compare today against this year's March 2 to know
		// whether the prior-year submission window has closed.
		today := time.Now().UTC().Truncate(24 * time.Hour)
		deadline := time.Date(today.Year(), 3, 2, 0, 0, 0, 0, time.UTC)
		switch {
		case rowsForYear > 0 && submitted == rowsForYear:
			status = "ok"
		case today.After(deadline) && rowsForYear > 0 && submitted < rowsForYear:
			status = "alert"
		}
	}

	writeJSON(w, Summary{
		Primary:   &SummaryMetric{Label: "recordable YTD", Value: recordable},
		Secondary: &SummaryMetric{Label: "high-severity YTD", Value: severe},
		Status:    status,
	})
}

// handlePermitsSummary aggregates active-permit expiry buckets for the
// top-level Dashboard / Facilities hub card.
//
//   - primary   = active permits expiring within 30 days (the urgent ones)
//   - secondary = active permits expiring 31-60 days out (the planning window)
//   - status    = derived from primary via statusForOpenItems
//   - empty     = true when the scope has no active permits at all
//
// One round-trip via SUM(CASE) — cheaper than three count queries and
// gives us the active-total for the empty signal in the same pass.
func (s *Server) handlePermitsSummary(w http.ResponseWriter, r *http.Request) {
	where, args := facilityFilter(r, "establishment_id")
	row, err := s.db.QueryRow(`
		SELECT
		  CAST(COALESCE(SUM(CASE WHEN expiration_date IS NOT NULL
		         AND expiration_date >= date('now')
		         AND expiration_date <= date('now', '+30 days') THEN 1 ELSE 0 END), 0) AS INTEGER) AS bucket_30,
		  CAST(COALESCE(SUM(CASE WHEN expiration_date IS NOT NULL
		         AND expiration_date >  date('now', '+30 days')
		         AND expiration_date <= date('now', '+60 days') THEN 1 ELSE 0 END), 0) AS INTEGER) AS bucket_60,
		  COUNT(*) AS active_total
		FROM permits
		WHERE status = 'active'`+where, args...)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	total, _ := row["active_total"].(int64)
	if total == 0 {
		writeJSON(w, Summary{Empty: true})
		return
	}

	bucket30, _ := row["bucket_30"].(int64)
	bucket60, _ := row["bucket_60"].(int64)

	writeJSON(w, Summary{
		Primary:   &SummaryMetric{Label: "expiring ≤30 days", Value: bucket30},
		Secondary: &SummaryMetric{Label: "in 31-60 days", Value: bucket60},
		Status:    statusForOpenItems(bucket30),
	})
}
