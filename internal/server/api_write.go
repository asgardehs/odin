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
	s.mux.HandleFunc("POST /api/establishments/{id}/deactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.DeactivateEstablishment(user, id)
		},
	))
	s.mux.HandleFunc("POST /api/establishments/{id}/reactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.ReactivateEstablishment(user, id)
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
	s.mux.HandleFunc("POST /api/employees/{id}/reactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.ReactivateEmployee(user, id)
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
	s.mux.HandleFunc("POST /api/chemicals/{id}/reactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.ReactivateChemical(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/chemicals/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteChemical(user, id)
		},
	))

	// -- Training Courses --
	s.mux.HandleFunc("POST /api/training/courses", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.TrainingCourseInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateTrainingCourse(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/training/courses/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.TrainingCourseInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateTrainingCourse(user, id, in)
		},
	))
	s.mux.HandleFunc("DELETE /api/training/courses/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteTrainingCourse(user, id)
		},
	))

	// -- Training Completions --
	s.mux.HandleFunc("POST /api/training/completions", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.TrainingCompletionInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateTrainingCompletion(user, in)
		},
	))
	s.mux.HandleFunc("DELETE /api/training/completions/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteTrainingCompletion(user, id)
		},
	))

	// -- Training Assignments --
	s.mux.HandleFunc("POST /api/training/assignments", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.TrainingAssignmentInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateTrainingAssignment(user, in)
		},
	))
	s.mux.HandleFunc("POST /api/training/assignments/{id}/complete", s.handleAction(
		func(user string, id int64, body []byte) error {
			var req struct {
				CompletionID int64 `json:"completion_id"`
			}
			json.Unmarshal(body, &req)
			return s.repo.CompleteTrainingAssignment(user, id, req.CompletionID)
		},
	))
	s.mux.HandleFunc("POST /api/training/assignments/{id}/cancel", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.CancelTrainingAssignment(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/training/assignments/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteTrainingAssignment(user, id)
		},
	))

	// -- Inspections --
	s.mux.HandleFunc("POST /api/inspections", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.InspectionInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateInspection(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/inspections/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.InspectionInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateInspection(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/inspections/{id}/complete", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.CompleteInspection(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/inspections/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteInspection(user, id)
		},
	))

	// -- Inspection Findings --
	s.mux.HandleFunc("POST /api/inspection-findings", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.InspectionFindingInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateInspectionFinding(user, in)
		},
	))
	s.mux.HandleFunc("POST /api/inspection-findings/{id}/close", s.handleAction(
		func(user string, id int64, body []byte) error {
			var req struct {
				Notes string `json:"notes"`
			}
			json.Unmarshal(body, &req)
			return s.repo.CloseInspectionFinding(user, id, req.Notes)
		},
	))
	s.mux.HandleFunc("DELETE /api/inspection-findings/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteInspectionFinding(user, id)
		},
	))

	// -- Audits --
	s.mux.HandleFunc("POST /api/audits", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.AuditInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateAudit(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/audits/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.AuditInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateAudit(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/audits/{id}/close", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.CloseAudit(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/audits/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteAudit(user, id)
		},
	))

	// -- Audit Findings --
	s.mux.HandleFunc("POST /api/audit-findings", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.AuditFindingInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateAuditFinding(user, in)
		},
	))
	s.mux.HandleFunc("POST /api/audit-findings/{id}/verify", s.handleAction(
		func(user string, id int64, body []byte) error {
			var req struct {
				Notes string `json:"notes"`
			}
			json.Unmarshal(body, &req)
			return s.repo.VerifyAuditFinding(user, id, req.Notes)
		},
	))
	s.mux.HandleFunc("DELETE /api/audit-findings/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteAuditFinding(user, id)
		},
	))

	// -- Permits --
	s.mux.HandleFunc("POST /api/permits", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.PermitInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreatePermit(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/permits/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.PermitInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdatePermit(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/permits/{id}/revoke", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.RevokePermit(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/permits/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeletePermit(user, id)
		},
	))

	// -- Waste Streams --
	// -- Chemical Inventory (sub-record on chemical detail) --
	s.mux.HandleFunc("POST /api/chemical-inventory", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.ChemicalInventoryInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateChemicalInventory(user, in)
		},
	))
	s.mux.HandleFunc("DELETE /api/chemical-inventory/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteChemicalInventory(user, id)
		},
	))

	// -- Storage Locations --
	s.mux.HandleFunc("POST /api/storage-locations", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.StorageLocationInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateStorageLocation(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/storage-locations/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.StorageLocationInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateStorageLocation(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/storage-locations/{id}/deactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.DeactivateStorageLocation(user, id)
		},
	))
	s.mux.HandleFunc("POST /api/storage-locations/{id}/reactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.ReactivateStorageLocation(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/storage-locations/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteStorageLocation(user, id)
		},
	))

	s.mux.HandleFunc("POST /api/waste-streams", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.WasteStreamInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateWasteStream(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/waste-streams/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.WasteStreamInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateWasteStream(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/waste-streams/{id}/deactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.DeactivateWasteStream(user, id)
		},
	))
	s.mux.HandleFunc("POST /api/waste-streams/{id}/reactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.ReactivateWasteStream(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/waste-streams/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteWasteStream(user, id)
		},
	))

	// -- PPE Items --
	s.mux.HandleFunc("POST /api/ppe/items", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.PPEItemInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreatePPEItem(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/ppe/items/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.PPEItemInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdatePPEItem(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/ppe/items/{id}/retire", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.RetirePPEItem(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/ppe/items/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeletePPEItem(user, id)
		},
	))

	// -- PPE Assignments --
	s.mux.HandleFunc("POST /api/ppe/assignments", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.PPEAssignmentInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreatePPEAssignment(user, in)
		},
	))
	s.mux.HandleFunc("POST /api/ppe/assignments/{id}/return", s.handleAction(
		func(user string, id int64, body []byte) error {
			var req struct {
				Condition string `json:"condition"`
				Notes     string `json:"notes"`
			}
			json.Unmarshal(body, &req)
			return s.repo.ReturnPPEAssignment(user, id, req.Condition, req.Notes)
		},
	))
	s.mux.HandleFunc("DELETE /api/ppe/assignments/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeletePPEAssignment(user, id)
		},
	))

	// -- PPE Inspections --
	s.mux.HandleFunc("POST /api/ppe/inspections", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.PPEInspectionInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreatePPEInspection(user, in)
		},
	))
	s.mux.HandleFunc("DELETE /api/ppe/inspections/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeletePPEInspection(user, id)
		},
	))

	// -- Emission Units (Module B: Title V / CAA) --
	s.mux.HandleFunc("POST /api/emission-units", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.EmissionUnitInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateEmissionUnit(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/emission-units/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.EmissionUnitInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateEmissionUnit(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/emission-units/{id}/decommission", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.DecommissionEmissionUnit(user, id)
		},
	))
	s.mux.HandleFunc("POST /api/emission-units/{id}/reactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.ReactivateEmissionUnit(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/emission-units/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteEmissionUnit(user, id)
		},
	))
}

// Handler factories — reduce boilerplate across write endpoints.
// All write endpoints require a valid session token (Bearer auth).

// handleCreate returns a handler that decodes a JSON body, calls the
// create function, and returns the new entity's ID.
func (s *Server) handleCreate(fn func(user string, body []byte) (int64, error)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authedUser := s.requireAuth(w, r)
		if authedUser == nil {
			return
		}
		body, err := readBody(r)
		if err != nil {
			writeError(w, "invalid request body", http.StatusBadRequest)
			return
		}
		id, err := fn(authedUser.Username, body)
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
		authedUser := s.requireAuth(w, r)
		if authedUser == nil {
			return
		}
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
		if err := fn(authedUser.Username, id, body); err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, map[string]string{"status": "ok"})
	}
}

// handleDelete returns a handler that deletes a resource by path ID.
func (s *Server) handleDelete(fn func(user string, id int64) error) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authedUser := s.requireAuth(w, r)
		if authedUser == nil {
			return
		}
		id, err := parseID(r)
		if err != nil {
			writeError(w, "invalid id", http.StatusBadRequest)
			return
		}
		if err := fn(authedUser.Username, id); err != nil {
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
		authedUser := s.requireAuth(w, r)
		if authedUser == nil {
			return
		}
		id, err := parseID(r)
		if err != nil {
			writeError(w, "invalid id", http.StatusBadRequest)
			return
		}
		body, _ := readBody(r) // body is optional for actions
		if err := fn(authedUser.Username, id, body); err != nil {
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
