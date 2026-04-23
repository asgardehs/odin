package server

import (
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strconv"

	"github.com/asgardehs/odin/internal/audit"
	"github.com/asgardehs/odin/internal/osha_ita"
)

// registerOSHAITARoutes wires up the three OSHA ITA export endpoints.
// Called from apiRoutes(). All three require admin; the two CSV-emitting
// routes write an audit entry on success.
func (s *Server) registerOSHAITARoutes() {
	s.mux.HandleFunc("GET /api/osha/ita/detail.csv", s.handleITADetailCSV)
	s.mux.HandleFunc("GET /api/osha/ita/summary.csv", s.handleITASummaryCSV)
	s.mux.HandleFunc("GET /api/osha/ita/preview", s.handleITAPreview)
}

// yearPattern matches the 4-digit year format OSHA ITA accepts.
var yearPattern = regexp.MustCompile(`^\d{4}$`)

// parseExportParams extracts establishment_id and year from query string
// and validates both. Writes error responses directly when invalid and
// returns ok=false so the caller returns early.
func parseExportParams(w http.ResponseWriter, r *http.Request) (establishmentID int64, year string, ok bool) {
	rawID := r.URL.Query().Get("establishment_id")
	if rawID == "" {
		writeError(w, "establishment_id is required", http.StatusBadRequest)
		return 0, "", false
	}
	id, err := strconv.ParseInt(rawID, 10, 64)
	if err != nil || id <= 0 {
		writeError(w, "establishment_id must be a positive integer", http.StatusBadRequest)
		return 0, "", false
	}

	year = r.URL.Query().Get("year")
	if !yearPattern.MatchString(year) {
		writeError(w, "year must be a 4-digit number (YYYY)", http.StatusBadRequest)
		return 0, "", false
	}

	return id, year, true
}

func (s *Server) handleITADetailCSV(w http.ResponseWriter, r *http.Request) {
	user := s.requireAdmin(w, r)
	if user == nil {
		return
	}

	estID, year, ok := parseExportParams(w, r)
	if !ok {
		return
	}

	reader, err := osha_ita.ExportDetail(s.db, estID, year)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	filename := fmt.Sprintf("osha-ita-detail-%d-%s.csv", estID, year)
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename=%q`, filename))
	if _, err := io.Copy(w, reader); err != nil {
		// Client likely disconnected mid-stream; headers are already
		// written so there's nothing useful we can report in the body.
		return
	}

	s.recordITAExport(user.Username, estID, year, "detail")
}

func (s *Server) handleITASummaryCSV(w http.ResponseWriter, r *http.Request) {
	user := s.requireAdmin(w, r)
	if user == nil {
		return
	}

	estID, year, ok := parseExportParams(w, r)
	if !ok {
		return
	}

	reader, err := osha_ita.ExportSummary(s.db, estID, year)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	filename := fmt.Sprintf("osha-ita-summary-%d-%s.csv", estID, year)
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename=%q`, filename))
	if _, err := io.Copy(w, reader); err != nil {
		return
	}

	s.recordITAExport(user.Username, estID, year, "summary")
}

func (s *Server) handleITAPreview(w http.ResponseWriter, r *http.Request) {
	if s.requireAdmin(w, r) == nil {
		return
	}

	estID, year, ok := parseExportParams(w, r)
	if !ok {
		return
	}

	preview, err := osha_ita.Preview(s.db, estID, year)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, preview)
}

// recordITAExport writes one audit entry per successful CSV export. The
// entry uses module="osha_ita" and a synthetic entity_id of
// "{establishment_id}-{year}-{kind}" so each (establishment, year, kind)
// export is distinctly tracked in the audit timeline.
func (s *Server) recordITAExport(user string, establishmentID int64, year, kind string) {
	if s.audit == nil {
		return
	}
	_ = s.audit.Record(audit.Entry{
		Action:   audit.ActionExport,
		Module:   "osha_ita",
		EntityID: fmt.Sprintf("%d-%s-%s", establishmentID, year, kind),
		User:     user,
		Summary:  fmt.Sprintf("Exported OSHA ITA %s CSV for establishment %d, year %s", kind, establishmentID, year),
	})
}
