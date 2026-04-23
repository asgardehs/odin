// Package osha_ita exports OSHA Injury Tracking Application (ITA) CSVs.
// Two shapes are supported, mirroring the files OSHA's ITA portal accepts:
//
//   - Detail CSV: 24 columns, one row per recordable incident for a given
//     (establishment, year). Emitted from v_osha_ita_detail.
//   - Summary CSV: 28 columns, one row per (establishment, year). Emitted
//     from v_osha_ita_summary; falls back to a synthesized zero-row when
//     the establishment had no recordable incidents in the year.
//
// The CSV column order is frozen in detailColumns / summaryColumns below;
// those lists are the canonical spec inside odin. If OSHA revises its
// template, update these constants and the matching view emit-aliases in
// docs/database-design/sql/module_c_osha300.sql together.
package osha_ita

import (
	"bytes"
	"encoding/csv"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/asgardehs/odin/internal/database"
)

// detailColumns is the 24-column ITA detail CSV shape, in spec order.
var detailColumns = []string{
	"establishment_name",
	"year_of_filing",
	"case_number",
	"job_title",
	"date_of_incident",
	"incident_location",
	"incident_description",
	"incident_outcome",
	"dafw_num_away",
	"djtr_num_tr",
	"type_of_incident",
	"date_of_birth",
	"date_of_hire",
	"sex",
	"treatment_facility_type",
	"treatment_in_patient",
	"time_started_work",
	"time_of_incident",
	"time_unknown",
	"nar_before_incident",
	"nar_what_happened",
	"nar_injury_illness",
	"nar_object_substance",
	"date_of_death",
}

// summaryColumns is the 28-column ITA summary CSV shape, in spec order.
var summaryColumns = []string{
	"establishment_name",
	"ein",
	"company_name",
	"street_address",
	"city",
	"state",
	"zip",
	"naics_code",
	"industry_description",
	"size",
	"establishment_type",
	"year_filing_for",
	"annual_average_employees",
	"total_hours_worked",
	"no_injuries_illnesses",
	"total_deaths",
	"total_dafw_cases",
	"total_djtr_cases",
	"total_other_cases",
	"total_dafw_days",
	"total_djtr_days",
	"total_injuries",
	"total_skin_disorders",
	"total_respiratory_conditions",
	"total_poisonings",
	"total_hearing_loss",
	"total_other_illnesses",
	"change_reason",
}

// DetailColumns returns a copy of the detail CSV column order. Used by
// the preview route for the UI's pre-download confirmation panel.
func DetailColumns() []string {
	out := make([]string, len(detailColumns))
	copy(out, detailColumns)
	return out
}

// SummaryColumns returns a copy of the summary CSV column order.
func SummaryColumns() []string {
	out := make([]string, len(summaryColumns))
	copy(out, summaryColumns)
	return out
}

// ExportDetail streams the ITA detail CSV for one establishment and year.
// One row per recordable incident. Non-recordable severities are filtered
// at the view level (v_osha_ita_detail INNER JOINs ita_outcome_mapping).
// Returns a CSV with just the header row when the (establishment, year)
// combo has zero recordable incidents.
func ExportDetail(db *database.DB, establishmentID int64, year string) (io.Reader, error) {
	rows, err := db.QueryRows(
		`SELECT `+strings.Join(detailColumns, ", ")+`
		 FROM v_osha_ita_detail
		 WHERE establishment_id = ? AND year_of_filing = ?`,
		establishmentID, year,
	)
	if err != nil {
		return nil, fmt.Errorf("export detail: query: %w", err)
	}
	return writeCSV(detailColumns, rows)
}

// ExportSummary streams the ITA summary CSV for one establishment and
// year. Always emits exactly one data row (300A is one row per
// establishment per year). When the establishment had no recordable
// incidents in the year, a synthesized row is returned with
// no_injuries_illnesses='Y' and zero totals; establishment identifying
// info is still read from the establishments table so the CSV has the
// shape OSHA expects even for an "empty" year.
func ExportSummary(db *database.DB, establishmentID int64, year string) (io.Reader, error) {
	rows, err := db.QueryRows(
		`SELECT `+strings.Join(summaryColumns, ", ")+`
		 FROM v_osha_ita_summary
		 WHERE establishment_id = ? AND year_filing_for = ?`,
		establishmentID, year,
	)
	if err != nil {
		return nil, fmt.Errorf("export summary: query: %w", err)
	}
	if len(rows) == 0 {
		rows, err = synthesizeEmptySummary(db, establishmentID, year)
		if err != nil {
			return nil, fmt.Errorf("export summary: empty-year fallback: %w", err)
		}
	}
	return writeCSV(summaryColumns, rows)
}

// synthesizeEmptySummary returns a one-row slice representing a zero-
// incident summary for (establishment, year). All count/day totals are 0;
// no_injuries_illnesses is 'Y'; change_reason is NULL. Establishment
// identifying info comes from the establishments table.
func synthesizeEmptySummary(db *database.DB, establishmentID int64, year string) ([]database.Row, error) {
	return db.QueryRows(
		`SELECT
		    est.name                      AS establishment_name,
		    est.ein                       AS ein,
		    est.company_name              AS company_name,
		    est.street_address            AS street_address,
		    est.city                      AS city,
		    est.state                     AS state,
		    est.zip                       AS zip,
		    est.naics_code                AS naics_code,
		    est.industry_description      AS industry_description,
		    ies.name                      AS size,
		    iet.name                      AS establishment_type,
		    ?1                            AS year_filing_for,
		    est.annual_avg_employees      AS annual_average_employees,
		    est.total_hours_worked        AS total_hours_worked,
		    'Y'                           AS no_injuries_illnesses,
		    0                             AS total_deaths,
		    0                             AS total_dafw_cases,
		    0                             AS total_djtr_cases,
		    0                             AS total_other_cases,
		    0                             AS total_dafw_days,
		    0                             AS total_djtr_days,
		    0                             AS total_injuries,
		    0                             AS total_skin_disorders,
		    0                             AS total_respiratory_conditions,
		    0                             AS total_poisonings,
		    0                             AS total_hearing_loss,
		    0                             AS total_other_illnesses,
		    NULL                          AS change_reason
		 FROM establishments est
		 LEFT JOIN ita_establishment_sizes ies ON ies.code = est.size_code
		 LEFT JOIN ita_establishment_types iet ON iet.code = est.establishment_type_code
		 WHERE est.id = ?2`,
		year, establishmentID,
	)
}

// PreviewData is returned by Preview for the UI pre-download panel.
type PreviewData struct {
	DetailRowCount     int      `json:"detail_row_count"`
	DetailColumns      []string `json:"detail_columns"`
	SummaryColumns     []string `json:"summary_columns"`
	NoInjuriesFlag     string   `json:"no_injuries_illnesses"` // "Y" if zero recordables, else "N"
	EstablishmentName  string   `json:"establishment_name"`
	EstablishmentKnown bool     `json:"establishment_known"` // false if the establishment_id didn't resolve
}

// Preview returns row counts + column headers + establishment display
// info for the UI to show before download. Cheap: two small queries,
// no full CSV materialization.
func Preview(db *database.DB, establishmentID int64, year string) (PreviewData, error) {
	out := PreviewData{
		DetailColumns:  DetailColumns(),
		SummaryColumns: SummaryColumns(),
	}

	// Establishment name (and existence check).
	estRow, err := db.QueryRow(
		`SELECT name FROM establishments WHERE id = ?`, establishmentID,
	)
	if err != nil {
		return out, fmt.Errorf("preview: establishment lookup: %w", err)
	}
	if estRow != nil {
		out.EstablishmentKnown = true
		if name, ok := estRow["name"].(string); ok {
			out.EstablishmentName = name
		}
	}

	// Recordable incident count for (establishment, year).
	cntRow, err := db.QueryRow(
		`SELECT COUNT(*) AS n FROM v_osha_ita_detail
		 WHERE establishment_id = ? AND year_of_filing = ?`,
		establishmentID, year,
	)
	if err != nil {
		return out, fmt.Errorf("preview: count: %w", err)
	}
	if cntRow != nil {
		if n, ok := cntRow["n"].(int64); ok {
			out.DetailRowCount = int(n)
		}
	}
	if out.DetailRowCount == 0 {
		out.NoInjuriesFlag = "Y"
	} else {
		out.NoInjuriesFlag = "N"
	}
	return out, nil
}

// writeCSV is the shared CSV-emit path for both exports. Walks rows in
// the specified column order and stringifies each cell.
func writeCSV(cols []string, rows []database.Row) (io.Reader, error) {
	var buf bytes.Buffer
	w := csv.NewWriter(&buf)

	if err := w.Write(cols); err != nil {
		return nil, fmt.Errorf("write header: %w", err)
	}

	record := make([]string, len(cols))
	for _, row := range rows {
		for i, col := range cols {
			record[i] = cellToString(row[col])
		}
		if err := w.Write(record); err != nil {
			return nil, fmt.Errorf("write row: %w", err)
		}
	}
	w.Flush()
	if err := w.Error(); err != nil {
		return nil, fmt.Errorf("flush csv: %w", err)
	}
	return &buf, nil
}

// cellToString normalizes a database.Row value into the CSV string form
// OSHA ITA expects. NULLs become empty strings. Numbers that arrive as
// float64 but have no fractional component emit as integers — this
// matters for count / day columns that must not render as "12.0".
func cellToString(v any) string {
	if v == nil {
		return ""
	}
	switch x := v.(type) {
	case string:
		return x
	case []byte:
		return string(x)
	case int:
		return strconv.Itoa(x)
	case int64:
		return strconv.FormatInt(x, 10)
	case float64:
		if x == float64(int64(x)) {
			return strconv.FormatInt(int64(x), 10)
		}
		return strconv.FormatFloat(x, 'f', -1, 64)
	case bool:
		if x {
			return "Y"
		}
		return "N"
	default:
		return fmt.Sprintf("%v", x)
	}
}
