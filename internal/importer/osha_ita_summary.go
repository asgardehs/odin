package importer

import (
	"fmt"
	"strings"
)

// oshaITASummaryImporter handles the OSHA ITA summary CSV shape (one
// row per establishment per year, the 28-column 300A equivalent).
//
// Unlike detail import which creates incidents, summary import does
// NOT persist the row itself — the summary totals are derived from
// incidents and re-computing them would conflict with the live data.
// Instead:
//   - Updates the target establishment's annual_avg_employees and
//     total_hours_worked (the two fields that are legitimately
//     establishment-scoped, not per-incident).
//   - Everything else on the row (the 12 total_* counts, the size/
//     type/address fields, no_injuries_illnesses, change_reason) is
//     acknowledged but not persisted — the establishment-identifying
//     fields already live on establishments, the totals are derived
//     from incidents, and change_reason needs an amendment-tracking
//     flow that doesn't exist yet.
//
// The engine writes its standard per-upload audit entry capturing
// filename + row count; that's enough traceability for now.
type oshaITASummaryImporter struct{}

func init() {
	Register(&oshaITASummaryImporter{})
}

func (*oshaITASummaryImporter) ModuleSlug() string { return "osha_ita_summary" }

func (*oshaITASummaryImporter) TargetFields() []TargetField {
	// All 28 columns declared so the fuzzy matcher correctly claims
	// each ITA header. Only two carry values that actually land on
	// the target establishment; the rest are acknowledged-and-dropped.
	return []TargetField{
		{Name: "annual_average_employees", Label: "Annual Average Employees", Aliases: []string{"annual_average_employees", "annual_avg_employees"}, Description: "Updates the target establishment's annual_avg_employees field."},
		{Name: "total_hours_worked", Label: "Total Hours Worked", Aliases: []string{"total_hours_worked"}, Description: "Updates the target establishment's total_hours_worked field."},
		{Name: "year_filing_for", Label: "Year Filing For", Aliases: []string{"year_filing_for", "reporting_year"}, Description: "Informational; odin currently does not track per-year snapshots of establishment employee counts."},

		// Dropped on import — all establishment-identifying fields that
		// already live on the target establishment.
		{Name: "establishment_name", Label: "Establishment Name (not imported)", Aliases: []string{"establishment_name"}},
		{Name: "ein", Label: "EIN (not imported)", Aliases: []string{"ein"}},
		{Name: "company_name", Label: "Company Name (not imported)", Aliases: []string{"company_name"}},
		{Name: "street_address", Label: "Street Address (not imported)", Aliases: []string{"street_address"}},
		{Name: "city", Label: "City (not imported)", Aliases: []string{"city"}},
		{Name: "state", Label: "State (not imported)", Aliases: []string{"state"}},
		{Name: "zip", Label: "ZIP (not imported)", Aliases: []string{"zip"}},
		{Name: "naics_code", Label: "NAICS Code (not imported)", Aliases: []string{"naics_code"}},
		{Name: "industry_description", Label: "Industry Description (not imported)", Aliases: []string{"industry_description"}},
		{Name: "size", Label: "Size (not imported)", Aliases: []string{"size"}},
		{Name: "establishment_type", Label: "Establishment Type (not imported)", Aliases: []string{"establishment_type"}},

		// Derived totals — come back out of the incidents table whenever
		// the summary view is queried; persisting them on import would
		// create a drift surface.
		{Name: "no_injuries_illnesses", Label: "No Injuries/Illnesses Flag (not imported)", Aliases: []string{"no_injuries_illnesses"}, Description: "Derived at export time from the incidents table."},
		{Name: "total_deaths", Label: "Total Deaths (not imported)", Aliases: []string{"total_deaths"}, Description: "Derived from incidents."},
		{Name: "total_dafw_cases", Label: "Total DAFW Cases (not imported)", Aliases: []string{"total_dafw_cases"}},
		{Name: "total_djtr_cases", Label: "Total DJTR Cases (not imported)", Aliases: []string{"total_djtr_cases"}},
		{Name: "total_other_cases", Label: "Total Other Cases (not imported)", Aliases: []string{"total_other_cases"}},
		{Name: "total_dafw_days", Label: "Total DAFW Days (not imported)", Aliases: []string{"total_dafw_days"}},
		{Name: "total_djtr_days", Label: "Total DJTR Days (not imported)", Aliases: []string{"total_djtr_days"}},
		{Name: "total_injuries", Label: "Total Injuries (not imported)", Aliases: []string{"total_injuries"}},
		{Name: "total_skin_disorders", Label: "Total Skin Disorders (not imported)", Aliases: []string{"total_skin_disorders"}},
		{Name: "total_respiratory_conditions", Label: "Total Respiratory Conditions (not imported)", Aliases: []string{"total_respiratory_conditions"}},
		{Name: "total_poisonings", Label: "Total Poisonings (not imported)", Aliases: []string{"total_poisonings"}},
		{Name: "total_hearing_loss", Label: "Total Hearing Loss (not imported)", Aliases: []string{"total_hearing_loss"}},
		{Name: "total_other_illnesses", Label: "Total Other Illnesses (not imported)", Aliases: []string{"total_other_illnesses"}},

		{Name: "change_reason", Label: "Change Reason (not imported)", Aliases: []string{"change_reason"}, Description: "Amendment-tracking flow doesn't exist yet in odin."},
	}
}

type oshaITASummaryPayload struct {
	EstablishmentID        int64
	AnnualAverageEmployees *int
	TotalHoursWorked       *int
}

func (*oshaITASummaryImporter) ValidateRow(
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

	p := &oshaITASummaryPayload{EstablishmentID: *ctx.EstablishmentID}

	if v := resolve("annual_average_employees"); v != "" {
		n, msg := parseOptionalInt(v, "Annual Average Employees")
		if msg != "" {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "annual_average_employees", Message: msg})
		} else {
			p.AnnualAverageEmployees = n
		}
	}

	if v := resolve("total_hours_worked"); v != "" {
		n, msg := parseOptionalInt(v, "Total Hours Worked")
		if msg != "" {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "total_hours_worked", Message: msg})
		} else {
			p.TotalHoursWorked = n
		}
	}

	// If neither field is present, the import is a no-op. Flag so the
	// user knows nothing actually changed.
	if p.AnnualAverageEmployees == nil && p.TotalHoursWorked == nil {
		errs = append(errs, ValidationError{
			Row:     rowIdx,
			Message: "neither annual_average_employees nor total_hours_worked provided; nothing to update on establishment",
		})
	}

	if len(errs) > 0 {
		return nil, errs
	}
	return p, nil
}

func (*oshaITASummaryImporter) InsertRow(db Execer, payload any, ctx RowContext) (int64, error) {
	p, ok := payload.(*oshaITASummaryPayload)
	if !ok {
		return 0, fmt.Errorf("osha_ita_summary: wrong payload type %T", payload)
	}

	// Build the UPDATE statement dynamically based on which fields are
	// present. Using COALESCE would overwrite non-null fields even when
	// the CSV cell was blank; that's a data-loss footgun. Instead only
	// touch the columns the user provided.
	set := []string{}
	args := []any{}
	if p.AnnualAverageEmployees != nil {
		set = append(set, "annual_avg_employees = ?")
		args = append(args, *p.AnnualAverageEmployees)
	}
	if p.TotalHoursWorked != nil {
		set = append(set, "total_hours_worked = ?")
		args = append(args, *p.TotalHoursWorked)
	}
	// Always bump updated_at so audit-by-timestamp still surfaces these.
	set = append(set, "updated_at = datetime('now')")
	args = append(args, p.EstablishmentID)

	sql := "UPDATE establishments SET " + strings.Join(set, ", ") + " WHERE id = ?"
	if err := db.ExecParams(sql, args...); err != nil {
		return 0, fmt.Errorf("update establishment %d: %w", p.EstablishmentID, err)
	}

	// Returning the establishment id as the "inserted id" — the framework
	// uses it for audit. No actual row was inserted; this is a virtual
	// per-establishment update disguised as a row insert.
	return p.EstablishmentID, nil
}
