package repository

import "fmt"

const chemicalModule = "chemicals"
const chemicalTable = "chemicals"

// ChemicalInput is the payload for creating or updating a chemical.
// Covers the identification, GHS classification, regulatory flags,
// and physical properties needed for EPCRA compliance.
type ChemicalInput struct {
	EstablishmentID int64   `json:"establishment_id"`
	ProductName     string  `json:"product_name"`
	Manufacturer    *string `json:"manufacturer,omitempty"`
	ManufacturerPh  *string `json:"manufacturer_phone,omitempty"`
	PrimaryCAS      *string `json:"primary_cas_number,omitempty"`

	// GHS classification
	SignalWord *string `json:"signal_word,omitempty"`

	// Physical hazards
	IsFlammable      *int `json:"is_flammable,omitempty"`
	IsOxidizer       *int `json:"is_oxidizer,omitempty"`
	IsExplosive      *int `json:"is_explosive,omitempty"`
	IsCorrosiveToMtl *int `json:"is_corrosive_to_metal,omitempty"`
	IsGasUnderPress  *int `json:"is_gas_under_pressure,omitempty"`

	// Health hazards
	IsAcuteToxic *int `json:"is_acute_toxic,omitempty"`
	IsCarcinogen *int `json:"is_carcinogen,omitempty"`
	IsSkinCorr   *int `json:"is_skin_corrosion,omitempty"`
	IsEyeDamage  *int `json:"is_eye_damage,omitempty"`
	IsRespSensit *int `json:"is_respiratory_sensitizer,omitempty"`

	// Regulatory
	IsEHS      *int     `json:"is_ehs,omitempty"`
	EhsTPQ     *float64 `json:"ehs_tpq_lbs,omitempty"`
	EhsRQ      *float64 `json:"ehs_rq_lbs,omitempty"`
	IsSara313  *int     `json:"is_sara_313,omitempty"`
	Sara313Cat *string  `json:"sara_313_category,omitempty"`
	IsPBT      *int     `json:"is_pbt,omitempty"`

	// Physical properties
	PhysicalState *string  `json:"physical_state,omitempty"`
	FlashPointF   *float64 `json:"flash_point_f,omitempty"`

	// Storage
	StorageRequirements   *string `json:"storage_requirements,omitempty"`
	IncompatibleMaterials *string `json:"incompatible_materials,omitempty"`
	PPERequired           *string `json:"ppe_required,omitempty"`
}

func (r *Repo) CreateChemical(user string, in ChemicalInput) (int64, error) {
	return r.insertAndAudit(chemicalTable, chemicalModule, user,
		fmt.Sprintf("Created chemical: %s", in.ProductName),
		`INSERT INTO chemicals (establishment_id, product_name, manufacturer,
		        manufacturer_phone, primary_cas_number, signal_word,
		        is_flammable, is_oxidizer, is_explosive,
		        is_corrosive_to_metal, is_gas_under_pressure,
		        is_acute_toxic, is_carcinogen, is_skin_corrosion,
		        is_eye_damage, is_respiratory_sensitizer,
		        is_ehs, ehs_tpq_lbs, ehs_rq_lbs,
		        is_sara_313, sara_313_category, is_pbt,
		        physical_state, flash_point_f,
		        storage_requirements, incompatible_materials, ppe_required)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.ProductName, in.Manufacturer,
		in.ManufacturerPh, in.PrimaryCAS, in.SignalWord,
		in.IsFlammable, in.IsOxidizer, in.IsExplosive,
		in.IsCorrosiveToMtl, in.IsGasUnderPress,
		in.IsAcuteToxic, in.IsCarcinogen, in.IsSkinCorr,
		in.IsEyeDamage, in.IsRespSensit,
		in.IsEHS, in.EhsTPQ, in.EhsRQ,
		in.IsSara313, in.Sara313Cat, in.IsPBT,
		in.PhysicalState, in.FlashPointF,
		in.StorageRequirements, in.IncompatibleMaterials, in.PPERequired,
	)
}

func (r *Repo) UpdateChemical(user string, id int64, in ChemicalInput) error {
	return r.updateAndAudit(chemicalTable, chemicalModule, id, user,
		fmt.Sprintf("Updated chemical: %s", in.ProductName),
		`UPDATE chemicals SET
		        product_name = ?, manufacturer = ?, manufacturer_phone = ?,
		        primary_cas_number = ?, signal_word = ?,
		        is_flammable = ?, is_oxidizer = ?, is_explosive = ?,
		        is_corrosive_to_metal = ?, is_gas_under_pressure = ?,
		        is_acute_toxic = ?, is_carcinogen = ?, is_skin_corrosion = ?,
		        is_eye_damage = ?, is_respiratory_sensitizer = ?,
		        is_ehs = ?, ehs_tpq_lbs = ?, ehs_rq_lbs = ?,
		        is_sara_313 = ?, sara_313_category = ?, is_pbt = ?,
		        physical_state = ?, flash_point_f = ?,
		        storage_requirements = ?, incompatible_materials = ?, ppe_required = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.ProductName, in.Manufacturer, in.ManufacturerPh,
		in.PrimaryCAS, in.SignalWord,
		in.IsFlammable, in.IsOxidizer, in.IsExplosive,
		in.IsCorrosiveToMtl, in.IsGasUnderPress,
		in.IsAcuteToxic, in.IsCarcinogen, in.IsSkinCorr,
		in.IsEyeDamage, in.IsRespSensit,
		in.IsEHS, in.EhsTPQ, in.EhsRQ,
		in.IsSara313, in.Sara313Cat, in.IsPBT,
		in.PhysicalState, in.FlashPointF,
		in.StorageRequirements, in.IncompatibleMaterials, in.PPERequired,
		id,
	)
}

// DiscontinueChemical marks a chemical as inactive with a reason.
func (r *Repo) DiscontinueChemical(user string, id int64, reason string) error {
	return r.updateAndAudit(chemicalTable, chemicalModule, id, user,
		fmt.Sprintf("Discontinued chemical %d: %s", id, reason),
		`UPDATE chemicals SET is_active = 0, discontinued_date = date('now'),
		        discontinued_reason = ?, updated_at = datetime('now')
		 WHERE id = ?`, reason, id,
	)
}

// ReactivateChemical restores a discontinued chemical, clearing the
// discontinued_date and discontinued_reason fields.
func (r *Repo) ReactivateChemical(user string, id int64) error {
	return r.updateAndAudit(chemicalTable, chemicalModule, id, user,
		fmt.Sprintf("Reactivated chemical %d", id),
		`UPDATE chemicals SET is_active = 1, discontinued_date = NULL,
		        discontinued_reason = NULL, updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeleteChemical(user string, id int64) error {
	return r.deleteAndAudit(chemicalTable, chemicalModule, id, user,
		fmt.Sprintf("Deleted chemical %d", id),
		`DELETE FROM chemicals WHERE id = ?`, id,
	)
}
