package server

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/asgardehs/odin/internal/repository"
)

// writeRoutes registers POST, PUT, DELETE endpoints for entities
// that have repository-backed CRUD with audit trail recording.
func (s *Server) writeRoutes() {
	if s.repo == nil {
		return
	}

	// -- Establishments --
	s.mux.HandleFunc("POST /api/establishments", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.EstablishmentInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateEstablishment(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/establishments/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.EstablishmentInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateEstablishment(user, id, in)
		},
	))
	s.mux.HandleFunc("DELETE /api/establishments/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteEstablishment(user, id)
		},
	))

	// -- Employees --
	s.mux.HandleFunc("POST /api/employees", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.EmployeeInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateEmployee(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/employees/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.EmployeeInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateEmployee(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/employees/{id}/deactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.DeactivateEmployee(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/employees/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteEmployee(user, id)
		},
	))

	// -- Incidents --
	s.mux.HandleFunc("POST /api/incidents", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.IncidentInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateIncident(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/incidents/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.IncidentInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateIncident(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/incidents/{id}/close", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.CloseIncident(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/incidents/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteIncident(user, id)
		},
	))

	// -- Corrective Actions --
	s.mux.HandleFunc("POST /api/corrective-actions", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.CorrectiveActionInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateCorrectiveAction(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/corrective-actions/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.CorrectiveActionInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateCorrectiveAction(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/corrective-actions/{id}/complete", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.CompleteCorrectiveAction(user, id)
		},
	))
	s.mux.HandleFunc("POST /api/corrective-actions/{id}/verify", s.handleAction(
		func(user string, id int64, body []byte) error {
			var req struct {
				Notes string `json:"notes"`
			}
			json.Unmarshal(body, &req)
			return s.repo.VerifyCorrectiveAction(user, id, req.Notes)
		},
	))
	s.mux.HandleFunc("DELETE /api/corrective-actions/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteCorrectiveAction(user, id)
		},
	))

	// -- Chemicals --
	s.mux.HandleFunc("POST /api/chemicals", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.ChemicalInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateChemical(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/chemicals/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.ChemicalInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateChemical(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/chemicals/{id}/discontinue", s.handleAction(
		func(user string, id int64, body []byte) error {
			var req struct {
				Reason string `json:"reason"`
			}
			json.Unmarshal(body, &req)
			return s.repo.DiscontinueChemical(user, id, req.Reason)
		},
	))
	s.mux.HandleFunc("DELETE /api/chemicals/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteChemical(user, id)
		},
	))
}

// Handler factories — reduce boilerplate across write endpoints.
// All write endpoints use the OS username from the authenticator.

// handleCreate returns a handler that decodes a JSON body, calls the
// create function, and returns the new entity's ID.
func (s *Server) handleCreate(fn func(user string, body []byte) (int64, error)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		body, err := readBody(r)
		if err != nil {
			writeError(w, "invalid request body", http.StatusBadRequest)
			return
		}
		user := s.auth.CurrentUser()
		id, err := fn(user, body)
		if err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusCreated)
		writeJSON(w, map[string]int64{"id": id})
	}
}

// handleUpdate returns a handler that decodes a JSON body with a path ID,
// calls the update function.
func (s *Server) handleUpdate(fn func(user string, id int64, body []byte) error) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := parseID(r)
		if err != nil {
			writeError(w, "invalid id", http.StatusBadRequest)
			return
		}
		body, err := readBody(r)
		if err != nil {
			writeError(w, "invalid request body", http.StatusBadRequest)
			return
		}
		user := s.auth.CurrentUser()
		if err := fn(user, id, body); err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, map[string]string{"status": "ok"})
	}
}

// handleDelete returns a handler that deletes a resource by path ID.
func (s *Server) handleDelete(fn func(user string, id int64) error) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := parseID(r)
		if err != nil {
			writeError(w, "invalid id", http.StatusBadRequest)
			return
		}
		user := s.auth.CurrentUser()
		if err := fn(user, id); err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, map[string]string{"status": "ok"})
	}
}

// handleAction returns a handler for status-transition endpoints
// (close, complete, verify, deactivate, discontinue).
func (s *Server) handleAction(fn func(user string, id int64, body []byte) error) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := parseID(r)
		if err != nil {
			writeError(w, "invalid id", http.StatusBadRequest)
			return
		}
		body, _ := readBody(r) // body is optional for actions
		user := s.auth.CurrentUser()
		if err := fn(user, id, body); err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, map[string]string{"status": "ok"})
	}
}

func parseID(r *http.Request) (int64, error) {
	return strconv.ParseInt(r.PathValue("id"), 10, 64)
}

func readBody(r *http.Request) ([]byte, error) {
	defer r.Body.Close()
	var buf [1 << 20]byte // 1MB max
	n, err := r.Body.Read(buf[:])
	if err != nil && err.Error() != "EOF" {
		return nil, err
	}
	return buf[:n], nil
}
