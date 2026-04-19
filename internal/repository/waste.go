package repository

import "fmt"

const wasteStreamModule = "waste_streams"
const wasteStreamTable = "waste_streams"

// WasteStreamInput is the payload for creating or updating a waste stream.
type WasteStreamInput struct {
	EstablishmentID      int64    `json:"establishment_id"`
	StreamCode           *string  `json:"stream_code,omitempty"`
	StreamName           string   `json:"stream_name"`
	Description          *string  `json:"description,omitempty"`
	GeneratingProcess    *string  `json:"generating_process,omitempty"`
	SourceLocation       *string  `json:"source_location,omitempty"`
	SourceChemicalID     *int64   `json:"source_chemical_id,omitempty"`
	WasteCategory        string   `json:"waste_category"`
	WasteStreamTypeCode  *string  `json:"waste_stream_type_code,omitempty"`
	PhysicalForm         *string  `json:"physical_form,omitempty"`
	TypicalQtyPerMonth   *float64 `json:"typical_quantity_per_month,omitempty"`
	QuantityUnit         *string  `json:"quantity_unit,omitempty"`
	IsIgnitable          *int     `json:"is_ignitable,omitempty"`
	IsCorrosive          *int     `json:"is_corrosive,omitempty"`
	IsReactive           *int     `json:"is_reactive,omitempty"`
	IsToxic              *int     `json:"is_toxic,omitempty"`
	IsAcuteHazardous     *int     `json:"is_acute_hazardous,omitempty"`
	HandlingInstructions *string  `json:"handling_instructions,omitempty"`
	PPERequired          *string  `json:"ppe_required,omitempty"`
	IncompatibleWith     *string  `json:"incompatible_with,omitempty"`
	ProfileNumber        *string  `json:"profile_number,omitempty"`
	ProfileExpiration    *string  `json:"profile_expiration,omitempty"`
}

func (r *Repo) CreateWasteStream(user string, in WasteStreamInput) (int64, error) {
	return r.insertAndAudit(wasteStreamTable, wasteStreamModule, user,
		fmt.Sprintf("Created waste stream: %s (%s)", in.StreamName, in.WasteCategory),
		`INSERT INTO waste_streams (establishment_id, stream_code, stream_name,
		        description, generating_process, source_location, source_chemical_id,
		        waste_category, waste_stream_type_code, physical_form,
		        typical_quantity_per_month, quantity_unit,
		        is_ignitable, is_corrosive, is_reactive, is_toxic, is_acute_hazardous,
		        handling_instructions, ppe_required, incompatible_with,
		        profile_number, profile_expiration)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.StreamCode, in.StreamName,
		in.Description, in.GeneratingProcess, in.SourceLocation, in.SourceChemicalID,
		in.WasteCategory, in.WasteStreamTypeCode, in.PhysicalForm,
		in.TypicalQtyPerMonth, in.QuantityUnit,
		in.IsIgnitable, in.IsCorrosive, in.IsReactive, in.IsToxic, in.IsAcuteHazardous,
		in.HandlingInstructions, in.PPERequired, in.IncompatibleWith,
		in.ProfileNumber, in.ProfileExpiration,
	)
}

func (r *Repo) UpdateWasteStream(user string, id int64, in WasteStreamInput) error {
	return r.updateAndAudit(wasteStreamTable, wasteStreamModule, id, user,
		fmt.Sprintf("Updated waste stream: %s", in.StreamName),
		`UPDATE waste_streams SET
		        stream_code = ?, stream_name = ?, description = ?,
		        generating_process = ?, source_location = ?, source_chemical_id = ?,
		        waste_category = ?, waste_stream_type_code = ?, physical_form = ?,
		        typical_quantity_per_month = ?, quantity_unit = ?,
		        is_ignitable = ?, is_corrosive = ?, is_reactive = ?,
		        is_toxic = ?, is_acute_hazardous = ?,
		        handling_instructions = ?, ppe_required = ?, incompatible_with = ?,
		        profile_number = ?, profile_expiration = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.StreamCode, in.StreamName, in.Description,
		in.GeneratingProcess, in.SourceLocation, in.SourceChemicalID,
		in.WasteCategory, in.WasteStreamTypeCode, in.PhysicalForm,
		in.TypicalQtyPerMonth, in.QuantityUnit,
		in.IsIgnitable, in.IsCorrosive, in.IsReactive,
		in.IsToxic, in.IsAcuteHazardous,
		in.HandlingInstructions, in.PPERequired, in.IncompatibleWith,
		in.ProfileNumber, in.ProfileExpiration,
		id,
	)
}

// DeactivateWasteStream marks a waste stream as inactive.
func (r *Repo) DeactivateWasteStream(user string, id int64) error {
	return r.updateAndAudit(wasteStreamTable, wasteStreamModule, id, user,
		fmt.Sprintf("Deactivated waste stream %d", id),
		`UPDATE waste_streams SET is_active = 0, updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

// ReactivateWasteStream restores a previously deactivated waste stream.
func (r *Repo) ReactivateWasteStream(user string, id int64) error {
	return r.updateAndAudit(wasteStreamTable, wasteStreamModule, id, user,
		fmt.Sprintf("Reactivated waste stream %d", id),
		`UPDATE waste_streams SET is_active = 1, updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeleteWasteStream(user string, id int64) error {
	return r.deleteAndAudit(wasteStreamTable, wasteStreamModule, id, user,
		fmt.Sprintf("Deleted waste stream %d", id),
		`DELETE FROM waste_streams WHERE id = ?`, id,
	)
}
