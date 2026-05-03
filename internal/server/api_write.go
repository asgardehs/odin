package server

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"

	"github.com/asgardehs/odin/internal/repository"
)

// MaxRequestBody caps the bytes accepted from a single request body.
// Anything larger surfaces as *http.MaxBytesError, which writeBodyError
// maps to 413 Payload Too Large.
const MaxRequestBody = 1 << 20 // 1 MiB

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

	// -- Module D: Clean Water — Discharge Points --
	s.mux.HandleFunc("POST /api/discharge-points", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.DischargePointInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateDischargePoint(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/discharge-points/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.DischargePointInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateDischargePoint(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/discharge-points/{id}/decommission", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.DecommissionDischargePoint(user, id)
		},
	))
	s.mux.HandleFunc("POST /api/discharge-points/{id}/reactivate", s.handleAction(
		func(user string, id int64, _ []byte) error {
			return s.repo.ReactivateDischargePoint(user, id)
		},
	))
	s.mux.HandleFunc("DELETE /api/discharge-points/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteDischargePoint(user, id)
		},
	))

	// -- Module D: Clean Water — Water Sample Events --
	s.mux.HandleFunc("POST /api/ww-sample-events", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.WaterSampleEventInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateWaterSampleEvent(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/ww-sample-events/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.WaterSampleEventInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateWaterSampleEvent(user, id, in)
		},
	))
	s.mux.HandleFunc("POST /api/ww-sample-events/{id}/finalize", s.handleAction(
		func(user string, id int64, body []byte) error {
			// Optional body: {"finalized_by_employee_id": N}. Empty body OK.
			var payload struct {
				FinalizedByEmployeeID *int64 `json:"finalized_by_employee_id,omitempty"`
			}
			if len(body) > 0 {
				if err := json.Unmarshal(body, &payload); err != nil {
					return err
				}
			}
			return s.repo.FinalizeWaterSampleEvent(user, id, payload.FinalizedByEmployeeID)
		},
	))
	s.mux.HandleFunc("DELETE /api/ww-sample-events/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteWaterSampleEvent(user, id)
		},
	))

	// -- Module D: Clean Water — Water Sample Results --
	// Per plan: create + delete only; results are accessed via the parent event.
	s.mux.HandleFunc("POST /api/ww-sample-results", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.WaterSampleResultInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateWaterSampleResult(user, in)
		},
	))
	s.mux.HandleFunc("DELETE /api/ww-sample-results/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteWaterSampleResult(user, id)
		},
	))

	// -- Module D: Clean Water — SWPPPs --
	s.mux.HandleFunc("POST /api/swpps", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.SWPPPInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateSWPPP(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/swpps/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.SWPPPInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateSWPPP(user, id, in)
		},
	))
	s.mux.HandleFunc("DELETE /api/swpps/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteSWPPP(user, id)
		},
	))

	// -- Module D: Clean Water — BMPs --
	s.mux.HandleFunc("POST /api/bmps", s.handleCreate(
		func(user string, body []byte) (int64, error) {
			var in repository.BMPInput
			if err := json.Unmarshal(body, &in); err != nil {
				return 0, err
			}
			return s.repo.CreateBMP(user, in)
		},
	))
	s.mux.HandleFunc("PUT /api/bmps/{id}", s.handleUpdate(
		func(user string, id int64, body []byte) error {
			var in repository.BMPInput
			if err := json.Unmarshal(body, &in); err != nil {
				return err
			}
			return s.repo.UpdateBMP(user, id, in)
		},
	))
	s.mux.HandleFunc("DELETE /api/bmps/{id}", s.handleDelete(
		func(user string, id int64) error {
			return s.repo.DeleteBMP(user, id)
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
		body, err := readBody(w, r)
		if err != nil {
			writeBodyError(w, err)
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
		body, err := readBody(w, r)
		if err != nil {
			writeBodyError(w, err)
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
		// Body is optional for actions; oversized bodies still rejected
		// (a client should not be able to send 100 MB to /close).
		body, err := readBody(w, r)
		if err != nil {
			var maxErr *http.MaxBytesError
			if errors.As(err, &maxErr) {
				writeBodyError(w, err)
				return
			}
			body = nil // other read errors → treat as no body, per "optional"
		}
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

// readBody reads the request body, enforcing MaxRequestBody. Bodies that
// exceed the cap surface as *http.MaxBytesError; other read errors are
// returned as-is. Callers should route the error through writeBodyError
// so oversized bodies become 413 instead of a misleading 400.
//
// The ResponseWriter is needed so http.MaxBytesReader can signal a
// connection close on overflow — passing nil disables that signal.
func readBody(w http.ResponseWriter, r *http.Request) ([]byte, error) {
	defer r.Body.Close()
	return io.ReadAll(http.MaxBytesReader(w, r.Body, MaxRequestBody))
}

// writeBodyError maps a readBody error to the right HTTP status:
// *http.MaxBytesError → 413 (so the client knows to retry smaller),
// anything else → 400.
func writeBodyError(w http.ResponseWriter, err error) {
	var maxErr *http.MaxBytesError
	if errors.As(err, &maxErr) {
		writeError(w, "request body exceeds limit", http.StatusRequestEntityTooLarge)
		return
	}
	writeError(w, "invalid request body", http.StatusBadRequest)
}
