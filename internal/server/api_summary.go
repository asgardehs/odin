package server

import (
	"net/http"
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
	s.mux.HandleFunc("GET /api/permits/summary", s.summaryStub("permits"))
	s.mux.HandleFunc("GET /api/emission-units/summary", s.summaryStub("air_emission_units"))
	s.mux.HandleFunc("GET /api/waste-streams/summary", s.summaryStub("waste_streams"))
	s.mux.HandleFunc("GET /api/chemicals/summary", s.summaryStub("chemicals"))
	s.mux.HandleFunc("GET /api/storage-locations/summary", s.summaryStub("storage_locations"))
	s.mux.HandleFunc("GET /api/discharge-points/summary", s.summaryStub("discharge_points"))

	// Employees hub. training_completions is the right "module has data"
	// signal here — Phase 3's training KPI will be expiring completions.
	s.mux.HandleFunc("GET /api/training/summary", s.summaryStub("training_completions"))
	s.mux.HandleFunc("GET /api/ppe/summary", s.summaryStub("ppe_items"))
	s.mux.HandleFunc("GET /api/incidents/summary", s.summaryStub("incidents"))

	// Inspections hub
	s.mux.HandleFunc("GET /api/audits/summary", s.summaryStub("audits"))
	s.mux.HandleFunc("GET /api/ww-sample-events/summary", s.summaryStub("ww_sampling_events"))
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
