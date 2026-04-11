package repository

import "fmt"

const trainingCourseModule = "training_courses"
const trainingCourseTable = "training_courses"
const trainingCompletionModule = "training_completions"
const trainingCompletionTable = "training_completions"
const trainingAssignmentModule = "training_assignments"
const trainingAssignmentTable = "training_assignments"

// TrainingCourseInput is the payload for creating or updating a training course.
type TrainingCourseInput struct {
	EstablishmentID int64    `json:"establishment_id"`
	CourseCode      *string  `json:"course_code,omitempty"`
	CourseName      string   `json:"course_name"`
	Description     *string  `json:"description,omitempty"`
	DurationMinutes *int     `json:"duration_minutes,omitempty"`
	DeliveryMethod  *string  `json:"delivery_method,omitempty"`
	HasTest         *int     `json:"has_test,omitempty"`
	PassingScore    *float64 `json:"passing_score,omitempty"`
	ValidityMonths  *int     `json:"validity_months,omitempty"`
	IsExternal      *int     `json:"is_external,omitempty"`
	VendorName      *string  `json:"vendor_name,omitempty"`
}

func (r *Repo) CreateTrainingCourse(user string, in TrainingCourseInput) (int64, error) {
	return r.insertAndAudit(trainingCourseTable, trainingCourseModule, user,
		fmt.Sprintf("Created training course: %s", in.CourseName),
		`INSERT INTO training_courses (establishment_id, course_code, course_name,
		        description, duration_minutes, delivery_method,
		        has_test, passing_score, validity_months, is_external, vendor_name)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EstablishmentID, in.CourseCode, in.CourseName,
		in.Description, in.DurationMinutes, in.DeliveryMethod,
		in.HasTest, in.PassingScore, in.ValidityMonths, in.IsExternal, in.VendorName,
	)
}

func (r *Repo) UpdateTrainingCourse(user string, id int64, in TrainingCourseInput) error {
	return r.updateAndAudit(trainingCourseTable, trainingCourseModule, id, user,
		fmt.Sprintf("Updated training course: %s", in.CourseName),
		`UPDATE training_courses SET
		        course_code = ?, course_name = ?, description = ?,
		        duration_minutes = ?, delivery_method = ?,
		        has_test = ?, passing_score = ?, validity_months = ?,
		        is_external = ?, vendor_name = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`,
		in.CourseCode, in.CourseName, in.Description,
		in.DurationMinutes, in.DeliveryMethod,
		in.HasTest, in.PassingScore, in.ValidityMonths,
		in.IsExternal, in.VendorName,
		id,
	)
}

func (r *Repo) DeleteTrainingCourse(user string, id int64) error {
	return r.deleteAndAudit(trainingCourseTable, trainingCourseModule, id, user,
		fmt.Sprintf("Deleted training course %d", id),
		`DELETE FROM training_courses WHERE id = ?`, id,
	)
}

// TrainingCompletionInput is the payload for recording a training completion.
type TrainingCompletionInput struct {
	EmployeeID      int64    `json:"employee_id"`
	CourseID        int64    `json:"course_id"`
	CompletionDate  string   `json:"completion_date"`
	ExpirationDate  *string  `json:"expiration_date,omitempty"`
	Score           *float64 `json:"score,omitempty"`
	Passed          *int     `json:"passed,omitempty"`
	Instructor      *string  `json:"instructor,omitempty"`
	DeliveryMethod  *string  `json:"delivery_method,omitempty"`
	Location        *string  `json:"location,omitempty"`
	CertificateNum  *string  `json:"certificate_number,omitempty"`
	Notes           *string  `json:"notes,omitempty"`
}

func (r *Repo) CreateTrainingCompletion(user string, in TrainingCompletionInput) (int64, error) {
	return r.insertAndAudit(trainingCompletionTable, trainingCompletionModule, user,
		fmt.Sprintf("Recorded training completion for employee %d, course %d", in.EmployeeID, in.CourseID),
		`INSERT INTO training_completions (employee_id, course_id, completion_date,
		        expiration_date, score, passed, instructor, delivery_method,
		        location, certificate_number, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EmployeeID, in.CourseID, in.CompletionDate,
		in.ExpirationDate, in.Score, in.Passed, in.Instructor, in.DeliveryMethod,
		in.Location, in.CertificateNum, in.Notes,
	)
}

func (r *Repo) DeleteTrainingCompletion(user string, id int64) error {
	return r.deleteAndAudit(trainingCompletionTable, trainingCompletionModule, id, user,
		fmt.Sprintf("Deleted training completion %d", id),
		`DELETE FROM training_completions WHERE id = ?`, id,
	)
}

// TrainingAssignmentInput is the payload for assigning training.
type TrainingAssignmentInput struct {
	EmployeeID         int64   `json:"employee_id"`
	CourseID           int64   `json:"course_id"`
	DueDate            *string `json:"due_date,omitempty"`
	AssignedBy         *string `json:"assigned_by,omitempty"`
	Reason             *string `json:"reason,omitempty"`
	Priority           *string `json:"priority,omitempty"`
	CorrectiveActionID *int64  `json:"corrective_action_id,omitempty"`
	IncidentID         *int64  `json:"incident_id,omitempty"`
}

func (r *Repo) CreateTrainingAssignment(user string, in TrainingAssignmentInput) (int64, error) {
	return r.insertAndAudit(trainingAssignmentTable, trainingAssignmentModule, user,
		fmt.Sprintf("Assigned training course %d to employee %d", in.CourseID, in.EmployeeID),
		`INSERT INTO training_assignments (employee_id, course_id, due_date,
		        assigned_by, reason, priority, corrective_action_id, incident_id)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		in.EmployeeID, in.CourseID, in.DueDate,
		in.AssignedBy, in.Reason, in.Priority, in.CorrectiveActionID, in.IncidentID,
	)
}

// CompleteTrainingAssignment links an assignment to a completion record.
func (r *Repo) CompleteTrainingAssignment(user string, id int64, completionID int64) error {
	return r.updateAndAudit(trainingAssignmentTable, trainingAssignmentModule, id, user,
		fmt.Sprintf("Completed training assignment %d", id),
		`UPDATE training_assignments SET status = 'completed', completion_id = ?,
		        updated_at = datetime('now')
		 WHERE id = ?`, completionID, id,
	)
}

// CancelTrainingAssignment cancels an assignment.
func (r *Repo) CancelTrainingAssignment(user string, id int64) error {
	return r.updateAndAudit(trainingAssignmentTable, trainingAssignmentModule, id, user,
		fmt.Sprintf("Cancelled training assignment %d", id),
		`UPDATE training_assignments SET status = 'cancelled', updated_at = datetime('now')
		 WHERE id = ?`, id,
	)
}

func (r *Repo) DeleteTrainingAssignment(user string, id int64) error {
	return r.deleteAndAudit(trainingAssignmentTable, trainingAssignmentModule, id, user,
		fmt.Sprintf("Deleted training assignment %d", id),
		`DELETE FROM training_assignments WHERE id = ?`, id,
	)
}
