package repository

import "fmt"

const chemicalModule = "chemicals"
const chemicalTable = "chemicals"

// ChemicalInput is the payload for creating or updating a chemical.
// Covers the identification, full GHS classification (physical / health /
// environmental), physical properties, regulatory flags, and storage
// handling data needed for EPCRA, SARA Title III, and TRI reporting.
type ChemicalInput struct {
	EstablishmentID int64   `json:"establishment_id"`
	ProductName     string  `json:"product_name"`
	Manufacturer    *string `json:"manufacturer,omitempty"`
	ManufacturerPh  *string `json:"manufacturer_phone,omitempty"`
	PrimaryCAS      *string `json:"primary_cas_number,omitempty"`

	// GHS classification
	SignalWord *string `json:"signal_word,omitempty"` // 'Danger', 'Warning', or NULL

	// Physical hazards
	IsFlammable       *int `json:"is_flammable,omitempty"`
	IsOxidizer        *int `json:"is_oxidizer,omitempty"`
	IsExplosive       *int `json:"is_explosive,omitempty"`
	IsSelfReactive    *int `json:"is_self_reactive,omitempty"`
	IsPyrophoric      *int `json:"is_pyrophoric,omitempty"`
	IsSelfHeating     *int `json:"is_self_heating,omitempty"`
	IsOrganicPeroxide *int `json:"is_organic_peroxide,omitempty"`
	IsCorrosiveToMtl  *int `json:"is_corrosive_to_metal,omitempty"`
	IsGasUnderPress   *int `json:"is_gas_under_pressure,omitempty"`
	IsWaterReactive   *int `json:"is_water_reactive,omitempty"`

	// Health hazards
	IsAcuteToxic        *int `json:"is_acute_toxic,omitempty"`
	IsSkinCorr          *int `json:"is_skin_corrosion,omitempty"`
	IsEyeDamage         *int `json:"is_eye_damage,omitempty"`
	IsSkinSensitizer    *int `json:"is_skin_sensitizer,omitempty"`
	IsRespSensit        *int `json:"is_respiratory_sensitizer,omitempty"`
	IsGermCellMutagen   *int `json:"is_germ_cell_mutagen,omitempty"`
	IsCarcinogen        *int `json:"is_carcinogen,omitempty"`
	IsReproductiveToxin *int `json:"is_reproductive_toxin,omitempty"`
	IsTargetOrganSingle *int `json:"is_target_organ_single,omitempty"`
	IsTargetOrganRepeat *int `json:"is_target_organ_repeat,omitempty"`
	IsAspirationHazard  *int `json:"is_aspiration_hazard,omitempty"`

	// Environmental hazards
	IsAquaticToxic *int `json:"is_aquatic_toxic,omitempty"`

	// Regulatory
	IsEHS      *int     `json:"is_ehs,omitempty"`
	EhsTPQ     *float64 `json:"ehs_tpq_lbs,omitempty"`
	EhsRQ      *float64 `json:"ehs_rq_lbs,omitempty"`
	IsSara313  *int     `json:"is_sara_313,omitempty"`
	Sara313Cat *string  `json:"sara_313_category,omitempty"`
	IsPBT      *int     `json:"is_pbt,omitempty"`

	// Physical properties
	PhysicalState   *string  `json:"physical_state,omitempty"` // 'solid', 'liquid', 'gas'
	SpecificGravity *float64 `json:"specific_gravity,omitempty"`
	VaporPressure   *float64 `json:"vapor_pressure_mmhg,omitempty"`
	FlashPointF     *float64 `json:"flash_point_f,omitempty"`
	PH              *float64 `json:"ph,omitempty"`
	Appearance      *string  `json:"appearance,omitempty"`
	Odor            *string  `json:"odor,omitempty"`

	// Storage and handling
	StorageRequirements   *string `json:"storage_requirements,omitempty"`
	IncompatibleMaterials *string `json:"incompatible_materials,omitempty"`
	PPERequired           *string `json:"ppe_required,omitempty"`
}

func (r *Repo) CreateChemical(user string, in ChemicalInput) (int64, error) {
	return r.insertAndAudit(chemicalTable, chemicalModule, user,
		fmt.Sprintf("Created chemical: %s", in.ProductName),
		`INSERT INTO chemicals (establishment_id, product_name, manufacturer,
		        manufacturer_phone, primary_cas_number, signal_word,
		        is_flammable, is_oxidizer, is_explosive, is_self_reactive,
		        is_pyrophoric, is_self_heating, is_organic_peroxide,
		        is_corrosive_to_metal, is_gas_under_pressure, is_water_reactive,
		        is_acute_toxic, is_skin_corrosion, is_eye_damage,
		        is_skin_sensitizer, is_respiratory_sensitizer,
		        is_germ_cell_mutagen, is_carcinogen, is_reproductive_toxin,
		        is_target_organ_single, is_target_organ_repeat,
		        is_aspiration_hazard, is_aquatic_toxic,
		        is_ehs, ehs_tpq_lbs, ehs_rq_lbs,
		        is_sara_313, sara_313_category, is_pbt,
		        physical_state, specific_gravity, vapor_pressure_mmhg,
		        flash_point_f, ph, appearance, odor,
		        storage_requirements, incompatible_materials, ppe_required)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
		         ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
		         ?, ?, ?)`,
		in.EstablishmentID, in.ProductName, in.Manufacturer,
		in.ManufacturerPh, in.PrimaryCAS, in.SignalWord,
		in.IsFlammable, in.IsOxidizer, in.IsExplosive, in.IsSelfReactive,
		in.IsPyrophoric, in.IsSelfHeating, in.IsOrganicPeroxide,
		in.IsCorrosiveToMtl, in.IsGasUnderPress, in.IsWaterReactive,
		in.IsAcuteToxic, in.IsSkinCorr, in.IsEyeDamage,
		in.IsSkinSensitizer, in.IsRespSensit,
		in.IsGermCellMutagen, in.IsCarcinogen, in.IsReproductiveToxin,
		in.IsTargetOrganSingle, in.IsTargetOrganRepeat,
		in.IsAspirationHazard, in.IsAquaticToxic,
		in.IsEHS, in.EhsTPQ, in.EhsRQ,
		in.IsSara313, in.Sara313Cat, in.IsPBT,
		in.PhysicalState, in.SpecificGravity, in.VaporPressure,
		in.FlashPointF, in.PH, in.Appearance, in.Odor,
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
		        is_self_reactive = ?, is_pyrophoric = ?, is_self_heating = ?,
		        is_organic_peroxide = ?, is_corrosive_to_metal = ?,
		        is_gas_under_pressure = ?, is_water_reactive = ?,
		        is_acute_toxic = ?, is_skin_corrosion = ?, is_eye_damage = ?,
		        is_skin_sensitizer = ?, is_respiratory_sensitizer = ?,
		        is_germ_cell_mutagen = ?, is_carcinogen = ?,
		        is_reproductive_toxin = ?, is_target_organ_single = ?,
		        is_target_organ_repeat = ?, is_aspiration_hazard = ?,
		        is_aquatic_toxic = ?,
		        is_ehs = ?, ehs_tpq_lbs = ?, ehs_rq_lbs = ?,
		        is_sara_313 = ?, sara_313_category = ?, is_pbt = ?,
		        physical_state = ?, specific_gravity = ?, vapor_pressure_mmhg = ?,
		        flash_point_f = ?, ph = ?, appearance = ?, odor = ?,
		        storage_requirements = ?, incompatible_materials = ?, ppe_required = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.ProductName, in.Manufacturer, in.ManufacturerPh,
		in.PrimaryCAS, in.SignalWord,
		in.IsFlammable, in.IsOxidizer, in.IsExplosive,
		in.IsSelfReactive, in.IsPyrophoric, in.IsSelfHeating,
		in.IsOrganicPeroxide, in.IsCorrosiveToMtl,
		in.IsGasUnderPress, in.IsWaterReactive,
		in.IsAcuteToxic, in.IsSkinCorr, in.IsEyeDamage,
		in.IsSkinSensitizer, in.IsRespSensit,
		in.IsGermCellMutagen, in.IsCarcinogen,
		in.IsReproductiveToxin, in.IsTargetOrganSingle,
		in.IsTargetOrganRepeat, in.IsAspirationHazard,
		in.IsAquaticToxic,
		in.IsEHS, in.EhsTPQ, in.EhsRQ,
		in.IsSara313, in.Sara313Cat, in.IsPBT,
		in.PhysicalState, in.SpecificGravity, in.VaporPressure,
		in.FlashPointF, in.PH, in.Appearance, in.Odor,
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
