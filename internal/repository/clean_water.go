package repository

import "fmt"

// ============================================================================
// Module D — Clean Water Act repository layer.
//
// Five entity types, all living in module_d_clean_water.sql:
//   - Discharge points (ehs:DischargePoint)
//   - Water sample events (ehs:MonitoringLocation sampling runs)
//   - Water sample results (one row per parameter per event)
//   - SWPPPs (ehs:SWPPP documents)
//   - BMPs (ehs:BestManagementPractice catalog under a SWPPP)
//
// NPDES permits themselves reuse permit.go via the generic permits table —
// there is no NPDESPermitInput here by design. See
// docs/plans/2026-04-20-module-d-csv-import-pdf-forms.md Phase 1 for why.
// ============================================================================

// ---- Discharge points ------------------------------------------------------

const dischargePointModule = "discharge_points"
const dischargePointTable = "discharge_points"

type DischargePointInput struct {
	EstablishmentID                  int64    `json:"establishment_id"`
	OutfallCode                      string   `json:"outfall_code"`
	OutfallName                      *string  `json:"outfall_name,omitempty"`
	Description                      *string  `json:"description,omitempty"`
	DischargeType                    string   `json:"discharge_type"`
	ReceivingWaterbody               *string  `json:"receiving_waterbody,omitempty"`
	ReceivingWaterbodyType           *string  `json:"receiving_waterbody_type,omitempty"`
	ReceivingWaterbodyClassification *string  `json:"receiving_waterbody_classification,omitempty"`
	IsImpairedWater                  *int     `json:"is_impaired_water,omitempty"`
	TmdlApplies                      *int     `json:"tmdl_applies,omitempty"`
	TmdlParameters                   *string  `json:"tmdl_parameters,omitempty"`
	Latitude                         *float64 `json:"latitude,omitempty"`
	Longitude                        *float64 `json:"longitude,omitempty"`
	PermitID                         *int64   `json:"permit_id,omitempty"`
	StormwaterSectorCode             *string  `json:"stormwater_sector_code,omitempty"`
	SwpppID                          *int64   `json:"swppp_id,omitempty"`
	EmissionUnitID                   *int64   `json:"emission_unit_id,omitempty"`
	PipeDiameterInches               *float64 `json:"pipe_diameter_inches,omitempty"`
	TypicalFlowMgd                   *float64 `json:"typical_flow_mgd,omitempty"`
	InstallationDate                 *string  `json:"installation_date,omitempty"`
	DecommissionDate                 *string  `json:"decommission_date,omitempty"`
	Notes                            *string  `json:"notes,omitempty"`
}

func (r *Repo) CreateDischargePoint(user string, in DischargePointInput) (int64, error) {
	return r.insertAndAudit(dischargePointTable, dischargePointModule, user,
		fmt.Sprintf("Created discharge point: %s", in.OutfallCode),
		`INSERT INTO discharge_points (
		        establishment_id, outfall_code, outfall_name, description,
		        discharge_type,
		        receiving_waterbody, receiving_waterbody_type,
		        receiving_waterbody_classification,
		        is_impaired_water, tmdl_applies, tmdl_parameters,
		        latitude, longitude,
		        permit_id, stormwater_sector_code, swppp_id, emission_unit_id,
		        pipe_diameter_inches, typical_flow_mgd,
		        installation_date, decommission_date, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.OutfallCode, in.OutfallName, in.Description,
		in.DischargeType,
		in.ReceivingWaterbody, in.ReceivingWaterbodyType,
		in.ReceivingWaterbodyClassification,
		in.IsImpairedWater, in.TmdlApplies, in.TmdlParameters,
		in.Latitude, in.Longitude,
		in.PermitID, in.StormwaterSectorCode, in.SwpppID, in.EmissionUnitID,
		in.PipeDiameterInches, in.TypicalFlowMgd,
		in.InstallationDate, in.DecommissionDate, in.Notes,
	)
}

func (r *Repo) UpdateDischargePoint(user string, id int64, in DischargePointInput) error {
	return r.updateAndAudit(dischargePointTable, dischargePointModule, id, user,
		fmt.Sprintf("Updated discharge point: %s", in.OutfallCode),
		`UPDATE discharge_points SET
		        outfall_code = ?, outfall_name = ?, description = ?,
		        discharge_type = ?,
		        receiving_waterbody = ?, receiving_waterbody_type = ?,
		        receiving_waterbody_classification = ?,
		        is_impaired_water = ?, tmdl_applies = ?, tmdl_parameters = ?,
		        latitude = ?, longitude = ?,
		        permit_id = ?, stormwater_sector_code = ?, swppp_id = ?, emission_unit_id = ?,
		        pipe_diameter_inches = ?, typical_flow_mgd = ?,
		        installation_date = ?, decommission_date = ?, notes = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.OutfallCode, in.OutfallName, in.Description,
		in.DischargeType,
		in.ReceivingWaterbody, in.ReceivingWaterbodyType,
		in.ReceivingWaterbodyClassification,
		in.IsImpairedWater, in.TmdlApplies, in.TmdlParameters,
		in.Latitude, in.Longitude,
		in.PermitID, in.StormwaterSectorCode, in.SwpppID, in.EmissionUnitID,
		in.PipeDiameterInches, in.TypicalFlowMgd,
		in.InstallationDate, in.DecommissionDate, in.Notes,
		id,
	)
}

func (r *Repo) DecommissionDischargePoint(user string, id int64) error {
	return r.updateAndAudit(dischargePointTable, dischargePointModule, id, user,
		fmt.Sprintf("Decommissioned discharge point %d", id),
		`UPDATE discharge_points
		    SET status = 'decommissioned',
		        decommission_date = COALESCE(decommission_date, date('now')),
		        updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) ReactivateDischargePoint(user string, id int64) error {
	return r.updateAndAudit(dischargePointTable, dischargePointModule, id, user,
		fmt.Sprintf("Reactivated discharge point %d", id),
		`UPDATE discharge_points
		    SET status = 'active',
		        decommission_date = NULL,
		        updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeleteDischargePoint(user string, id int64) error {
	return r.deleteAndAudit(dischargePointTable, dischargePointModule, id, user,
		fmt.Sprintf("Deleted discharge point %d", id),
		`DELETE FROM discharge_points WHERE id = ?`, id,
	)
}

// ---- Water sample events ---------------------------------------------------

const waterSampleEventModule = "water_sample_events"
const waterSampleEventTable = "ww_sampling_events"

type WaterSampleEventInput struct {
	EstablishmentID        int64    `json:"establishment_id"`
	LocationID             int64    `json:"location_id"`
	EventNumber            *string  `json:"event_number,omitempty"`
	SampleDate             string   `json:"sample_date"`
	SampleTime             *string  `json:"sample_time,omitempty"`
	SampledByEmployeeID    *int64   `json:"sampled_by_employee_id,omitempty"`
	SampleType             *string  `json:"sample_type,omitempty"`
	CompositePeriodHours   *float64 `json:"composite_period_hours,omitempty"`
	WeatherConditions      *string  `json:"weather_conditions,omitempty"`
	EquipmentID            *int64   `json:"equipment_id,omitempty"`
	LabSubmissionID        *int64   `json:"lab_submission_id,omitempty"`
	PhotoPaths             *string  `json:"photo_paths,omitempty"`
	Notes                  *string  `json:"notes,omitempty"`
}

func (r *Repo) CreateWaterSampleEvent(user string, in WaterSampleEventInput) (int64, error) {
	label := in.SampleDate
	if in.EventNumber != nil {
		label = *in.EventNumber
	}
	return r.insertAndAudit(waterSampleEventTable, waterSampleEventModule, user,
		fmt.Sprintf("Created water sample event: %s", label),
		`INSERT INTO ww_sampling_events (
		        establishment_id, location_id, event_number,
		        sample_date, sample_time, sampled_by_employee_id,
		        sample_type, composite_period_hours, weather_conditions,
		        equipment_id, lab_submission_id, photo_paths, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.LocationID, in.EventNumber,
		in.SampleDate, in.SampleTime, in.SampledByEmployeeID,
		in.SampleType, in.CompositePeriodHours, in.WeatherConditions,
		in.EquipmentID, in.LabSubmissionID, in.PhotoPaths, in.Notes,
	)
}

func (r *Repo) UpdateWaterSampleEvent(user string, id int64, in WaterSampleEventInput) error {
	label := in.SampleDate
	if in.EventNumber != nil {
		label = *in.EventNumber
	}
	return r.updateAndAudit(waterSampleEventTable, waterSampleEventModule, id, user,
		fmt.Sprintf("Updated water sample event: %s", label),
		`UPDATE ww_sampling_events SET
		        location_id = ?, event_number = ?,
		        sample_date = ?, sample_time = ?, sampled_by_employee_id = ?,
		        sample_type = ?, composite_period_hours = ?, weather_conditions = ?,
		        equipment_id = ?, lab_submission_id = ?, photo_paths = ?, notes = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.LocationID, in.EventNumber,
		in.SampleDate, in.SampleTime, in.SampledByEmployeeID,
		in.SampleType, in.CompositePeriodHours, in.WeatherConditions,
		in.EquipmentID, in.LabSubmissionID, in.PhotoPaths, in.Notes,
		id,
	)
}

// FinalizeWaterSampleEvent marks an event DMR-ready and stamps the
// finalizing user as the finalized-by-employee (using a nil employee ID if
// no mapping exists — the audit trail still captures the text user).
func (r *Repo) FinalizeWaterSampleEvent(user string, id int64, finalizedByEmployeeID *int64) error {
	return r.updateAndAudit(waterSampleEventTable, waterSampleEventModule, id, user,
		fmt.Sprintf("Finalized water sample event %d", id),
		`UPDATE ww_sampling_events
		    SET status = 'finalized',
		        finalized_date = COALESCE(finalized_date, date('now')),
		        finalized_by_employee_id = COALESCE(?, finalized_by_employee_id),
		        updated_at = datetime('now')
		 WHERE id = ?`,
		finalizedByEmployeeID, id,
	)
}

func (r *Repo) DeleteWaterSampleEvent(user string, id int64) error {
	return r.deleteAndAudit(waterSampleEventTable, waterSampleEventModule, id, user,
		fmt.Sprintf("Deleted water sample event %d", id),
		`DELETE FROM ww_sampling_events WHERE id = ?`, id,
	)
}

// ---- Water sample results --------------------------------------------------

const waterSampleResultModule = "water_sample_results"
const waterSampleResultTable = "ww_sample_results"

type WaterSampleResultInput struct {
	EventID             int64    `json:"event_id"`
	ParameterID         int64    `json:"parameter_id"`
	ResultValue         *float64 `json:"result_value,omitempty"`
	ResultUnits         string   `json:"result_units"`
	ResultQualifier     *string  `json:"result_qualifier,omitempty"`
	DetectionLimit      *float64 `json:"detection_limit,omitempty"`
	ReportingLimit      *float64 `json:"reporting_limit,omitempty"`
	AnalyzedDate        *string  `json:"analyzed_date,omitempty"`
	AnalyzedBy          *string  `json:"analyzed_by,omitempty"`
	AnalysisMethod      *string  `json:"analysis_method,omitempty"`
	IsDuplicate         *int     `json:"is_duplicate,omitempty"`
	DuplicateOfResultID *int64   `json:"duplicate_of_result_id,omitempty"`
	IsBlank             *int     `json:"is_blank,omitempty"`
	Notes               *string  `json:"notes,omitempty"`
}

func (r *Repo) CreateWaterSampleResult(user string, in WaterSampleResultInput) (int64, error) {
	return r.insertAndAudit(waterSampleResultTable, waterSampleResultModule, user,
		fmt.Sprintf("Added water sample result (event %d, parameter %d)", in.EventID, in.ParameterID),
		`INSERT INTO ww_sample_results (
		        event_id, parameter_id,
		        result_value, result_units, result_qualifier,
		        detection_limit, reporting_limit,
		        analyzed_date, analyzed_by, analysis_method,
		        is_duplicate, duplicate_of_result_id, is_blank, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EventID, in.ParameterID,
		in.ResultValue, in.ResultUnits, in.ResultQualifier,
		in.DetectionLimit, in.ReportingLimit,
		in.AnalyzedDate, in.AnalyzedBy, in.AnalysisMethod,
		in.IsDuplicate, in.DuplicateOfResultID, in.IsBlank, in.Notes,
	)
}

func (r *Repo) DeleteWaterSampleResult(user string, id int64) error {
	return r.deleteAndAudit(waterSampleResultTable, waterSampleResultModule, id, user,
		fmt.Sprintf("Deleted water sample result %d", id),
		`DELETE FROM ww_sample_results WHERE id = ?`, id,
	)
}

// ---- SWPPPs ----------------------------------------------------------------

const swpppModule = "swpps"
const swpppTable = "sw_swpps"

type SWPPPInput struct {
	EstablishmentID                         int64   `json:"establishment_id"`
	RevisionNumber                          string  `json:"revision_number"`
	EffectiveDate                           string  `json:"effective_date"`
	SupersedesSwpppID                       *int64  `json:"supersedes_swppp_id,omitempty"`
	LastAnnualReviewDate                    *string `json:"last_annual_review_date,omitempty"`
	NextAnnualReviewDue                     *string `json:"next_annual_review_due,omitempty"`
	PollutionPreventionTeamLeadEmployeeID   *int64  `json:"pollution_prevention_team_lead_employee_id,omitempty"`
	PollutionPreventionTeam                 *string `json:"pollution_prevention_team,omitempty"`
	DocumentPath                            *string `json:"document_path,omitempty"`
	PermitID                                *int64  `json:"permit_id,omitempty"`
	SiteDescriptionSummary                  *string `json:"site_description_summary,omitempty"`
	IndustrialActivitiesSummary             *string `json:"industrial_activities_summary,omitempty"`
	Notes                                   *string `json:"notes,omitempty"`
}

func (r *Repo) CreateSWPPP(user string, in SWPPPInput) (int64, error) {
	return r.insertAndAudit(swpppTable, swpppModule, user,
		fmt.Sprintf("Created SWPPP %s for establishment %d", in.RevisionNumber, in.EstablishmentID),
		`INSERT INTO sw_swpps (
		        establishment_id, revision_number, effective_date,
		        supersedes_swppp_id,
		        last_annual_review_date, next_annual_review_due,
		        pollution_prevention_team_lead_employee_id,
		        pollution_prevention_team, document_path,
		        permit_id,
		        site_description_summary, industrial_activities_summary,
		        notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.RevisionNumber, in.EffectiveDate,
		in.SupersedesSwpppID,
		in.LastAnnualReviewDate, in.NextAnnualReviewDue,
		in.PollutionPreventionTeamLeadEmployeeID,
		in.PollutionPreventionTeam, in.DocumentPath,
		in.PermitID,
		in.SiteDescriptionSummary, in.IndustrialActivitiesSummary,
		in.Notes,
	)
}

func (r *Repo) UpdateSWPPP(user string, id int64, in SWPPPInput) error {
	return r.updateAndAudit(swpppTable, swpppModule, id, user,
		fmt.Sprintf("Updated SWPPP %s", in.RevisionNumber),
		`UPDATE sw_swpps SET
		        revision_number = ?, effective_date = ?,
		        supersedes_swppp_id = ?,
		        last_annual_review_date = ?, next_annual_review_due = ?,
		        pollution_prevention_team_lead_employee_id = ?,
		        pollution_prevention_team = ?, document_path = ?,
		        permit_id = ?,
		        site_description_summary = ?, industrial_activities_summary = ?,
		        notes = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.RevisionNumber, in.EffectiveDate,
		in.SupersedesSwpppID,
		in.LastAnnualReviewDate, in.NextAnnualReviewDue,
		in.PollutionPreventionTeamLeadEmployeeID,
		in.PollutionPreventionTeam, in.DocumentPath,
		in.PermitID,
		in.SiteDescriptionSummary, in.IndustrialActivitiesSummary,
		in.Notes,
		id,
	)
}

func (r *Repo) DeleteSWPPP(user string, id int64) error {
	return r.deleteAndAudit(swpppTable, swpppModule, id, user,
		fmt.Sprintf("Deleted SWPPP %d", id),
		`DELETE FROM sw_swpps WHERE id = ?`, id,
	)
}

// ---- BMPs ------------------------------------------------------------------

const bmpModule = "bmps"
const bmpTable = "sw_bmps"

type BMPInput struct {
	SwpppID                    int64   `json:"swppp_id"`
	EstablishmentID            int64   `json:"establishment_id"`
	BmpCode                    string  `json:"bmp_code"`
	BmpName                    string  `json:"bmp_name"`
	BmpType                    string  `json:"bmp_type"`
	BmpSubtype                 *string `json:"bmp_subtype,omitempty"`
	Description                string  `json:"description"`
	ImplementationDate         *string `json:"implementation_date,omitempty"`
	ImplementationDetails      *string `json:"implementation_details,omitempty"`
	InspectionFrequency        *string `json:"inspection_frequency,omitempty"`
	InspectionFrequencyDays    *int64  `json:"inspection_frequency_days,omitempty"`
	ResponsibleRole            *string `json:"responsible_role,omitempty"`
	ResponsibleEmployeeID      *int64  `json:"responsible_employee_id,omitempty"`
	LastInspectionDate         *string `json:"last_inspection_date,omitempty"`
	NextInspectionDue          *string `json:"next_inspection_due,omitempty"`
	LastEffectivenessReviewDate *string `json:"last_effectiveness_review_date,omitempty"`
	RetirementDate             *string `json:"retirement_date,omitempty"`
	RetirementReason           *string `json:"retirement_reason,omitempty"`
	ReplacedByBmpID            *int64  `json:"replaced_by_bmp_id,omitempty"`
	Notes                      *string `json:"notes,omitempty"`
}

func (r *Repo) CreateBMP(user string, in BMPInput) (int64, error) {
	return r.insertAndAudit(bmpTable, bmpModule, user,
		fmt.Sprintf("Created BMP: %s", in.BmpCode),
		`INSERT INTO sw_bmps (
		        swppp_id, establishment_id,
		        bmp_code, bmp_name, bmp_type, bmp_subtype, description,
		        implementation_date, implementation_details,
		        inspection_frequency, inspection_frequency_days,
		        responsible_role, responsible_employee_id,
		        last_inspection_date, next_inspection_due,
		        last_effectiveness_review_date,
		        retirement_date, retirement_reason, replaced_by_bmp_id,
		        notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.SwpppID, in.EstablishmentID,
		in.BmpCode, in.BmpName, in.BmpType, in.BmpSubtype, in.Description,
		in.ImplementationDate, in.ImplementationDetails,
		in.InspectionFrequency, in.InspectionFrequencyDays,
		in.ResponsibleRole, in.ResponsibleEmployeeID,
		in.LastInspectionDate, in.NextInspectionDue,
		in.LastEffectivenessReviewDate,
		in.RetirementDate, in.RetirementReason, in.ReplacedByBmpID,
		in.Notes,
	)
}

func (r *Repo) UpdateBMP(user string, id int64, in BMPInput) error {
	return r.updateAndAudit(bmpTable, bmpModule, id, user,
		fmt.Sprintf("Updated BMP: %s", in.BmpCode),
		`UPDATE sw_bmps SET
		        swppp_id = ?,
		        bmp_code = ?, bmp_name = ?, bmp_type = ?, bmp_subtype = ?, description = ?,
		        implementation_date = ?, implementation_details = ?,
		        inspection_frequency = ?, inspection_frequency_days = ?,
		        responsible_role = ?, responsible_employee_id = ?,
		        last_inspection_date = ?, next_inspection_due = ?,
		        last_effectiveness_review_date = ?,
		        retirement_date = ?, retirement_reason = ?, replaced_by_bmp_id = ?,
		        notes = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.SwpppID,
		in.BmpCode, in.BmpName, in.BmpType, in.BmpSubtype, in.Description,
		in.ImplementationDate, in.ImplementationDetails,
		in.InspectionFrequency, in.InspectionFrequencyDays,
		in.ResponsibleRole, in.ResponsibleEmployeeID,
		in.LastInspectionDate, in.NextInspectionDue,
		in.LastEffectivenessReviewDate,
		in.RetirementDate, in.RetirementReason, in.ReplacedByBmpID,
		in.Notes,
		id,
	)
}

func (r *Repo) DeleteBMP(user string, id int64) error {
	return r.deleteAndAudit(bmpTable, bmpModule, id, user,
		fmt.Sprintf("Deleted BMP %d", id),
		`DELETE FROM sw_bmps WHERE id = ?`, id,
	)
}
