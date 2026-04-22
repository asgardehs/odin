package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/asgardehs/odin/internal/importer"
	"github.com/asgardehs/odin/internal/ratatoskr"
)

// importRoutes registers the bulk-import API. All routes are admin-only.
// Lifecycle (CSV and XLSX share everything after upload — same token, same
// mapping/commit/discard endpoints under the CSV path):
//   GET    /api/import/modules                                 — list modules + target fields
//   POST   /api/import/csv/{module}                            — multipart CSV upload, returns a token
//   POST   /api/import/xlsx/{module}                           — multipart XLSX upload, returns a token
//   GET    /api/import/csv/{module}/{token}                    — status + current mapping + validation errors
//   PUT    /api/import/csv/{module}/{token}/mapping            — update mapping, re-validate
//   POST   /api/import/csv/{module}/{token}/commit?skip_invalid=1
//   DELETE /api/import/csv/{module}/{token}                    — discard
func (s *Server) importRoutes() {
	s.mux.HandleFunc("GET /api/import/modules", s.handleImportListModules)
	s.mux.HandleFunc("POST /api/import/csv/{module}", s.handleImportUpload)
	s.mux.HandleFunc("POST /api/import/xlsx/{module}", s.handleImportUploadXLSX)
	s.mux.HandleFunc("GET /api/import/csv/{module}/{token}", s.handleImportStatus)
	s.mux.HandleFunc("PUT /api/import/csv/{module}/{token}/mapping", s.handleImportUpdateMapping)
	s.mux.HandleFunc("POST /api/import/csv/{module}/{token}/commit", s.handleImportCommit)
	s.mux.HandleFunc("DELETE /api/import/csv/{module}/{token}", s.handleImportDiscard)
}

// importModuleDescriptor is what the UI needs to build its module picker
// and its mapping dropdowns: slug + human label + the target fields.
type importModuleDescriptor struct {
	Slug         string                  `json:"slug"`
	Label        string                  `json:"label"`
	TargetFields []importer.TargetField `json:"target_fields"`
}

var moduleLabels = map[string]string{
	"employees": "Employees",
	"chemicals": "Chemicals",
	"training_completions": "Training Completions",
}

func (s *Server) handleImportListModules(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}
	if s.importer == nil {
		writeError(w, "import framework not configured", http.StatusServiceUnavailable)
		return
	}
	out := make([]importModuleDescriptor, 0)
	for _, slug := range importer.Modules() {
		imp, _ := importer.Get(slug)
		label := moduleLabels[slug]
		if label == "" {
			label = slug
		}
		out = append(out, importModuleDescriptor{
			Slug:         slug,
			Label:        label,
			TargetFields: imp.TargetFields(),
		})
	}
	writeJSON(w, map[string]any{"modules": out})
}

func (s *Server) handleImportUpload(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	if s.importer == nil {
		writeError(w, "import framework not configured", http.StatusServiceUnavailable)
		return
	}

	module := r.PathValue("module")

	// Cap the parser to MaxFileBytes + a small overhead for form fields.
	r.Body = http.MaxBytesReader(w, r.Body, importer.MaxFileBytes+1<<20)
	if err := r.ParseMultipartForm(int64(importer.MaxFileBytes + 1<<20)); err != nil {
		writeError(w, "upload too large or malformed: "+err.Error(), http.StatusBadRequest)
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, "missing 'file' form field", http.StatusBadRequest)
		return
	}
	defer file.Close()

	var targetEstablishmentID *int64
	if raw := r.FormValue("target_establishment_id"); raw != "" {
		if id, err := strconv.ParseInt(raw, 10, 64); err == nil {
			targetEstablishmentID = &id
		} else {
			writeError(w, "target_establishment_id must be an integer", http.StatusBadRequest)
			return
		}
	}

	preview, err := s.importer.Upload(module, admin.Username, header.Filename, file, targetEstablishmentID)
	if err != nil {
		switch {
		case errors.Is(err, importer.ErrUnknownModule):
			writeError(w, err.Error(), http.StatusNotFound)
		default:
			writeError(w, err.Error(), http.StatusBadRequest)
		}
		return
	}
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, preview)
}

// handleImportUploadXLSX runs the same flow as handleImportUpload but
// parses the multipart file through ratatoskr (embedded Python + openpyxl)
// before handing the header/row slices off to importer.Engine.UploadParsed.
//
// The odin binary must be built with `-tags ratatoskr_embed` for the
// embedded Python distribution to be available; otherwise this returns
// 503 with a short hint about the build flag.
func (s *Server) handleImportUploadXLSX(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	if s.importer == nil {
		writeError(w, "import framework not configured", http.StatusServiceUnavailable)
		return
	}

	module := r.PathValue("module")

	r.Body = http.MaxBytesReader(w, r.Body, importer.MaxFileBytes+1<<20)
	if err := r.ParseMultipartForm(int64(importer.MaxFileBytes + 1<<20)); err != nil {
		writeError(w, "upload too large or malformed: "+err.Error(), http.StatusBadRequest)
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, "missing 'file' form field", http.StatusBadRequest)
		return
	}
	defer file.Close()

	var targetEstablishmentID *int64
	if raw := r.FormValue("target_establishment_id"); raw != "" {
		if id, err := strconv.ParseInt(raw, 10, 64); err == nil {
			targetEstablishmentID = &id
		} else {
			writeError(w, "target_establishment_id must be an integer", http.StatusBadRequest)
			return
		}
	}

	// openpyxl reads a path, not a stream — buffer to a tempfile scoped
	// to this request.
	tmp, err := os.CreateTemp("", "odin-xlsx-*"+xlsxSuffix(header.Filename))
	if err != nil {
		writeError(w, "could not stage upload: "+err.Error(), http.StatusInternalServerError)
		return
	}
	defer os.Remove(tmp.Name())
	if _, err := io.Copy(tmp, file); err != nil {
		tmp.Close()
		writeError(w, "could not stage upload: "+err.Error(), http.StatusInternalServerError)
		return
	}
	if err := tmp.Close(); err != nil {
		writeError(w, "could not stage upload: "+err.Error(), http.StatusInternalServerError)
		return
	}

	parser, err := s.getXLSXParser()
	if err != nil {
		writeError(w, "xlsx import unavailable: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	parsed, err := parser.ParseXLSX(tmp.Name())
	if err != nil {
		writeError(w, "parse xlsx: "+err.Error(), http.StatusBadRequest)
		return
	}

	preview, err := s.importer.UploadParsed(module, admin.Username, header.Filename, parsed.Headers, parsed.Rows, targetEstablishmentID)
	if err != nil {
		switch {
		case errors.Is(err, importer.ErrUnknownModule):
			writeError(w, err.Error(), http.StatusNotFound)
		default:
			writeError(w, err.Error(), http.StatusBadRequest)
		}
		return
	}
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, preview)
}

// xlsxSuffix returns ".xlsx" or ".xls" based on the uploaded filename,
// falling back to ".xlsx". openpyxl sniffs the file by content, but
// giving the tempfile a real extension makes debugging easier.
func xlsxSuffix(name string) string {
	lower := strings.ToLower(name)
	switch {
	case strings.HasSuffix(lower, ".xlsx"):
		return ".xlsx"
	case strings.HasSuffix(lower, ".xls"):
		return ".xls"
	default:
		return ".xlsx"
	}
}

// getXLSXParser returns the lazily-initialized ratatoskr parser. First
// call triggers the embedded-Python extract + openpyxl install, which
// can take several seconds on a cold cache; subsequent calls are O(1).
func (s *Server) getXLSXParser() (*ratatoskr.XLSX, error) {
	s.xlsxOnce.Do(func() {
		s.xlsx, s.xlsxErr = ratatoskr.New()
	})
	return s.xlsx, s.xlsxErr
}

func (s *Server) handleImportStatus(w http.ResponseWriter, r *http.Request) {
	if admin := s.requireAdmin(w, r); admin == nil {
		return
	}
	if s.importer == nil {
		writeError(w, "import framework not configured", http.StatusServiceUnavailable)
		return
	}
	token := r.PathValue("token")
	preview, err := s.importer.GetStatus(token)
	if err != nil {
		writeImportErr(w, err)
		return
	}
	writeJSON(w, preview)
}

func (s *Server) handleImportUpdateMapping(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	if s.importer == nil {
		writeError(w, "import framework not configured", http.StatusServiceUnavailable)
		return
	}
	token := r.PathValue("token")

	var body struct {
		Mapping map[string]string `json:"mapping"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if body.Mapping == nil {
		writeError(w, "mapping is required", http.StatusBadRequest)
		return
	}

	preview, err := s.importer.UpdateMapping(token, admin.Username, body.Mapping)
	if err != nil {
		writeImportErr(w, err)
		return
	}
	writeJSON(w, preview)
}

func (s *Server) handleImportCommit(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	if s.importer == nil {
		writeError(w, "import framework not configured", http.StatusServiceUnavailable)
		return
	}
	token := r.PathValue("token")
	skipInvalid := r.URL.Query().Get("skip_invalid") == "1"

	result, err := s.importer.Commit(token, admin.Username, skipInvalid)
	if err != nil {
		writeImportErr(w, err)
		return
	}
	writeJSON(w, result)
}

func (s *Server) handleImportDiscard(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	if s.importer == nil {
		writeError(w, "import framework not configured", http.StatusServiceUnavailable)
		return
	}
	token := r.PathValue("token")
	if err := s.importer.Discard(token, admin.Username); err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"status": "discarded", "token": token})
}

func writeImportErr(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, importer.ErrNotFound):
		writeError(w, "import token not found", http.StatusNotFound)
	case errors.Is(err, importer.ErrExpired):
		writeError(w, "import token expired", http.StatusGone)
	case errors.Is(err, importer.ErrAlreadyCommitted):
		writeError(w, "import already committed or discarded", http.StatusConflict)
	case errors.Is(err, importer.ErrUnknownModule):
		writeError(w, err.Error(), http.StatusNotFound)
	default:
		writeError(w, fmt.Sprint(err), http.StatusBadRequest)
	}
}
