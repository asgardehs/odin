package repository

import "fmt"

const establishmentModule = "establishments"
const establishmentTable = "establishments"

// EstablishmentInput is the payload for creating or updating an establishment.
type EstablishmentInput struct {
	Name                string  `json:"name"`
	StreetAddress       string  `json:"street_address"`
	City                string  `json:"city"`
	State               string  `json:"state"`
	Zip                 string  `json:"zip"`
	IndustryDescription *string `json:"industry_description,omitempty"`
	NAICSCode           *string `json:"naics_code,omitempty"`
	SICCode             *string `json:"sic_code,omitempty"`
	PeakEmployees       *int    `json:"peak_employees,omitempty"`
	AnnualAvgEmployees  *int    `json:"annual_avg_employees,omitempty"`
}

func (r *Repo) CreateEstablishment(user string, in EstablishmentInput) (int64, error) {
	return r.insertAndAudit(establishmentTable, establishmentModule, user,
		fmt.Sprintf("Created establishment: %s", in.Name),
		`INSERT INTO establishments (name, street_address, city, state, zip,
		        industry_description, naics_code, sic_code,
		        peak_employees, annual_avg_employees)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.Name, in.StreetAddress, in.City, in.State, in.Zip,
		in.IndustryDescription, in.NAICSCode, in.SICCode,
		in.PeakEmployees, in.AnnualAvgEmployees,
	)
}

func (r *Repo) UpdateEstablishment(user string, id int64, in EstablishmentInput) error {
	return r.updateAndAudit(establishmentTable, establishmentModule, id, user,
		fmt.Sprintf("Updated establishment: %s", in.Name),
		`UPDATE establishments SET
		        name = ?, street_address = ?, city = ?, state = ?, zip = ?,
		        industry_description = ?, naics_code = ?, sic_code = ?,
		        peak_employees = ?, annual_avg_employees = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.Name, in.StreetAddress, in.City, in.State, in.Zip,
		in.IndustryDescription, in.NAICSCode, in.SICCode,
		in.PeakEmployees, in.AnnualAvgEmployees,
		id,
	)
}

func (r *Repo) DeleteEstablishment(user string, id int64) error {
	return r.deleteAndAudit(establishmentTable, establishmentModule, id, user,
		fmt.Sprintf("Deleted establishment %d", id),
		`DELETE FROM establishments WHERE id = ?`, id,
	)
}
