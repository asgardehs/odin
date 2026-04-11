package repository

import "fmt"

const ppeItemModule = "ppe_items"
const ppeItemTable = "ppe_items"
const ppeAssignmentModule = "ppe_assignments"
const ppeAssignmentTable = "ppe_assignments"
const ppeInspectionModule = "ppe_inspections"
const ppeInspectionTable = "ppe_inspections"

// PPEItemInput is the payload for creating or updating a PPE item.
type PPEItemInput struct {
	EstablishmentID int64    `json:"establishment_id"`
	PPETypeID       int64    `json:"ppe_type_id"`
	SerialNumber    *string  `json:"serial_number,omitempty"`
	AssetTag        *string  `json:"asset_tag,omitempty"`
	Manufacturer    *string  `json:"manufacturer,omitempty"`
	Model           *string  `json:"model,omitempty"`
	Size            *string  `json:"size,omitempty"`
	ManufactureDate *string  `json:"manufacture_date,omitempty"`
	PurchaseDate    *string  `json:"purchase_date,omitempty"`
	InServiceDate   *string  `json:"in_service_date,omitempty"`
	ExpirationDate  *string  `json:"expiration_date,omitempty"`
	PurchaseOrder   *string  `json:"purchase_order,omitempty"`
	PurchaseCost    *float64 `json:"purchase_cost,omitempty"`
	Vendor          *string  `json:"vendor,omitempty"`
}

func (r *Repo) CreatePPEItem(user string, in PPEItemInput) (int64, error) {
	return r.insertAndAudit(ppeItemTable, ppeItemModule, user,
		fmt.Sprintf("Created PPE item (type %d)", in.PPETypeID),
		`INSERT INTO ppe_items (establishment_id, ppe_type_id, serial_number, asset_tag,
		        manufacturer, model, size,
		        manufacture_date, purchase_date, in_service_date, expiration_date,
		        purchase_order, purchase_cost, vendor)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.PPETypeID, in.SerialNumber, in.AssetTag,
		in.Manufacturer, in.Model, in.Size,
		in.ManufactureDate, in.PurchaseDate, in.InServiceDate, in.ExpirationDate,
		in.PurchaseOrder, in.PurchaseCost, in.Vendor,
	)
}

func (r *Repo) UpdatePPEItem(user string, id int64, in PPEItemInput) error {
	return r.updateAndAudit(ppeItemTable, ppeItemModule, id, user,
		fmt.Sprintf("Updated PPE item %d", id),
		`UPDATE ppe_items SET
		        ppe_type_id = ?, serial_number = ?, asset_tag = ?,
		        manufacturer = ?, model = ?, size = ?,
		        manufacture_date = ?, purchase_date = ?, in_service_date = ?,
		        expiration_date = ?, purchase_order = ?, purchase_cost = ?, vendor = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.PPETypeID, in.SerialNumber, in.AssetTag,
		in.Manufacturer, in.Model, in.Size,
		in.ManufactureDate, in.PurchaseDate, in.InServiceDate,
		in.ExpirationDate, in.PurchaseOrder, in.PurchaseCost, in.Vendor,
		id,
	)
}

// RetirePPEItem marks a PPE item as retired.
func (r *Repo) RetirePPEItem(user string, id int64) error {
	return r.updateAndAudit(ppeItemTable, ppeItemModule, id, user,
		fmt.Sprintf("Retired PPE item %d", id),
		`UPDATE ppe_items SET status = 'retired', updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeletePPEItem(user string, id int64) error {
	return r.deleteAndAudit(ppeItemTable, ppeItemModule, id, user,
		fmt.Sprintf("Deleted PPE item %d", id),
		`DELETE FROM ppe_items WHERE id = ?`, id,
	)
}

// PPEAssignmentInput is the payload for assigning PPE to an employee.
type PPEAssignmentInput struct {
	PPEItemID              int64   `json:"ppe_item_id"`
	EmployeeID             int64   `json:"employee_id"`
	AssignedDate           string  `json:"assigned_date"`
	AssignedByEmployeeID   *int64  `json:"assigned_by_employee_id,omitempty"`
	Notes                  *string `json:"notes,omitempty"`
}

func (r *Repo) CreatePPEAssignment(user string, in PPEAssignmentInput) (int64, error) {
	return r.insertAndAudit(ppeAssignmentTable, ppeAssignmentModule, user,
		fmt.Sprintf("Assigned PPE item %d to employee %d", in.PPEItemID, in.EmployeeID),
		`INSERT INTO ppe_assignments (ppe_item_id, employee_id, assigned_date,
		        assigned_by_employee_id, notes)
		 VALUES (?, ?, ?, ?, ?)`,
		in.PPEItemID, in.EmployeeID, in.AssignedDate,
		in.AssignedByEmployeeID, in.Notes,
	)
}

// ReturnPPEAssignment records a PPE item being returned.
func (r *Repo) ReturnPPEAssignment(user string, id int64, condition string, notes string) error {
	return r.updateAndAudit(ppeAssignmentTable, ppeAssignmentModule, id, user,
		fmt.Sprintf("Returned PPE assignment %d (condition: %s)", id, condition),
		`UPDATE ppe_assignments SET returned_date = date('now'),
		        returned_condition = ?, return_notes = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`, condition, notes, id,
	)
}

func (r *Repo) DeletePPEAssignment(user string, id int64) error {
	return r.deleteAndAudit(ppeAssignmentTable, ppeAssignmentModule, id, user,
		fmt.Sprintf("Deleted PPE assignment %d", id),
		`DELETE FROM ppe_assignments WHERE id = ?`, id,
	)
}

// PPEInspectionInput is the payload for recording a PPE inspection.
type PPEInspectionInput struct {
	PPEItemID              int64   `json:"ppe_item_id"`
	InspectionDate         string  `json:"inspection_date"`
	InspectedByEmployeeID  int64   `json:"inspected_by_employee_id"`
	Passed                 int     `json:"passed"`
	Condition              *string `json:"condition,omitempty"`
	ChecklistResults       *string `json:"checklist_results,omitempty"`
	IssuesFound            *string `json:"issues_found,omitempty"`
	CorrectiveAction       *string `json:"corrective_action,omitempty"`
	NextInspectionDue      *string `json:"next_inspection_due,omitempty"`
	RemovedFromService     *int    `json:"removed_from_service,omitempty"`
	RemovalReason          *string `json:"removal_reason,omitempty"`
	Notes                  *string `json:"notes,omitempty"`
}

func (r *Repo) CreatePPEInspection(user string, in PPEInspectionInput) (int64, error) {
	result := "PASS"
	if in.Passed == 0 {
		result = "FAIL"
	}
	return r.insertAndAudit(ppeInspectionTable, ppeInspectionModule, user,
		fmt.Sprintf("Inspected PPE item %d: %s", in.PPEItemID, result),
		`INSERT INTO ppe_inspections (ppe_item_id, inspection_date, inspected_by_employee_id,
		        passed, condition, checklist_results, issues_found, corrective_action,
		        next_inspection_due, removed_from_service, removal_reason, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.PPEItemID, in.InspectionDate, in.InspectedByEmployeeID,
		in.Passed, in.Condition, in.ChecklistResults, in.IssuesFound, in.CorrectiveAction,
		in.NextInspectionDue, in.RemovedFromService, in.RemovalReason, in.Notes,
	)
}

func (r *Repo) DeletePPEInspection(user string, id int64) error {
	return r.deleteAndAudit(ppeInspectionTable, ppeInspectionModule, id, user,
		fmt.Sprintf("Deleted PPE inspection %d", id),
		`DELETE FROM ppe_inspections WHERE id = ?`, id,
	)
}
