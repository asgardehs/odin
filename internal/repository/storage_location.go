package repository

import "fmt"

const storageLocationModule = "storage_locations"
const storageLocationTable = "storage_locations"

// StorageLocationInput is the payload for creating or updating a storage
// location. These are where chemicals physically live within a facility —
// referenced by chemical_inventory snapshots for Tier II site plans.
type StorageLocationInput struct {
	EstablishmentID    int64    `json:"establishment_id"`
	Building           string   `json:"building"`
	Room               *string  `json:"room,omitempty"`
	Area               *string  `json:"area,omitempty"`
	GridReference      *string  `json:"grid_reference,omitempty"`
	Latitude           *float64 `json:"latitude,omitempty"`
	Longitude          *float64 `json:"longitude,omitempty"`
	IsIndoor           *int     `json:"is_indoor,omitempty"`
	StoragePressure    *string  `json:"storage_pressure,omitempty"`
	StorageTemperature *string  `json:"storage_temperature,omitempty"`
	ContainerTypes     *string  `json:"container_types,omitempty"`
	MaxCapacityGallons *float64 `json:"max_capacity_gallons,omitempty"`
}

func (r *Repo) CreateStorageLocation(user string, in StorageLocationInput) (int64, error) {
	return r.insertAndAudit(storageLocationTable, storageLocationModule, user,
		fmt.Sprintf("Created storage location: %s", in.Building),
		`INSERT INTO storage_locations (establishment_id, building, room, area,
		        grid_reference, latitude, longitude, is_indoor,
		        storage_pressure, storage_temperature,
		        container_types, max_capacity_gallons)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.Building, in.Room, in.Area,
		in.GridReference, in.Latitude, in.Longitude, in.IsIndoor,
		in.StoragePressure, in.StorageTemperature,
		in.ContainerTypes, in.MaxCapacityGallons,
	)
}

func (r *Repo) UpdateStorageLocation(user string, id int64, in StorageLocationInput) error {
	return r.updateAndAudit(storageLocationTable, storageLocationModule, id, user,
		fmt.Sprintf("Updated storage location: %s", in.Building),
		`UPDATE storage_locations SET
		        building = ?, room = ?, area = ?,
		        grid_reference = ?, latitude = ?, longitude = ?, is_indoor = ?,
		        storage_pressure = ?, storage_temperature = ?,
		        container_types = ?, max_capacity_gallons = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.Building, in.Room, in.Area,
		in.GridReference, in.Latitude, in.Longitude, in.IsIndoor,
		in.StoragePressure, in.StorageTemperature,
		in.ContainerTypes, in.MaxCapacityGallons,
		id,
	)
}

// DeactivateStorageLocation hides a location from active selectors.
// Historical inventory snapshots remain intact.
func (r *Repo) DeactivateStorageLocation(user string, id int64) error {
	return r.updateAndAudit(storageLocationTable, storageLocationModule, id, user,
		fmt.Sprintf("Deactivated storage location %d", id),
		`UPDATE storage_locations SET is_active = 0, updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) ReactivateStorageLocation(user string, id int64) error {
	return r.updateAndAudit(storageLocationTable, storageLocationModule, id, user,
		fmt.Sprintf("Reactivated storage location %d", id),
		`UPDATE storage_locations SET is_active = 1, updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeleteStorageLocation(user string, id int64) error {
	return r.deleteAndAudit(storageLocationTable, storageLocationModule, id, user,
		fmt.Sprintf("Deleted storage location %d", id),
		`DELETE FROM storage_locations WHERE id = ?`, id,
	)
}
