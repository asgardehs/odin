package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"github.com/asgardehs/odin/internal/importer"
)

// importRoutes registers the CSV import API. All routes are admin-only.
// Lifecycle:
//   GET    /api/import/modules                                 — list modules + target fields
//   POST   /api/import/csv/{module}                            — multipart upload, returns a token
//   GET    /api/import/csv/{module}/{token}                    — status + current mapping + validation errors
//   PUT    /api/import/csv/{module}/{token}/mapping            — update mapping, re-validate
//   POST   /api/import/csv/{module}/{token}/commit?skip_invalid=1
//   DELETE /api/import/csv/{module}/{token}                    — discard
func (s *Server) importRoutes() {
	s.mux.HandleFunc("GET /api/import/modules", s.handleImportListModules)
	s.mux.HandleFunc("POST /api/import/csv/{module}", s.handleImportUpload)
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
