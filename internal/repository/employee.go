package repository

import "fmt"

const employeeModule = "employees"
const employeeTable = "employees"

// EmployeeInput is the payload for creating or updating an employee.
type EmployeeInput struct {
	EstablishmentID int64   `json:"establishment_id"`
	EmployeeNumber  *string `json:"employee_number,omitempty"`
	FirstName       string  `json:"first_name"`
	LastName        string  `json:"last_name"`
	StreetAddress   *string `json:"street_address,omitempty"`
	City            *string `json:"city,omitempty"`
	State           *string `json:"state,omitempty"`
	Zip             *string `json:"zip,omitempty"`
	DateOfBirth     *string `json:"date_of_birth,omitempty"`
	DateHired       *string `json:"date_hired,omitempty"`
	Gender          *string `json:"gender,omitempty"`
	JobTitle        *string `json:"job_title,omitempty"`
	Department      *string `json:"department,omitempty"`
	SupervisorName  *string `json:"supervisor_name,omitempty"`
}

func (r *Repo) CreateEmployee(user string, in EmployeeInput) (int64, error) {
	return r.insertAndAudit(employeeTable, employeeModule, user,
		fmt.Sprintf("Created employee: %s %s", in.FirstName, in.LastName),
		`INSERT INTO employees (establishment_id, employee_number, first_name, last_name,
		        street_address, city, state, zip, date_of_birth, date_hired,
		        gender, job_title, department, supervisor_name)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.EmployeeNumber, in.FirstName, in.LastName,
		in.StreetAddress, in.City, in.State, in.Zip, in.DateOfBirth, in.DateHired,
		in.Gender, in.JobTitle, in.Department, in.SupervisorName,
	)
}

func (r *Repo) UpdateEmployee(user string, id int64, in EmployeeInput) error {
	return r.updateAndAudit(employeeTable, employeeModule, id, user,
		fmt.Sprintf("Updated employee: %s %s", in.FirstName, in.LastName),
		`UPDATE employees SET
		        establishment_id = ?, employee_number = ?, first_name = ?, last_name = ?,
		        street_address = ?, city = ?, state = ?, zip = ?,
		        date_of_birth = ?, date_hired = ?, gender = ?,
		        job_title = ?, department = ?, supervisor_name = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.EstablishmentID, in.EmployeeNumber, in.FirstName, in.LastName,
		in.StreetAddress, in.City, in.State, in.Zip, in.DateOfBirth, in.DateHired,
		in.Gender, in.JobTitle, in.Department, in.SupervisorName,
		id,
	)
}

func (r *Repo) DeactivateEmployee(user string, id int64) error {
	return r.updateAndAudit(employeeTable, employeeModule, id, user,
		fmt.Sprintf("Deactivated employee %d", id),
		`UPDATE employees SET is_active = 0, termination_date = date('now'),
		        updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeleteEmployee(user string, id int64) error {
	return r.deleteAndAudit(employeeTable, employeeModule, id, user,
		fmt.Sprintf("Deleted employee %d", id),
		`DELETE FROM employees WHERE id = ?`, id,
	)
}
