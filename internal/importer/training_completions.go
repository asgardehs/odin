package importer

import (
	"fmt"
	"strings"
)

// trainingCompletionsImporter handles bulk import of training-completion
// records. Unlike employees + chemicals, the record's two FKs
// (employee_id, course_id) are usually referenced by lookup strings in
// the source CSV — employee number + course code — so this mapper does
// DB lookups during validation via ctx.DB.
type trainingCompletionsImporter struct{}

func init() {
	Register(&trainingCompletionsImporter{})
}

func (*trainingCompletionsImporter) ModuleSlug() string { return "training_completions" }

func (*trainingCompletionsImporter) TargetFields() []TargetField {
	return []TargetField{
		{Name: "employee_number", Label: "Employee Number", Required: true, Aliases: []string{"emp id", "emp number", "badge", "payroll id"}, Description: "Looked up against employees.employee_number in the target facility."},
		{Name: "course_code", Label: "Course Code", Required: true, Aliases: []string{"course", "course id", "training code", "code"}, Description: "Looked up against training_courses.course_code in the target facility."},
		{Name: "completion_date", Label: "Completion Date", Required: true, Aliases: []string{"completed", "date", "date completed", "training date"}, Description: "YYYY-MM-DD preferred; common variants accepted."},
		{Name: "expiration_date", Label: "Expiration Date", Aliases: []string{"expires", "retraining due", "due date"}},
		{Name: "score", Label: "Score", Aliases: []string{"test score", "grade", "result"}},
		{Name: "passed", Label: "Passed?", Aliases: []string{"pass", "p/f", "pass fail"}, Description: "Y/N, true/false, or 1/0. Defaults to Y if blank."},
		{Name: "instructor", Label: "Instructor", Aliases: []string{"trainer", "teacher", "delivered by"}},
		{Name: "delivery_method", Label: "Delivery Method", Aliases: []string{"method", "format", "medium"}, Description: "e.g. classroom, online, on-the-job."},
		{Name: "location", Label: "Location", Aliases: []string{"where", "venue"}},
		{Name: "certificate_number", Label: "Certificate Number", Aliases: []string{"cert", "cert number", "certificate"}},
		{Name: "notes", Label: "Notes", Aliases: []string{"comments", "remarks"}},
	}
}

type trainingCompletionPayload struct {
	EmployeeID        int64
	CourseID          int64
	CompletionDate    string
	ExpirationDate    *string
	Score             *float64
	Passed            int
	Instructor        *string
	DeliveryMethod    *string
	Location          *string
	CertificateNumber *string
	Notes             *string
}

func (*trainingCompletionsImporter) ValidateRow(
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
	if ctx.DB == nil {
		errs = append(errs, ValidationError{Row: rowIdx, Message: "database handle not available for FK lookups"})
		return nil, errs
	}

	resolve := func(target string) string {
		for src, dst := range mapping {
			if dst == target {
				return strings.TrimSpace(raw[src])
			}
		}
		return ""
	}

	p := &trainingCompletionPayload{Passed: 1} // passed defaults to 1 per schema

	empNum := resolve("employee_number")
	if empNum == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "employee_number", Message: "Employee Number is required"})
	} else {
		id, err := ctx.DB.QueryVal(
			`SELECT id FROM employees WHERE establishment_id = ? AND employee_number = ?`,
			*ctx.EstablishmentID, empNum,
		)
		if err != nil || id == nil {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "employee_number", Message: fmt.Sprintf("No employee with employee_number %q at the target facility", empNum)})
		} else {
			p.EmployeeID = id.(int64)
		}
	}

	courseCode := resolve("course_code")
	if courseCode == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "course_code", Message: "Course Code is required"})
	} else {
		id, err := ctx.DB.QueryVal(
			`SELECT id FROM training_courses WHERE establishment_id = ? AND course_code = ?`,
			*ctx.EstablishmentID, courseCode,
		)
		if err != nil || id == nil {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "course_code", Message: fmt.Sprintf("No training course with course_code %q at the target facility", courseCode)})
		} else {
			p.CourseID = id.(int64)
		}
	}

	if v := resolve("completion_date"); v == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "completion_date", Message: "Completion Date is required"})
	} else if iso, ok, msg := parseDate(v); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "completion_date", Message: msg})
	} else if ok {
		p.CompletionDate = iso
	}

	if iso, ok, msg := parseDate(resolve("expiration_date")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "expiration_date", Message: msg})
	} else if ok {
		p.ExpirationDate = &iso
	}

	if v, ok, msg := parseFloat(resolve("score")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "score", Message: msg})
	} else if ok {
		p.Score = &v
	}

	if b, ok, msg := parseBool(resolve("passed")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "passed", Message: msg})
	} else if ok {
		if b {
			p.Passed = 1
		} else {
			p.Passed = 0
		}
	}

	setIfNonEmpty(&p.Instructor, resolve("instructor"))
	setIfNonEmpty(&p.DeliveryMethod, resolve("delivery_method"))
	setIfNonEmpty(&p.Location, resolve("location"))
	setIfNonEmpty(&p.CertificateNumber, resolve("certificate_number"))
	setIfNonEmpty(&p.Notes, resolve("notes"))

	if len(errs) > 0 {
		return nil, errs
	}
	return p, nil
}

func (*trainingCompletionsImporter) InsertRow(db Execer, payload any, ctx RowContext) (int64, error) {
	p, ok := payload.(*trainingCompletionPayload)
	if !ok {
		return 0, fmt.Errorf("training_completions: wrong payload type %T", payload)
	}
	if err := db.ExecParams(
		`INSERT INTO training_completions (
		     employee_id, course_id, completion_date, expiration_date,
		     score, passed, instructor, delivery_method, location,
		     certificate_number, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		p.EmployeeID, p.CourseID, p.CompletionDate, p.ExpirationDate,
		p.Score, p.Passed, p.Instructor, p.DeliveryMethod, p.Location,
		p.CertificateNumber, p.Notes,
	); err != nil {
		return 0, err
	}
	id, err := db.QueryVal("SELECT last_insert_rowid()")
	if err != nil {
		return 0, err
	}
	return id.(int64), nil
}
