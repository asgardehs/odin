package importer

import (
	"fmt"
	"regexp"
	"strings"
	"time"
)

// Employees is the Importer for the employees table. Register at init so
// the engine can find it via Get("employees").
type employeesImporter struct{}

func init() {
	Register(&employeesImporter{})
}

func (*employeesImporter) ModuleSlug() string { return "employees" }

func (*employeesImporter) TargetFields() []TargetField {
	return []TargetField{
		{Name: "employee_number", Label: "Employee Number", Aliases: []string{"emp id", "emp number", "badge", "payroll id", "id"}, Description: "Unique identifier in the facility's payroll or badge system."},
		{Name: "first_name", Label: "First Name", Required: true, Aliases: []string{"fname", "given name"}},
		{Name: "last_name", Label: "Last Name", Required: true, Aliases: []string{"lname", "surname", "family name"}},
		{Name: "job_title", Label: "Job Title", Aliases: []string{"title", "position", "role"}},
		{Name: "department", Label: "Department", Aliases: []string{"dept", "division", "group"}},
		{Name: "supervisor_name", Label: "Supervisor", Aliases: []string{"manager", "reports to"}},
		{Name: "date_hired", Label: "Hire Date", Aliases: []string{"hire dt", "start date", "started", "hired", "employment start"}, Description: "ISO 8601 format (YYYY-MM-DD) preferred. Common variants accepted."},
		{Name: "date_of_birth", Label: "Date of Birth", Aliases: []string{"dob", "birth date", "birthday"}, Description: "Required for OSHA 301 incident reporting."},
		{Name: "gender", Label: "Gender", Aliases: []string{"sex"}, Description: "M, F, or X (OSHA reporting codes)."},
		{Name: "street_address", Label: "Street Address", Aliases: []string{"address", "street", "address line 1"}},
		{Name: "city", Label: "City", Aliases: []string{"town"}},
		{Name: "state", Label: "State", Aliases: []string{"state code", "province"}, Description: "Two-letter USPS code (e.g. IL, CA)."},
		{Name: "zip", Label: "ZIP Code", Aliases: []string{"zip code", "postal code", "postcode"}},
	}
}

type employeePayload struct {
	EstablishmentID int64
	EmployeeNumber  *string
	FirstName       string
	LastName        string
	StreetAddress   *string
	City            *string
	State           *string
	Zip             *string
	DateOfBirth     *string
	DateHired       *string
	Gender          *string
	JobTitle        *string
	Department      *string
	SupervisorName  *string
}

func (*employeesImporter) ValidateRow(
	raw map[string]string,
	mapping map[string]string,
	rowIdx int,
	ctx RowContext,
) (any, []ValidationError) {
	var errs []ValidationError

	if ctx.EstablishmentID == nil {
		errs = append(errs, ValidationError{Row: rowIdx, Message: "target establishment not set on the import"})
		return nil, errs
	}

	// Invert the mapping once so we can pull target-field values directly.
	resolve := func(target string) string {
		for src, dst := range mapping {
			if dst == target {
				return strings.TrimSpace(raw[src])
			}
		}
		return ""
	}

	first := resolve("first_name")
	last := resolve("last_name")
	if first == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "first_name", Message: "First Name is required"})
	}
	if last == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "last_name", Message: "Last Name is required"})
	}

	p := &employeePayload{
		EstablishmentID: *ctx.EstablishmentID,
		FirstName:       first,
		LastName:        last,
	}

	setIfNonEmpty(&p.EmployeeNumber, resolve("employee_number"))
	setIfNonEmpty(&p.StreetAddress, resolve("street_address"))
	setIfNonEmpty(&p.City, resolve("city"))
	setIfNonEmpty(&p.SupervisorName, resolve("supervisor_name"))
	setIfNonEmpty(&p.JobTitle, resolve("job_title"))
	setIfNonEmpty(&p.Department, resolve("department"))

	if v := resolve("state"); v != "" {
		st := strings.ToUpper(v)
		if !isTwoLetterCode(st) {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "state", Message: "State must be a two-letter code (e.g. IL, CA)"})
		} else {
			p.State = &st
		}
	}

	if v := resolve("zip"); v != "" {
		if !zipPattern.MatchString(v) {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "zip", Message: "ZIP must be 5 digits or 5+4"})
		} else {
			p.Zip = &v
		}
	}

	if v := resolve("gender"); v != "" {
		g := strings.ToUpper(v)
		switch g {
		case "M", "F", "X", "MALE", "FEMALE":
			if g == "MALE" {
				g = "M"
			}
			if g == "FEMALE" {
				g = "F"
			}
			p.Gender = &g
		default:
			errs = append(errs, ValidationError{Row: rowIdx, Column: "gender", Message: "Gender must be M, F, or X"})
		}
	}

	if iso, ok, msg := parseDate(resolve("date_hired")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "date_hired", Message: msg})
	} else if ok {
		p.DateHired = &iso
	}
	if iso, ok, msg := parseDate(resolve("date_of_birth")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "date_of_birth", Message: msg})
	} else if ok {
		p.DateOfBirth = &iso
	}

	if len(errs) > 0 {
		return nil, errs
	}
	return p, nil
}

func (*employeesImporter) InsertRow(db Execer, payload any, ctx RowContext) (int64, error) {
	p, ok := payload.(*employeePayload)
	if !ok {
		return 0, fmt.Errorf("employees: wrong payload type %T", payload)
	}
	if err := db.ExecParams(
		`INSERT INTO employees (
		     establishment_id, employee_number, first_name, last_name,
		     street_address, city, state, zip,
		     date_of_birth, date_hired, gender,
		     job_title, department, supervisor_name)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		p.EstablishmentID, p.EmployeeNumber, p.FirstName, p.LastName,
		p.StreetAddress, p.City, p.State, p.Zip,
		p.DateOfBirth, p.DateHired, p.Gender,
		p.JobTitle, p.Department, p.SupervisorName,
	); err != nil {
		return 0, err
	}
	id, err := db.QueryVal("SELECT last_insert_rowid()")
	if err != nil {
		return 0, err
	}
	return id.(int64), nil
}

// ---- helpers --------------------------------------------------------------

var zipPattern = regexp.MustCompile(`^\d{5}(-\d{4})?$`)

func setIfNonEmpty(dst **string, v string) {
	v = strings.TrimSpace(v)
	if v == "" {
		return
	}
	*dst = &v
}

func isTwoLetterCode(s string) bool {
	if len(s) != 2 {
		return false
	}
	for _, r := range s {
		if r < 'A' || r > 'Z' {
			return false
		}
	}
	return true
}

// parseDate accepts ISO 8601 + a handful of common US formats. Returns
// (isoFormatted, true, "") on success, ("", false, "") if blank, and
// ("", false, error-message) on parse failure. Keeping this tolerant
// matters — most real-world employee CSVs come from Excel.
var dateFormats = []string{
	"2006-01-02",
	"2006/01/02",
	"01/02/2006",
	"1/2/2006",
	"01-02-2006",
	"1-2-2006",
	"02 Jan 2006",
	"January 2, 2006",
	"Jan 2, 2006",
}

func parseDate(v string) (iso string, ok bool, msg string) {
	v = strings.TrimSpace(v)
	if v == "" {
		return "", false, ""
	}
	for _, f := range dateFormats {
		if t, err := time.Parse(f, v); err == nil {
			return t.Format("2006-01-02"), true, ""
		}
	}
	return "", false, fmt.Sprintf("Date %q is not in a recognized format (try YYYY-MM-DD or MM/DD/YYYY)", v)
}
