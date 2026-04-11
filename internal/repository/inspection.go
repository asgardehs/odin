package repository

import "fmt"

const inspectionModule = "inspections"
const inspectionTable = "inspections"
const inspectionFindingModule = "inspection_findings"
const inspectionFindingTable = "inspection_findings"
const auditModule = "audits"
const auditTable = "audits"
const auditFindingModule = "audit_findings"
const auditFindingTable = "audit_findings"

// InspectionInput is the payload for creating or updating an inspection.
type InspectionInput struct {
	EstablishmentID  int64    `json:"establishment_id"`
	InspectionTypeID int64    `json:"inspection_type_id"`
	InspectionNumber *string  `json:"inspection_number,omitempty"`
	ScheduledDate    *string  `json:"scheduled_date,omitempty"`
	InspectionDate   string   `json:"inspection_date"`
	InspectorID      *int64   `json:"inspector_id,omitempty"`
	InspectorName    *string  `json:"inspector_name,omitempty"`
	AreasInspected   *string  `json:"areas_inspected,omitempty"`
	WorkAreaID       *int64   `json:"work_area_id,omitempty"`
	IsStormTriggered *int     `json:"is_storm_triggered,omitempty"`
	StormDate        *string  `json:"storm_date,omitempty"`
	RainfallInches   *float64 `json:"rainfall_inches,omitempty"`
	OverallResult    *string  `json:"overall_result,omitempty"`
	SummaryNotes     *string  `json:"summary_notes,omitempty"`
	WeatherConds     *string  `json:"weather_conditions,omitempty"`
	TemperatureF     *int     `json:"temperature_f,omitempty"`
}

func (r *Repo) CreateInspection(user string, in InspectionInput) (int64, error) {
	return r.insertAndAudit(inspectionTable, inspectionModule, user,
		fmt.Sprintf("Created inspection on %s", in.InspectionDate),
		`INSERT INTO inspections (establishment_id, inspection_type_id, inspection_number,
		        scheduled_date, inspection_date, inspector_id, inspector_name,
		        areas_inspected, work_area_id, is_storm_triggered, storm_date,
		        rainfall_inches, overall_result, summary_notes,
		        weather_conditions, temperature_f)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.InspectionTypeID, in.InspectionNumber,
		in.ScheduledDate, in.InspectionDate, in.InspectorID, in.InspectorName,
		in.AreasInspected, in.WorkAreaID, in.IsStormTriggered, in.StormDate,
		in.RainfallInches, in.OverallResult, in.SummaryNotes,
		in.WeatherConds, in.TemperatureF,
	)
}

func (r *Repo) UpdateInspection(user string, id int64, in InspectionInput) error {
	return r.updateAndAudit(inspectionTable, inspectionModule, id, user,
		fmt.Sprintf("Updated inspection %d", id),
		`UPDATE inspections SET
		        inspection_type_id = ?, inspection_number = ?,
		        scheduled_date = ?, inspection_date = ?, inspector_id = ?, inspector_name = ?,
		        areas_inspected = ?, work_area_id = ?, is_storm_triggered = ?, storm_date = ?,
		        rainfall_inches = ?, overall_result = ?, summary_notes = ?,
		        weather_conditions = ?, temperature_f = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.InspectionTypeID, in.InspectionNumber,
		in.ScheduledDate, in.InspectionDate, in.InspectorID, in.InspectorName,
		in.AreasInspected, in.WorkAreaID, in.IsStormTriggered, in.StormDate,
		in.RainfallInches, in.OverallResult, in.SummaryNotes,
		in.WeatherConds, in.TemperatureF,
		id,
	)
}

// CompleteInspection marks an inspection as completed.
func (r *Repo) CompleteInspection(user string, id int64) error {
	return r.updateAndAudit(inspectionTable, inspectionModule, id, user,
		fmt.Sprintf("Completed inspection %d", id),
		`UPDATE inspections SET status = 'completed', completed_at = datetime('now'),
		        updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeleteInspection(user string, id int64) error {
	return r.deleteAndAudit(inspectionTable, inspectionModule, id, user,
		fmt.Sprintf("Deleted inspection %d", id),
		`DELETE FROM inspections WHERE id = ?`, id,
	)
}

// InspectionFindingInput is the payload for an inspection finding.
type InspectionFindingInput struct {
	InspectionID       int64   `json:"inspection_id"`
	FindingNumber      *string `json:"finding_number,omitempty"`
	FindingType        string  `json:"finding_type"`
	Severity           *string `json:"severity,omitempty"`
	FindingDescription string  `json:"finding_description"`
	Location           *string `json:"location,omitempty"`
	RegulatoryCitation *string `json:"regulatory_citation,omitempty"`
	ImmediateAction    *string `json:"immediate_action,omitempty"`
	ImmediateActionBy  *string `json:"immediate_action_by,omitempty"`
	CorrectiveActionID *int64  `json:"corrective_action_id,omitempty"`
	IncidentID         *int64  `json:"incident_id,omitempty"`
}

func (r *Repo) CreateInspectionFinding(user string, in InspectionFindingInput) (int64, error) {
	return r.insertAndAudit(inspectionFindingTable, inspectionFindingModule, user,
		fmt.Sprintf("Created inspection finding: %s", in.FindingType),
		`INSERT INTO inspection_findings (inspection_id, finding_number, finding_type,
		        severity, finding_description, location, regulatory_citation,
		        immediate_action, immediate_action_by,
		        corrective_action_id, incident_id)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.InspectionID, in.FindingNumber, in.FindingType,
		in.Severity, in.FindingDescription, in.Location, in.RegulatoryCitation,
		in.ImmediateAction, in.ImmediateActionBy,
		in.CorrectiveActionID, in.IncidentID,
	)
}

func (r *Repo) CloseInspectionFinding(user string, id int64, notes string) error {
	return r.updateAndAudit(inspectionFindingTable, inspectionFindingModule, id, user,
		fmt.Sprintf("Closed inspection finding %d", id),
		`UPDATE inspection_findings SET status = 'closed', closed_date = date('now'),
		        closure_notes = ?, updated_at = datetime('now')
		 WHERE id = ?`, notes, id,
	)
}

func (r *Repo) DeleteInspectionFinding(user string, id int64) error {
	return r.deleteAndAudit(inspectionFindingTable, inspectionFindingModule, id, user,
		fmt.Sprintf("Deleted inspection finding %d", id),
		`DELETE FROM inspection_findings WHERE id = ?`, id,
	)
}

// AuditInput is the payload for creating or updating an audit.
type AuditInput struct {
	EstablishmentID    int64   `json:"establishment_id"`
	AuditNumber        *string `json:"audit_number,omitempty"`
	AuditTitle         string  `json:"audit_title"`
	AuditType          string  `json:"audit_type"`
	StandardID         *int64  `json:"standard_id,omitempty"`
	IsIntegratedAudit  *int    `json:"is_integrated_audit,omitempty"`
	RegistrarName      *string `json:"registrar_name,omitempty"`
	ScheduledStartDate *string `json:"scheduled_start_date,omitempty"`
	ScheduledEndDate   *string `json:"scheduled_end_date,omitempty"`
	ActualStartDate    *string `json:"actual_start_date,omitempty"`
	ActualEndDate      *string `json:"actual_end_date,omitempty"`
	LeadAuditorID      *int64  `json:"lead_auditor_id,omitempty"`
	LeadAuditorName    *string `json:"lead_auditor_name,omitempty"`
	ScopeDescription   *string `json:"scope_description,omitempty"`
	AuditObjectives    *string `json:"audit_objectives,omitempty"`
	AuditCriteria      *string `json:"audit_criteria,omitempty"`
}

func (r *Repo) CreateAudit(user string, in AuditInput) (int64, error) {
	return r.insertAndAudit(auditTable, auditModule, user,
		fmt.Sprintf("Created audit: %s", in.AuditTitle),
		`INSERT INTO audits (establishment_id, audit_number, audit_title, audit_type,
		        standard_id, is_integrated_audit, registrar_name,
		        scheduled_start_date, scheduled_end_date,
		        actual_start_date, actual_end_date,
		        lead_auditor_id, lead_auditor_name,
		        scope_description, audit_objectives, audit_criteria)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.AuditNumber, in.AuditTitle, in.AuditType,
		in.StandardID, in.IsIntegratedAudit, in.RegistrarName,
		in.ScheduledStartDate, in.ScheduledEndDate,
		in.ActualStartDate, in.ActualEndDate,
		in.LeadAuditorID, in.LeadAuditorName,
		in.ScopeDescription, in.AuditObjectives, in.AuditCriteria,
	)
}

func (r *Repo) UpdateAudit(user string, id int64, in AuditInput) error {
	return r.updateAndAudit(auditTable, auditModule, id, user,
		fmt.Sprintf("Updated audit: %s", in.AuditTitle),
		`UPDATE audits SET
		        audit_number = ?, audit_title = ?, audit_type = ?,
		        standard_id = ?, is_integrated_audit = ?, registrar_name = ?,
		        scheduled_start_date = ?, scheduled_end_date = ?,
		        actual_start_date = ?, actual_end_date = ?,
		        lead_auditor_id = ?, lead_auditor_name = ?,
		        scope_description = ?, audit_objectives = ?, audit_criteria = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.AuditNumber, in.AuditTitle, in.AuditType,
		in.StandardID, in.IsIntegratedAudit, in.RegistrarName,
		in.ScheduledStartDate, in.ScheduledEndDate,
		in.ActualStartDate, in.ActualEndDate,
		in.LeadAuditorID, in.LeadAuditorName,
		in.ScopeDescription, in.AuditObjectives, in.AuditCriteria,
		id,
	)
}

// CloseAudit finalizes an audit.
func (r *Repo) CloseAudit(user string, id int64) error {
	return r.updateAndAudit(auditTable, auditModule, id, user,
		fmt.Sprintf("Closed audit %d", id),
		`UPDATE audits SET status = 'closed', updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeleteAudit(user string, id int64) error {
	return r.deleteAndAudit(auditTable, auditModule, id, user,
		fmt.Sprintf("Deleted audit %d", id),
		`DELETE FROM audits WHERE id = ?`, id,
	)
}

// AuditFindingInput is the payload for an audit finding.
type AuditFindingInput struct {
	AuditID              int64   `json:"audit_id"`
	FindingNumber        string  `json:"finding_number"`
	FindingType          string  `json:"finding_type"`
	ClauseNumber         *string `json:"clause_number,omitempty"`
	ClauseTitle          *string `json:"clause_title,omitempty"`
	RequirementStatement *string `json:"requirement_statement,omitempty"`
	FindingStatement     string  `json:"finding_statement"`
	ProcessArea          *string `json:"process_area,omitempty"`
	EvidenceDescription  *string `json:"evidence_description,omitempty"`
	IsRepeatFinding      *int    `json:"is_repeat_finding,omitempty"`
	RiskLevel            *string `json:"risk_level,omitempty"`
	CorrectiveActionID   *int64  `json:"corrective_action_id,omitempty"`
}

func (r *Repo) CreateAuditFinding(user string, in AuditFindingInput) (int64, error) {
	return r.insertAndAudit(auditFindingTable, auditFindingModule, user,
		fmt.Sprintf("Created audit finding %s: %s", in.FindingNumber, in.FindingType),
		`INSERT INTO audit_findings (audit_id, finding_number, finding_type,
		        clause_number, clause_title, requirement_statement, finding_statement,
		        process_area, evidence_description,
		        is_repeat_finding, risk_level, corrective_action_id)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.AuditID, in.FindingNumber, in.FindingType,
		in.ClauseNumber, in.ClauseTitle, in.RequirementStatement, in.FindingStatement,
		in.ProcessArea, in.EvidenceDescription,
		in.IsRepeatFinding, in.RiskLevel, in.CorrectiveActionID,
	)
}

func (r *Repo) VerifyAuditFinding(user string, id int64, notes string) error {
	return r.updateAndAudit(auditFindingTable, auditFindingModule, id, user,
		fmt.Sprintf("Verified audit finding %d", id),
		`UPDATE audit_findings SET status = 'verified', verified_date = date('now'),
		        verification_notes = ?, updated_at = datetime('now')
		 WHERE id = ?`, notes, id,
	)
}

func (r *Repo) DeleteAuditFinding(user string, id int64) error {
	return r.deleteAndAudit(auditFindingTable, auditFindingModule, id, user,
		fmt.Sprintf("Deleted audit finding %d", id),
		`DELETE FROM audit_findings WHERE id = ?`, id,
	)
}
