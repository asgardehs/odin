package repository

import "fmt"

const chemicalInventoryModule = "chemical_inventory"
const chemicalInventoryTable = "chemical_inventory"

// ChemicalInventoryInput records a point-in-time inventory snapshot of
// a chemical at a storage location. Snapshots feed Tier II reporting,
// EHS threshold checks, and RCRA generator-status calculations.
type ChemicalInventoryInput struct {
	ChemicalID           int64    `json:"chemical_id"`
	StorageLocationID    int64    `json:"storage_location_id"`
	SnapshotDate         string   `json:"snapshot_date"`
	SnapshotType         *string  `json:"snapshot_type,omitempty"`
	Quantity             float64  `json:"quantity"`
	Unit                 string   `json:"unit"`
	QuantityLbs          *float64 `json:"quantity_lbs,omitempty"`
	ContainerType        *string  `json:"container_type,omitempty"`
	ContainerCount       *int     `json:"container_count,omitempty"`
	MaxContainerSize     *float64 `json:"max_container_size,omitempty"`
	MaxContainerSizeUnit *string  `json:"max_container_size_unit,omitempty"`
	IsTier2Max           *int     `json:"is_tier2_max,omitempty"`
	IsTier2Average       *int     `json:"is_tier2_average,omitempty"`
	RecordedBy           *string  `json:"recorded_by,omitempty"`
	Notes                *string  `json:"notes,omitempty"`
}

func (r *Repo) CreateChemicalInventory(user string, in ChemicalInventoryInput) (int64, error) {
	return r.insertAndAudit(chemicalInventoryTable, chemicalInventoryModule, user,
		fmt.Sprintf("Recorded chemical inventory for chemical %d", in.ChemicalID),
		`INSERT INTO chemical_inventory (chemical_id, storage_location_id,
		        snapshot_date, snapshot_type, quantity, unit, quantity_lbs,
		        container_type, container_count, max_container_size,
		        max_container_size_unit, is_tier2_max, is_tier2_average,
		        recorded_by, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.ChemicalID, in.StorageLocationID,
		in.SnapshotDate, in.SnapshotType, in.Quantity, in.Unit, in.QuantityLbs,
		in.ContainerType, in.ContainerCount, in.MaxContainerSize,
		in.MaxContainerSizeUnit, in.IsTier2Max, in.IsTier2Average,
		in.RecordedBy, in.Notes,
	)
}

func (r *Repo) DeleteChemicalInventory(user string, id int64) error {
	return r.deleteAndAudit(chemicalInventoryTable, chemicalInventoryModule, id, user,
		fmt.Sprintf("Deleted chemical inventory snapshot %d", id),
		`DELETE FROM chemical_inventory WHERE id = ?`, id,
	)
}
