package auth

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/asgardehs/odin/internal/database"
)

// DefaultSessionDuration is the default session lifetime.
const DefaultSessionDuration = 24 * time.Hour

// MaxSessionDuration is the maximum allowed session lifetime.
const MaxSessionDuration = 24 * time.Hour

// SessionStore manages login sessions backed by the app_sessions table.
type SessionStore struct {
	db       *database.DB
	duration time.Duration
}

// NewSessionStore creates a session store with the given expiry duration.
// Duration is clamped to [1 minute, MaxSessionDuration].
func NewSessionStore(db *database.DB, duration time.Duration) *SessionStore {
	if duration <= 0 {
		duration = DefaultSessionDuration
	}
	if duration > MaxSessionDuration {
		duration = MaxSessionDuration
	}
	return &SessionStore{db: db, duration: duration}
}

// Session represents an active login session.
type Session struct {
	Token     string `json:"token"`
	UserID    int64  `json:"user_id"`
	CreatedAt string `json:"created_at"`
	ExpiresAt string `json:"expires_at"`
	IPAddress string `json:"ip_address,omitempty"`
}

// Create generates a new session token for the given user.
func (s *SessionStore) Create(userID int64, ipAddr string) (string, error) {
	token, err := generateToken()
	if err != nil {
		return "", fmt.Errorf("session: generate token: %w", err)
	}

	expiresAt := time.Now().UTC().Add(s.duration).Format(time.DateTime)

	err = s.db.ExecParams(
		`INSERT INTO app_sessions (token, user_id, expires_at, ip_address) VALUES (?, ?, ?, ?)`,
		token, userID, expiresAt, ipAddr,
	)
	if err != nil {
		return "", fmt.Errorf("session: create: %w", err)
	}

	return token, nil
}

// Validate checks a token and returns the associated user if the
// session is still active. Returns nil, nil if the token is invalid
// or expired.
func (s *SessionStore) Validate(token string) (*User, error) {
	if token == "" {
		return nil, nil
	}

	now := time.Now().UTC().Format(time.DateTime)
	row, err := s.db.QueryRow(
		`SELECT u.id, u.username, u.display_name, u.role, u.is_active
		 FROM app_sessions s
		 JOIN app_users u ON u.id = s.user_id
		 WHERE s.token = ? AND s.expires_at > ? AND u.is_active = 1`,
		token, now,
	)
	if err != nil {
		return nil, fmt.Errorf("session: validate: %w", err)
	}
	if row == nil {
		return nil, nil
	}

	return userFromRow(row), nil
}

// Delete removes a session (logout).
func (s *SessionStore) Delete(token string) error {
	return s.db.ExecParams(`DELETE FROM app_sessions WHERE token = ?`, token)
}

// DeleteForUser removes all sessions for a user (force logout).
func (s *SessionStore) DeleteForUser(userID int64) error {
	return s.db.ExecParams(`DELETE FROM app_sessions WHERE user_id = ?`, userID)
}

// CleanExpired removes all expired sessions.
func (s *SessionStore) CleanExpired() error {
	now := time.Now().UTC().Format(time.DateTime)
	return s.db.ExecParams(`DELETE FROM app_sessions WHERE expires_at <= ?`, now)
}

// generateToken produces a cryptographically random 32-byte hex token.
func generateToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
