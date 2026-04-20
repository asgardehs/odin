package repository

import "fmt"

const emissionUnitModule = "emission_units"
const emissionUnitTable = "air_emission_units"

// EmissionUnitInput is the payload for creating or updating an air emission unit.
type EmissionUnitInput struct {
	EstablishmentID            int64    `json:"establishment_id"`
	UnitName                   string   `json:"unit_name"`
	UnitDescription            *string  `json:"unit_description,omitempty"`
	SourceCategory             string   `json:"source_category"`
	SccCode                    *string  `json:"scc_code,omitempty"`
	IsFugitive                 *int     `json:"is_fugitive,omitempty"`
	Building                   *string  `json:"building,omitempty"`
	Area                       *string  `json:"area,omitempty"`
	StackID                    *int64   `json:"stack_id,omitempty"`
	PermitTypeCode             *string  `json:"permit_type_code,omitempty"`
	PermitNumber               *string  `json:"permit_number,omitempty"`
	MaxThroughput              *float64 `json:"max_throughput,omitempty"`
	MaxThroughputUnit          *string  `json:"max_throughput_unit,omitempty"`
	MaxOperatingHoursYear      *float64 `json:"max_operating_hours_year,omitempty"`
	TypicalOperatingHoursYear  *float64 `json:"typical_operating_hours_year,omitempty"`
	RestrictedThroughput       *float64 `json:"restricted_throughput,omitempty"`
	RestrictedThroughputUnit   *string  `json:"restricted_throughput_unit,omitempty"`
	RestrictedHoursYear        *float64 `json:"restricted_hours_year,omitempty"`
	InstallDate                *string  `json:"install_date,omitempty"`
	DecommissionDate           *string  `json:"decommission_date,omitempty"`
	Notes                      *string  `json:"notes,omitempty"`
}

func (r *Repo) CreateEmissionUnit(user string, in EmissionUnitInput) (int64, error) {
	return r.insertAndAudit(emissionUnitTable, emissionUnitModule, user,
		fmt.Sprintf("Created emission unit: %s", in.UnitName),
		`INSERT INTO air_emission_units (
		        establishment_id, unit_name, unit_description,
		        source_category, scc_code, is_fugitive,
		        building, area, stack_id,
		        permit_type_code, permit_number,
		        max_throughput, max_throughput_unit,
		        max_operating_hours_year, typical_operating_hours_year,
		        restricted_throughput, restricted_throughput_unit, restricted_hours_year,
		        install_date, decommission_date, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.UnitName, in.UnitDescription,
		in.SourceCategory, in.SccCode, in.IsFugitive,
		in.Building, in.Area, in.StackID,
		in.PermitTypeCode, in.PermitNumber,
		in.MaxThroughput, in.MaxThroughputUnit,
		in.MaxOperatingHoursYear, in.TypicalOperatingHoursYear,
		in.RestrictedThroughput, in.RestrictedThroughputUnit, in.RestrictedHoursYear,
		in.InstallDate, in.DecommissionDate, in.Notes,
	)
}

func (r *Repo) UpdateEmissionUnit(user string, id int64, in EmissionUnitInput) error {
	return r.updateAndAudit(emissionUnitTable, emissionUnitModule, id, user,
		fmt.Sprintf("Updated emission unit: %s", in.UnitName),
		`UPDATE air_emission_units SET
		        unit_name = ?, unit_description = ?,
		        source_category = ?, scc_code = ?, is_fugitive = ?,
		        building = ?, area = ?, stack_id = ?,
		        permit_type_code = ?, permit_number = ?,
		        max_throughput = ?, max_throughput_unit = ?,
		        max_operating_hours_year = ?, typical_operating_hours_year = ?,
		        restricted_throughput = ?, restricted_throughput_unit = ?, restricted_hours_year = ?,
		        install_date = ?, decommission_date = ?, notes = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.UnitName, in.UnitDescription,
		in.SourceCategory, in.SccCode, in.IsFugitive,
		in.Building, in.Area, in.StackID,
		in.PermitTypeCode, in.PermitNumber,
		in.MaxThroughput, in.MaxThroughputUnit,
		in.MaxOperatingHoursYear, in.TypicalOperatingHoursYear,
		in.RestrictedThroughput, in.RestrictedThroughputUnit, in.RestrictedHoursYear,
		in.InstallDate, in.DecommissionDate, in.Notes,
		id,
	)
}

// DecommissionEmissionUnit marks a unit decommissioned and records the date.
func (r *Repo) DecommissionEmissionUnit(user string, id int64) error {
	return r.updateAndAudit(emissionUnitTable, emissionUnitModule, id, user,
		fmt.Sprintf("Decommissioned emission unit %d", id),
		`UPDATE air_emission_units
		    SET is_active = 0,
		        decommission_date = COALESCE(decommission_date, date('now')),
		        updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

// ReactivateEmissionUnit returns a unit to service (clears decommission_date).
func (r *Repo) ReactivateEmissionUnit(user string, id int64) error {
	return r.updateAndAudit(emissionUnitTable, emissionUnitModule, id, user,
		fmt.Sprintf("Reactivated emission unit %d", id),
		`UPDATE air_emission_units
		    SET is_active = 1,
		        decommission_date = NULL,
		        updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeleteEmissionUnit(user string, id int64) error {
	return r.deleteAndAudit(emissionUnitTable, emissionUnitModule, id, user,
		fmt.Sprintf("Deleted emission unit %d", id),
		`DELETE FROM air_emission_units WHERE id = ?`, id,
	)
}
