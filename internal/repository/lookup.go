package repository

import (
	"fmt"

	"github.com/asgardehs/odin/internal/database"
)

// lookupQueries is the server-side whitelist of lookup tables exposed
// via GET /api/lookup/{table}. Using a whitelist rather than
// interpolating {table} into SQL prevents client-driven access to
// arbitrary tables.
//
// Every query normalizes its result shape to (code, name, description)
// so the frontend <LookupDropdown> component can render any of these
// tables uniformly. Tables without a native description column (e.g.
// case_classifications) emit an empty string; tables with a natural
// grouping column (body_parts.category) use that.
//
// Ordering is chosen per-table for UX:
//   - incident_severity_levels: recordable severities first (common case)
//   - body_parts: grouped by body region
//   - ita_establishment_sizes: small → large by headcount
//   - others: alphabetical by code
var lookupQueries = map[string]string{
	"case_classifications": `
		SELECT code, name, '' AS description
		FROM case_classifications
		ORDER BY code`,

	"incident_severity_levels": `
		SELECT code, name, description
		FROM incident_severity_levels
		ORDER BY is_osha_recordable DESC, code`,

	"body_parts": `
		SELECT code, name, COALESCE(category, '') AS description
		FROM body_parts
		ORDER BY category, name`,

	"ita_establishment_sizes": `
		SELECT code, name, description
		FROM ita_establishment_sizes
		ORDER BY COALESCE(min_employees, 0)`,

	"ita_establishment_types": `
		SELECT code, name, description
		FROM ita_establishment_types
		ORDER BY code`,

	"ita_treatment_facility_types": `
		SELECT code, name, description
		FROM ita_treatment_facility_types
		ORDER BY code`,
}

// ListLookup returns the rows of a whitelisted lookup table as
// (code, name, description) triples. Unknown tables return an error;
// the HTTP handler maps that to a 404.
func (r *Repo) ListLookup(table string) ([]database.Row, error) {
	query, ok := lookupQueries[table]
	if !ok {
		return nil, fmt.Errorf("unknown lookup table: %s", table)
	}
	return r.DB.QueryRows(query)
}
