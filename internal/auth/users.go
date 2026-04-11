package auth

import (
	"fmt"
	"time"

	"github.com/asgardehs/odin/internal/database"
	"golang.org/x/crypto/bcrypt"
)

// bcryptCost is the work factor for password hashing.
const bcryptCost = 12

// User represents an application-level user account.
type User struct {
	ID                   int64  `json:"id"`
	Username             string `json:"username"`
	DisplayName          string `json:"display_name"`
	Role                 string `json:"role"`
	IsActive             bool   `json:"is_active"`
	HasSecurityQuestions bool   `json:"has_security_questions"`
	CreatedAt            string `json:"created_at"`
	UpdatedAt            string `json:"updated_at"`
	LastLoginAt          string `json:"last_login_at,omitempty"`
}

// SecurityQuestion is a question/answer pair for password reset.
type SecurityQuestion struct {
	Question string `json:"question"`
	Answer   string `json:"answer"` // plaintext on input, never returned
}

// SecurityQuestionsInput is the payload for setting security questions.
type SecurityQuestionsInput struct {
	Questions [3]SecurityQuestion `json:"questions"`
}

// UserInput is the payload for creating or updating a user.
type UserInput struct {
	Username    string `json:"username"`
	DisplayName string `json:"display_name"`
	Password    string `json:"password,omitempty"` // only required on create
	Role        string `json:"role"`
}

// UserStore manages application users backed by the app_users table.
type UserStore struct {
	db *database.DB
}

// NewUserStore creates a user store.
func NewUserStore(db *database.DB) *UserStore {
	return &UserStore{db: db}
}

// UserCount returns the number of users in the system.
// Used for bootstrap detection (zero users = first-run setup).
func (s *UserStore) UserCount() (int64, error) {
	val, err := s.db.QueryVal(`SELECT COUNT(*) FROM app_users`)
	if err != nil {
		return 0, fmt.Errorf("users: count: %w", err)
	}
	return val.(int64), nil
}

// Create inserts a new user with a bcrypt-hashed password.
func (s *UserStore) Create(input UserInput) (int64, error) {
	if input.Username == "" {
		return 0, fmt.Errorf("users: username is required")
	}
	if input.Password == "" {
		return 0, fmt.Errorf("users: password is required")
	}
	if input.DisplayName == "" {
		input.DisplayName = input.Username
	}
	if input.Role == "" {
		input.Role = "user"
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcryptCost)
	if err != nil {
		return 0, fmt.Errorf("users: hash password: %w", err)
	}

	err = s.db.ExecParams(
		`INSERT INTO app_users (username, display_name, password_hash, role)
		 VALUES (?, ?, ?, ?)`,
		input.Username, input.DisplayName, string(hash), input.Role,
	)
	if err != nil {
		return 0, fmt.Errorf("users: create: %w", err)
	}

	val, err := s.db.QueryVal(`SELECT last_insert_rowid()`)
	if err != nil {
		return 0, fmt.Errorf("users: last id: %w", err)
	}
	return val.(int64), nil
}

// Get returns a user by ID.
func (s *UserStore) Get(id int64) (*User, error) {
	row, err := s.db.QueryRow(
		`SELECT id, username, display_name, role, is_active,
		        security_q1, security_a1, created_at, updated_at, last_login_at
		 FROM app_users WHERE id = ?`, id,
	)
	if err != nil {
		return nil, fmt.Errorf("users: get: %w", err)
	}
	if row == nil {
		return nil, nil
	}
	return userFromRow(row), nil
}

// GetByUsername returns a user by username (case-insensitive).
func (s *UserStore) GetByUsername(username string) (*User, error) {
	row, err := s.db.QueryRow(
		`SELECT id, username, display_name, role, is_active,
		        security_q1, security_a1, created_at, updated_at, last_login_at
		 FROM app_users WHERE username = ?`, username,
	)
	if err != nil {
		return nil, fmt.Errorf("users: get by username: %w", err)
	}
	if row == nil {
		return nil, nil
	}
	return userFromRow(row), nil
}

// List returns all users.
func (s *UserStore) List() ([]User, error) {
	rows, err := s.db.QueryRows(
		`SELECT id, username, display_name, role, is_active,
		        security_q1, security_a1, created_at, updated_at, last_login_at
		 FROM app_users ORDER BY username`,
	)
	if err != nil {
		return nil, fmt.Errorf("users: list: %w", err)
	}

	users := make([]User, 0, len(rows))
	for _, row := range rows {
		users = append(users, *userFromRow(row))
	}
	return users, nil
}

// Update modifies a user's display name, role, and/or active status.
func (s *UserStore) Update(id int64, input UserInput) error {
	existing, err := s.Get(id)
	if err != nil {
		return err
	}
	if existing == nil {
		return fmt.Errorf("users: user %d not found", id)
	}

	displayName := input.DisplayName
	if displayName == "" {
		displayName = existing.DisplayName
	}
	role := input.Role
	if role == "" {
		role = existing.Role
	}

	now := time.Now().UTC().Format(time.DateTime)
	return s.db.ExecParams(
		`UPDATE app_users SET display_name = ?, role = ?, updated_at = ? WHERE id = ?`,
		displayName, role, now, id,
	)
}

// SetPassword updates a user's password hash.
func (s *UserStore) SetPassword(id int64, newPassword string) error {
	if newPassword == "" {
		return fmt.Errorf("users: password is required")
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcryptCost)
	if err != nil {
		return fmt.Errorf("users: hash password: %w", err)
	}

	now := time.Now().UTC().Format(time.DateTime)
	return s.db.ExecParams(
		`UPDATE app_users SET password_hash = ?, updated_at = ? WHERE id = ?`,
		string(hash), now, id,
	)
}

// Deactivate sets a user as inactive (soft delete).
func (s *UserStore) Deactivate(id int64) error {
	now := time.Now().UTC().Format(time.DateTime)
	return s.db.ExecParams(
		`UPDATE app_users SET is_active = 0, updated_at = ? WHERE id = ?`,
		now, id,
	)
}

// Reactivate restores a deactivated user. Used during disaster recovery
// when a recovery key is used to regain access to an inactive account.
func (s *UserStore) Reactivate(id int64) error {
	now := time.Now().UTC().Format(time.DateTime)
	return s.db.ExecParams(
		`UPDATE app_users SET is_active = 1, updated_at = ? WHERE id = ?`,
		now, id,
	)
}

// Authenticate verifies a username/password combination and returns
// the user on success. Returns nil on failed auth (no error, just no
// match). Updates last_login_at on success.
func (s *UserStore) Authenticate(username, password string) (*User, error) {
	row, err := s.db.QueryRow(
		`SELECT id, username, display_name, role, is_active, password_hash,
		        security_q1, security_a1, created_at, updated_at, last_login_at
		 FROM app_users WHERE username = ? AND is_active = 1`, username,
	)
	if err != nil {
		return nil, fmt.Errorf("users: authenticate: %w", err)
	}
	if row == nil {
		return nil, nil
	}

	hash, _ := row["password_hash"].(string)
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)); err != nil {
		return nil, nil // wrong password, not an error
	}

	// Update last login.
	now := time.Now().UTC().Format(time.DateTime)
	_ = s.db.ExecParams(`UPDATE app_users SET last_login_at = ? WHERE id = ?`,
		now, row["id"],
	)

	return userFromRow(row), nil
}

// SetSecurityQuestions stores 3 security question/answer pairs for a user.
// Answers are bcrypt-hashed and compared case-sensitively — no normalization.
func (s *UserStore) SetSecurityQuestions(id int64, input SecurityQuestionsInput) error {
	for i, q := range input.Questions {
		if q.Question == "" {
			return fmt.Errorf("users: security question %d is required", i+1)
		}
		if q.Answer == "" {
			return fmt.Errorf("users: security answer %d is required", i+1)
		}
	}

	// Hash all 3 answers. Case-sensitive — answers are hashed exactly as typed.
	hashes := [3]string{}
	for i, q := range input.Questions {
		h, err := bcrypt.GenerateFromPassword([]byte(q.Answer), bcryptCost)
		if err != nil {
			return fmt.Errorf("users: hash answer %d: %w", i+1, err)
		}
		hashes[i] = string(h)
	}

	now := time.Now().UTC().Format(time.DateTime)
	return s.db.ExecParams(
		`UPDATE app_users SET
		  security_q1 = ?, security_a1 = ?,
		  security_q2 = ?, security_a2 = ?,
		  security_q3 = ?, security_a3 = ?,
		  updated_at = ?
		 WHERE id = ?`,
		input.Questions[0].Question, hashes[0],
		input.Questions[1].Question, hashes[1],
		input.Questions[2].Question, hashes[2],
		now, id,
	)
}

// GetSecurityQuestions returns the 3 security questions for a user
// (questions only, never answers). Returns nil if not set.
func (s *UserStore) GetSecurityQuestions(username string) ([]string, error) {
	row, err := s.db.QueryRow(
		`SELECT security_q1, security_q2, security_q3
		 FROM app_users WHERE username = ? AND is_active = 1`, username,
	)
	if err != nil {
		return nil, fmt.Errorf("users: get questions: %w", err)
	}
	if row == nil {
		return nil, nil
	}

	q1, _ := row["security_q1"].(string)
	if q1 == "" {
		return nil, nil // no questions set
	}
	q2, _ := row["security_q2"].(string)
	q3, _ := row["security_q3"].(string)
	return []string{q1, q2, q3}, nil
}

// ResetPassword verifies 3 security answers and sets a new password.
// Answers are compared case-sensitively. Returns an error if any answer
// is wrong or if security questions haven't been set.
func (s *UserStore) ResetPassword(username string, answers [3]string, newPassword string) error {
	if newPassword == "" {
		return fmt.Errorf("users: new password is required")
	}

	row, err := s.db.QueryRow(
		`SELECT id, security_a1, security_a2, security_a3
		 FROM app_users WHERE username = ? AND is_active = 1`, username,
	)
	if err != nil {
		return fmt.Errorf("users: reset: %w", err)
	}
	if row == nil {
		return fmt.Errorf("users: user not found")
	}

	// Check that security questions are set.
	a1Hash, _ := row["security_a1"].(string)
	if a1Hash == "" {
		return fmt.Errorf("users: security questions not configured")
	}
	a2Hash, _ := row["security_a2"].(string)
	a3Hash, _ := row["security_a3"].(string)

	// Verify all 3 answers. Case-sensitive — compared exactly as typed.
	hashes := [3]string{a1Hash, a2Hash, a3Hash}
	for i, answer := range answers {
		if err := bcrypt.CompareHashAndPassword([]byte(hashes[i]), []byte(answer)); err != nil {
			return fmt.Errorf("users: incorrect answer to question %d", i+1)
		}
	}

	// All answers correct — set new password.
	id, _ := row["id"].(int64)
	return s.SetPassword(id, newPassword)
}

// userFromRow converts a database row map to a User struct.
func userFromRow(row map[string]any) *User {
	u := &User{}
	if v, ok := row["id"].(int64); ok {
		u.ID = v
	}
	if v, ok := row["username"].(string); ok {
		u.Username = v
	}
	if v, ok := row["display_name"].(string); ok {
		u.DisplayName = v
	}
	if v, ok := row["role"].(string); ok {
		u.Role = v
	}
	if v, ok := row["is_active"].(int64); ok {
		u.IsActive = v == 1
	}
	// HasSecurityQuestions is true if security_q1 is populated.
	if v, ok := row["security_q1"].(string); ok && v != "" {
		u.HasSecurityQuestions = true
	}
	if v, ok := row["created_at"].(string); ok {
		u.CreatedAt = v
	}
	if v, ok := row["updated_at"].(string); ok {
		u.UpdatedAt = v
	}
	if v, ok := row["last_login_at"].(string); ok {
		u.LastLoginAt = v
	}
	return u
}
