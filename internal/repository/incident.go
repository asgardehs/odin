package repository

import "fmt"

const incidentModule = "incidents"
const incidentTable = "incidents"
const correctiveActionModule = "corrective_actions"
const correctiveActionTable = "corrective_actions"

// IncidentInput is the payload for creating or updating an incident.
type IncidentInput struct {
	EstablishmentID         int64   `json:"establishment_id"`
	EmployeeID              *int64  `json:"employee_id,omitempty"`
	CaseNumber              *string `json:"case_number,omitempty"`
	IncidentDate            string  `json:"incident_date"`
	IncidentTime            *string `json:"incident_time,omitempty"`
	TimeEmployeeBeganWork   *string `json:"time_employee_began_work,omitempty"`
	LocationDescription     *string `json:"location_description,omitempty"`
	ActivityDescription     *string `json:"activity_description,omitempty"`
	IncidentDescription     string  `json:"incident_description"`
	ObjectOrSubstance       *string `json:"object_or_substance,omitempty"`
	CaseClassificationCode  *string `json:"case_classification_code,omitempty"`
	BodyPartCode            *string `json:"body_part_code,omitempty"`
	SeverityCode            string  `json:"severity_code"`
	TreatmentProvided       *string `json:"treatment_provided,omitempty"`
	TreatingPhysician       *string `json:"treating_physician,omitempty"`
	TreatmentFacility       *string `json:"treatment_facility,omitempty"`
	WasHospitalized         *int    `json:"was_hospitalized,omitempty"`
	WasERVisit              *int    `json:"was_er_visit,omitempty"`
	ReportedBy              *string `json:"reported_by,omitempty"`
	ReportedDate            *string `json:"reported_date,omitempty"`
}

func (r *Repo) CreateIncident(user string, in IncidentInput) (int64, error) {
	return r.insertAndAudit(incidentTable, incidentModule, user,
		fmt.Sprintf("Created incident on %s: %s", in.IncidentDate, in.IncidentDescription),
		`INSERT INTO incidents (establishment_id, employee_id, case_number,
		        incident_date, incident_time, time_employee_began_work,
		        location_description, activity_description, incident_description,
		        object_or_substance, case_classification_code, body_part_code,
		        severity_code, treatment_provided, treating_physician,
		        treatment_facility, was_hospitalized, was_er_visit,
		        reported_by, reported_date)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.EmployeeID, in.CaseNumber,
		in.IncidentDate, in.IncidentTime, in.TimeEmployeeBeganWork,
		in.LocationDescription, in.ActivityDescription, in.IncidentDescription,
		in.ObjectOrSubstance, in.CaseClassificationCode, in.BodyPartCode,
		in.SeverityCode, in.TreatmentProvided, in.TreatingPhysician,
		in.TreatmentFacility, in.WasHospitalized, in.WasERVisit,
		in.ReportedBy, in.ReportedDate,
	)
}

func (r *Repo) UpdateIncident(user string, id int64, in IncidentInput) error {
	return r.updateAndAudit(incidentTable, incidentModule, id, user,
		fmt.Sprintf("Updated incident %d", id),
		`UPDATE incidents SET
		        establishment_id = ?, employee_id = ?, case_number = ?,
		        incident_date = ?, incident_time = ?, time_employee_began_work = ?,
		        location_description = ?, activity_description = ?, incident_description = ?,
		        object_or_substance = ?, case_classification_code = ?, body_part_code = ?,
		        severity_code = ?, treatment_provided = ?, treating_physician = ?,
		        treatment_facility = ?, was_hospitalized = ?, was_er_visit = ?,
		        reported_by = ?, reported_date = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.EstablishmentID, in.EmployeeID, in.CaseNumber,
		in.IncidentDate, in.IncidentTime, in.TimeEmployeeBeganWork,
		in.LocationDescription, in.ActivityDescription, in.IncidentDescription,
		in.ObjectOrSubstance, in.CaseClassificationCode, in.BodyPartCode,
		in.SeverityCode, in.TreatmentProvided, in.TreatingPhysician,
		in.TreatmentFacility, in.WasHospitalized, in.WasERVisit,
		in.ReportedBy, in.ReportedDate,
		id,
	)
}

// CloseIncident transitions an incident to closed status.
func (r *Repo) CloseIncident(user string, id int64) error {
	return r.updateAndAudit(incidentTable, incidentModule, id, user,
		fmt.Sprintf("Closed incident %d", id),
		`UPDATE incidents SET status = 'closed', closed_date = date('now'), closed_by = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`, user, id,
	)
}

func (r *Repo) DeleteIncident(user string, id int64) error {
	return r.deleteAndAudit(incidentTable, incidentModule, id, user,
		fmt.Sprintf("Deleted incident %d", id),
		`DELETE FROM incidents WHERE id = ?`, id,
	)
}

// CorrectiveActionInput is the payload for creating or updating a corrective action.
type CorrectiveActionInput struct {
	InvestigationID        int64   `json:"investigation_id"`
	Description            string  `json:"description"`
	HierarchyLevel         string  `json:"hierarchy_level"`
	HierarchyJustification *string `json:"hierarchy_justification,omitempty"`
	AssignedTo             *string `json:"assigned_to,omitempty"`
	DueDate                *string `json:"due_date,omitempty"`
}

func (r *Repo) CreateCorrectiveAction(user string, in CorrectiveActionInput) (int64, error) {
	return r.insertAndAudit(correctiveActionTable, correctiveActionModule, user,
		fmt.Sprintf("Created corrective action: %s (%s)", in.Description, in.HierarchyLevel),
		`INSERT INTO corrective_actions (investigation_id, description,
		        hierarchy_level, hierarchy_justification, assigned_to, due_date)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		in.InvestigationID, in.Description,
		in.HierarchyLevel, in.HierarchyJustification, in.AssignedTo, in.DueDate,
	)
}

func (r *Repo) UpdateCorrectiveAction(user string, id int64, in CorrectiveActionInput) error {
	return r.updateAndAudit(correctiveActionTable, correctiveActionModule, id, user,
		fmt.Sprintf("Updated corrective action %d", id),
		`UPDATE corrective_actions SET
		        description = ?, hierarchy_level = ?, hierarchy_justification = ?,
		        assigned_to = ?, due_date = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.Description, in.HierarchyLevel, in.HierarchyJustification,
		in.AssignedTo, in.DueDate,
		id,
	)
}

// CompleteCorrectiveAction marks a corrective action as completed.
func (r *Repo) CompleteCorrectiveAction(user string, id int64) error {
	return r.updateAndAudit(correctiveActionTable, correctiveActionModule, id, user,
		fmt.Sprintf("Completed corrective action %d", id),
		`UPDATE corrective_actions SET status = 'completed',
		        completed_date = date('now'), completed_by = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`, user, id,
	)
}

// VerifyCorrectiveAction marks a corrective action as verified effective.
func (r *Repo) VerifyCorrectiveAction(user string, id int64, notes string) error {
	return r.updateAndAudit(correctiveActionTable, correctiveActionModule, id, user,
		fmt.Sprintf("Verified corrective action %d", id),
		`UPDATE corrective_actions SET status = 'verified',
		        verified_date = date('now'), verified_by = ?, verification_notes = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`, user, notes, id,
	)
}

func (r *Repo) DeleteCorrectiveAction(user string, id int64) error {
	return r.deleteAndAudit(correctiveActionTable, correctiveActionModule, id, user,
		fmt.Sprintf("Deleted corrective action %d", id),
		`DELETE FROM corrective_actions WHERE id = ?`, id,
	)
}
