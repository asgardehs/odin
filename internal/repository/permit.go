package repository

import "fmt"

const permitModule = "permits"
const permitTable = "permits"

// PermitInput is the payload for creating or updating a permit.
type PermitInput struct {
	EstablishmentID       int64    `json:"establishment_id"`
	PermitTypeID          int64    `json:"permit_type_id"`
	IssuingAgencyID       *int64   `json:"issuing_agency_id,omitempty"`
	PermitNumber          string   `json:"permit_number"`
	PermitName            *string  `json:"permit_name,omitempty"`
	ApplicationDate       *string  `json:"application_date,omitempty"`
	ApplicationNumber     *string  `json:"application_number,omitempty"`
	IssueDate             *string  `json:"issue_date,omitempty"`
	EffectiveDate         *string  `json:"effective_date,omitempty"`
	ExpirationDate        *string  `json:"expiration_date,omitempty"`
	PermitClassification  *string  `json:"permit_classification,omitempty"`
	CoverageDescription   *string  `json:"coverage_description,omitempty"`
	AnnualFee             *float64 `json:"annual_fee,omitempty"`
	FeeDueDate            *string  `json:"fee_due_date,omitempty"`
	InternalOwnerID       *int64   `json:"internal_owner_id,omitempty"`
	Notes                 *string  `json:"notes,omitempty"`
}

func (r *Repo) CreatePermit(user string, in PermitInput) (int64, error) {
	return r.insertAndAudit(permitTable, permitModule, user,
		fmt.Sprintf("Created permit: %s", in.PermitNumber),
		`INSERT INTO permits (establishment_id, permit_type_id, issuing_agency_id,
		        permit_number, permit_name, application_date, application_number,
		        issue_date, effective_date, expiration_date,
		        permit_classification, coverage_description,
		        annual_fee, fee_due_date, internal_owner_id, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.PermitTypeID, in.IssuingAgencyID,
		in.PermitNumber, in.PermitName, in.ApplicationDate, in.ApplicationNumber,
		in.IssueDate, in.EffectiveDate, in.ExpirationDate,
		in.PermitClassification, in.CoverageDescription,
		in.AnnualFee, in.FeeDueDate, in.InternalOwnerID, in.Notes,
	)
}

func (r *Repo) UpdatePermit(user string, id int64, in PermitInput) error {
	return r.updateAndAudit(permitTable, permitModule, id, user,
		fmt.Sprintf("Updated permit: %s", in.PermitNumber),
		`UPDATE permits SET
		        permit_type_id = ?, issuing_agency_id = ?,
		        permit_number = ?, permit_name = ?,
		        application_date = ?, application_number = ?,
		        issue_date = ?, effective_date = ?, expiration_date = ?,
		        permit_classification = ?, coverage_description = ?,
		        annual_fee = ?, fee_due_date = ?, internal_owner_id = ?, notes = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.PermitTypeID, in.IssuingAgencyID,
		in.PermitNumber, in.PermitName,
		in.ApplicationDate, in.ApplicationNumber,
		in.IssueDate, in.EffectiveDate, in.ExpirationDate,
		in.PermitClassification, in.CoverageDescription,
		in.AnnualFee, in.FeeDueDate, in.InternalOwnerID, in.Notes,
		id,
	)
}

// RevokePermit marks a permit as revoked.
func (r *Repo) RevokePermit(user string, id int64) error {
	return r.updateAndAudit(permitTable, permitModule, id, user,
		fmt.Sprintf("Revoked permit %d", id),
		`UPDATE permits SET status = 'revoked', updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeletePermit(user string, id int64) error {
	return r.deleteAndAudit(permitTable, permitModule, id, user,
		fmt.Sprintf("Deleted permit %d", id),
		`DELETE FROM permits WHERE id = ?`, id,
	)
}
