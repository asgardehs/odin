package importer

import (
	"fmt"
	"regexp"
	"strings"
)

// osha_ita_detail is the importer for the OSHA ITA detail CSV shape
// (the 24-column per-incident export). Round-trips the output of
// /api/osha/ita/detail.csv back into odin as incident rows.
//
// Design calls:
//   - Upsert incidents by (establishment_id, case_number). Re-importing
//     the same CSV is a safe no-op data-wise (existing rows updated).
//   - Non-recordable severities are not in the ITA spec, so every row
//     imported here carries a recordable severity_code (reverse-mapped
//     from the incident_outcome human text).
//   - Employee matching is NOT attempted — ITA CSVs deliberately omit
//     employee_number and personally-identifying names. Demographic
//     columns (date_of_birth, date_of_hire, sex, job_title) are dropped
//     on import. Imported incidents have employee_id = NULL; the user
//     links employees manually via the incident edit form after import.
//   - establishment_name in the CSV is informational only; the actual
//     target establishment comes from RowContext.EstablishmentID
//     (picked by the user on the import page).
type oshaITADetailImporter struct{}

func init() {
	Register(&oshaITADetailImporter{})
}

func (*oshaITADetailImporter) ModuleSlug() string { return "osha_ita_detail" }

func (*oshaITADetailImporter) TargetFields() []TargetField {
	// The ITA CSV column set is fixed and authoritative. All 24 columns
	// are declared here so the fuzzy matcher correctly claims each
	// header. Four columns carry employee demographics with nowhere to
	// land in odin's schema without an employee match (which the CSV
	// doesn't support) — they're declared so the matcher doesn't
	// misassign them to semantically-adjacent fields like date_of_death,
	// but their values are discarded in ValidateRow.
	return []TargetField{
		{Name: "case_number", Label: "Case Number", Required: true, Aliases: []string{"case_number", "case no"}, Description: "Upsert key: existing incidents with this case_number in the target establishment are updated; new case numbers insert."},
		{Name: "date_of_incident", Label: "Date of Incident", Required: true, Aliases: []string{"date_of_incident", "incident_date"}, Description: "YYYY-MM-DD."},
		{Name: "incident_location", Label: "Incident Location", Aliases: []string{"incident_location", "location"}},
		{Name: "incident_description", Label: "Incident Description", Aliases: []string{"incident_description", "description"}},
		{Name: "incident_outcome", Label: "Incident Outcome", Required: true, Aliases: []string{"incident_outcome", "outcome"}, Description: "Death / Days Away From Work / Job Transfer or Restriction / Other Recordable. Reverse-mapped to severity_code."},
		{Name: "dafw_num_away", Label: "Days Away From Work", Aliases: []string{"dafw_num_away", "days_away"}},
		{Name: "djtr_num_tr", Label: "Days Restricted or Transferred", Aliases: []string{"djtr_num_tr", "days_restricted"}},
		{Name: "type_of_incident", Label: "Type of Incident", Aliases: []string{"type_of_incident", "type", "classification"}, Description: "Injury / Skin Disorder / Respiratory Condition / Poisoning / Hearing Loss / All Other Illnesses."},
		{Name: "treatment_facility_type", Label: "Treatment Facility Type", Aliases: []string{"treatment_facility_type", "facility_type"}},
		{Name: "treatment_in_patient", Label: "In-patient Treatment?", Aliases: []string{"treatment_in_patient", "hospitalized"}, Description: "Y/N — maps to was_hospitalized."},
		{Name: "time_started_work", Label: "Time Started Work", Aliases: []string{"time_started_work", "time_employee_began_work"}},
		{Name: "time_of_incident", Label: "Time of Incident", Aliases: []string{"time_of_incident", "incident_time"}},
		{Name: "time_unknown", Label: "Time Unknown?", Aliases: []string{"time_unknown"}},
		{Name: "nar_before_incident", Label: "What Employee Was Doing Before", Aliases: []string{"nar_before_incident", "activity_description"}},
		{Name: "nar_what_happened", Label: "What Happened", Aliases: []string{"nar_what_happened"}, Description: "Narrative of the incident. Also stored as incident_description if that column isn't mapped."},
		{Name: "nar_injury_illness", Label: "Injury / Illness Description", Aliases: []string{"nar_injury_illness", "injury_description"}},
		{Name: "nar_object_substance", Label: "Object or Substance", Aliases: []string{"nar_object_substance", "object_or_substance"}},
		{Name: "date_of_death", Label: "Date of Death", Aliases: []string{"date_of_death"}, Description: "YYYY-MM-DD. Only for fatalities."},

		// Dropped on import — declared so the fuzzy matcher assigns
		// these CSV columns correctly instead of misrouting them.
		{Name: "date_of_birth", Label: "Date of Birth (not imported)", Aliases: []string{"date_of_birth", "dob"}, Description: "ITA includes employee DOB; odin drops it on import because the CSV lacks an employee key to match against. Link employees manually after import."},
		{Name: "date_of_hire", Label: "Date of Hire (not imported)", Aliases: []string{"date_of_hire", "hire_date"}, Description: "Dropped on import (see Date of Birth note)."},
		{Name: "sex", Label: "Sex (not imported)", Aliases: []string{"sex", "gender"}, Description: "Dropped on import (see Date of Birth note)."},
		{Name: "job_title", Label: "Job Title (not imported)", Aliases: []string{"job_title", "title"}, Description: "Dropped on import (see Date of Birth note)."},
	}
}

// Reverse-maps from ITA human labels to odin internal codes. Hardcoded
// because the ITA vocabulary is OSHA-frozen and the mapping is 4+6+7 =
// 17 entries total. Update together if OSHA ever revises the spec.
var itaOutcomeToSeverity = map[string]string{
	"Death":                        "FATALITY",
	"Days Away From Work":          "LOST_TIME",
	"Job Transfer or Restriction":  "RESTRICTED",
	"Other Recordable":             "MEDICAL_TX",
}

var itaTypeToCaseClassification = map[string]string{
	"Injury":                 "INJURY",
	"Skin Disorder":          "SKIN",
	"Respiratory Condition":  "RESP",
	"Poisoning":              "POISON",
	"Hearing Loss":           "HEARING",
	"All Other Illnesses":    "OTHER_ILL",
}

var itaFacilityToCode = map[string]string{
	"Hospital Emergency Room":     "HOSPITAL_ER",
	"Hospital Outpatient Clinic":  "HOSPITAL_OP",
	"Physician's Office":          "PHYSICIAN",
	"Urgent Care Center":          "URGENT_CARE",
	"Occupational Health Clinic":  "OCC_HEALTH",
	"Other Facility":              "OTHER",
	"Unknown":                     "UNKNOWN",
}

type oshaITADetailPayload struct {
	EstablishmentID             int64
	CaseNumber                  string // upsert key
	IncidentDate                string // YYYY-MM-DD
	LocationDescription         *string
	IncidentDescription         string // NOT NULL in schema
	SeverityCode                string // reverse-mapped from incident_outcome
	DaysAwayFromWork            *int
	DaysRestrictedOrTransferred *int
	CaseClassificationCode      *string // reverse-mapped from type_of_incident
	TreatmentFacilityTypeCode   *string
	WasHospitalized             int
	TimeEmployeeBeganWork       *string
	IncidentTime                *string
	TimeUnknown                 int
	ActivityDescription         *string
	InjuryIllnessDescription    *string
	ObjectOrSubstance           *string
	DateOfDeath                 *string
}

func (*oshaITADetailImporter) ValidateRow(
	raw map[string]string,
	mapping map[string]string,
	rowIdx int,
	ctx RowContext,
) (any, []ValidationError) {
	var errs []ValidationError

	if ctx.EstablishmentID == nil {
		errs = append(errs, ValidationError{Row: rowIdx, Message: "target establishment not set on the import"})
		return nil, errs
	}

	resolve := func(target string) string {
		for src, dst := range mapping {
			if dst == target {
				return strings.TrimSpace(raw[src])
			}
		}
		return ""
	}

	// Required fields
	caseNumber := resolve("case_number")
	if caseNumber == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "case_number", Message: "Case Number is required"})
	}

	incidentDate := resolve("date_of_incident")
	if incidentDate == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "date_of_incident", Message: "Date of Incident is required"})
	} else if iso, ok, msg := parseDate(incidentDate); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "date_of_incident", Message: msg})
	} else if ok {
		incidentDate = iso
	}

	outcome := resolve("incident_outcome")
	severity, okSeverity := itaOutcomeToSeverity[outcome]
	if outcome == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "incident_outcome", Message: "Incident Outcome is required"})
	} else if !okSeverity {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "incident_outcome", Message: fmt.Sprintf("Unknown incident outcome %q (expected Death / Days Away From Work / Job Transfer or Restriction / Other Recordable)", outcome)})
	}

	// incident_description column on the schema is NOT NULL. Prefer the
	// ITA "nar_what_happened" narrative; fall back to the short
	// "incident_description" if that's all the CSV has.
	narWhatHappened := resolve("nar_what_happened")
	incidentDesc := resolve("incident_description")
	description := narWhatHappened
	if description == "" {
		description = incidentDesc
	}
	if description == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Message: "At least one of nar_what_happened or incident_description must be provided"})
	}

	p := &oshaITADetailPayload{
		EstablishmentID:     *ctx.EstablishmentID,
		CaseNumber:          caseNumber,
		IncidentDate:        incidentDate,
		IncidentDescription: description,
		SeverityCode:        severity,
	}

	// Optional text fields
	setIfNonEmpty(&p.LocationDescription, resolve("incident_location"))
	setIfNonEmpty(&p.TimeEmployeeBeganWork, resolve("time_started_work"))
	setIfNonEmpty(&p.IncidentTime, resolve("time_of_incident"))
	setIfNonEmpty(&p.ActivityDescription, resolve("nar_before_incident"))
	setIfNonEmpty(&p.InjuryIllnessDescription, resolve("nar_injury_illness"))
	setIfNonEmpty(&p.ObjectOrSubstance, resolve("nar_object_substance"))

	// type_of_incident → case_classification_code (reverse map)
	if v := resolve("type_of_incident"); v != "" {
		code, ok := itaTypeToCaseClassification[v]
		if !ok {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "type_of_incident", Message: fmt.Sprintf("Unknown type of incident %q (expected Injury / Skin Disorder / Respiratory Condition / Poisoning / Hearing Loss / All Other Illnesses)", v)})
		} else {
			p.CaseClassificationCode = &code
		}
	}

	// treatment_facility_type → treatment_facility_type_code
	if v := resolve("treatment_facility_type"); v != "" {
		code, ok := itaFacilityToCode[v]
		if !ok {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "treatment_facility_type", Message: fmt.Sprintf("Unknown treatment facility type %q", v)})
		} else {
			p.TreatmentFacilityTypeCode = &code
		}
	}

	// Integer columns
	if v := resolve("dafw_num_away"); v != "" {
		n, msg := parseOptionalInt(v, "Days Away From Work")
		if msg != "" {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "dafw_num_away", Message: msg})
		} else {
			p.DaysAwayFromWork = n
		}
	}
	if v := resolve("djtr_num_tr"); v != "" {
		n, msg := parseOptionalInt(v, "Days Restricted")
		if msg != "" {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "djtr_num_tr", Message: msg})
		} else {
			p.DaysRestrictedOrTransferred = n
		}
	}

	// Boolean-ish columns: Y/N → 1/0
	p.WasHospitalized = ynToInt(resolve("treatment_in_patient"))
	p.TimeUnknown = ynToInt(resolve("time_unknown"))

	// date_of_death optional
	if v := resolve("date_of_death"); v != "" {
		if iso, ok, msg := parseDate(v); msg != "" {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "date_of_death", Message: msg})
		} else if ok {
			p.DateOfDeath = &iso
		}
	}

	if len(errs) > 0 {
		return nil, errs
	}
	return p, nil
}

func (*oshaITADetailImporter) InsertRow(db Execer, payload any, ctx RowContext) (int64, error) {
	p, ok := payload.(*oshaITADetailPayload)
	if !ok {
		return 0, fmt.Errorf("osha_ita_detail: wrong payload type %T", payload)
	}

	// Upsert by (establishment_id, case_number). If a matching incident
	// exists, UPDATE it; otherwise INSERT.
	existing, err := db.QueryVal(
		`SELECT id FROM incidents WHERE establishment_id = ? AND case_number = ?`,
		p.EstablishmentID, p.CaseNumber,
	)
	if err != nil {
		return 0, fmt.Errorf("lookup existing incident: %w", err)
	}

	if existing != nil {
		id, ok := existing.(int64)
		if !ok {
			return 0, fmt.Errorf("existing incident id has unexpected type %T", existing)
		}
		if err := db.ExecParams(
			`UPDATE incidents SET
			     incident_date = ?,
			     location_description = ?,
			     incident_description = ?,
			     severity_code = ?,
			     case_classification_code = ?,
			     treatment_facility_type_code = ?,
			     was_hospitalized = ?,
			     days_away_from_work = ?,
			     days_restricted_or_transferred = ?,
			     date_of_death = ?,
			     time_employee_began_work = ?,
			     incident_time = ?,
			     time_unknown = ?,
			     activity_description = ?,
			     injury_illness_description = ?,
			     object_or_substance = ?,
			     updated_at = datetime('now')
			 WHERE id = ?`,
			p.IncidentDate, p.LocationDescription, p.IncidentDescription,
			p.SeverityCode, p.CaseClassificationCode, p.TreatmentFacilityTypeCode,
			p.WasHospitalized, p.DaysAwayFromWork, p.DaysRestrictedOrTransferred,
			p.DateOfDeath, p.TimeEmployeeBeganWork, p.IncidentTime, p.TimeUnknown,
			p.ActivityDescription, p.InjuryIllnessDescription, p.ObjectOrSubstance,
			id,
		); err != nil {
			return 0, fmt.Errorf("update incident %d: %w", id, err)
		}
		return id, nil
	}

	// No match — INSERT new incident. employee_id is NULL by design;
	// user links employees manually after import.
	if err := db.ExecParams(
		`INSERT INTO incidents (
		     establishment_id, case_number, employee_id,
		     incident_date, location_description, incident_description,
		     severity_code, case_classification_code,
		     treatment_facility_type_code, was_hospitalized,
		     days_away_from_work, days_restricted_or_transferred,
		     date_of_death, time_employee_began_work, incident_time,
		     time_unknown, activity_description,
		     injury_illness_description, object_or_substance)
		 VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		p.EstablishmentID, p.CaseNumber,
		p.IncidentDate, p.LocationDescription, p.IncidentDescription,
		p.SeverityCode, p.CaseClassificationCode,
		p.TreatmentFacilityTypeCode, p.WasHospitalized,
		p.DaysAwayFromWork, p.DaysRestrictedOrTransferred,
		p.DateOfDeath, p.TimeEmployeeBeganWork, p.IncidentTime,
		p.TimeUnknown, p.ActivityDescription,
		p.InjuryIllnessDescription, p.ObjectOrSubstance,
	); err != nil {
		return 0, fmt.Errorf("insert incident: %w", err)
	}
	id, err := db.QueryVal("SELECT last_insert_rowid()")
	if err != nil {
		return 0, err
	}
	return id.(int64), nil
}

// --- helpers -----------------------------------------------------------------

// ynToInt converts Y/Yes/1/true → 1; everything else (including blank) → 0.
// Case-insensitive.
func ynToInt(v string) int {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "y", "yes", "1", "true", "t":
		return 1
	default:
		return 0
	}
}

var intPattern = regexp.MustCompile(`^-?\d+$`)

func parseOptionalInt(v, label string) (*int, string) {
	v = strings.TrimSpace(v)
	if v == "" {
		return nil, ""
	}
	if !intPattern.MatchString(v) {
		return nil, fmt.Sprintf("%s must be an integer (got %q)", label, v)
	}
	// intPattern guarantees a valid base-10 int; use sscanf-free path.
	var n int
	if _, err := fmt.Sscanf(v, "%d", &n); err != nil {
		return nil, fmt.Sprintf("%s: %v", label, err)
	}
	return &n, ""
}
