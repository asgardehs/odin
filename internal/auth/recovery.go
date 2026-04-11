package auth

import (
	"crypto/rand"
	"fmt"
	"math/big"

	"github.com/asgardehs/odin/internal/database"
	"golang.org/x/crypto/bcrypt"
)

const (
	// recoveryKeyConfigKey is the app_config key for the recovery key hash.
	recoveryKeyConfigKey = "recovery_key_hash"

	// recoveryKeyLength is the number of characters in a recovery key.
	// 32 alphanumeric chars ≈ 190 bits of entropy.
	recoveryKeyLength = 32

	// recoveryKeyAlphabet avoids ambiguous characters (0/O, 1/l/I) for
	// easy reading off a printed sheet.
	recoveryKeyAlphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz"
)

// RecoveryStore manages the application recovery key.
type RecoveryStore struct {
	db *database.DB
}

// NewRecoveryStore creates a recovery store.
func NewRecoveryStore(db *database.DB) *RecoveryStore {
	return &RecoveryStore{db: db}
}

// HasRecoveryKey returns true if a recovery key has been set.
func (s *RecoveryStore) HasRecoveryKey() (bool, error) {
	val, err := s.db.QueryVal(
		`SELECT value FROM app_config WHERE key = ?`, recoveryKeyConfigKey,
	)
	if err != nil {
		return false, fmt.Errorf("recovery: check: %w", err)
	}
	return val != nil, nil
}

// GenerateAndStore creates a new recovery key, stores its bcrypt hash,
// and returns the plaintext key. This is the ONLY time the plaintext
// is available — the caller must present it to the user for printing.
//
// If a recovery key already exists, it is replaced (an admin is
// regenerating it).
func (s *RecoveryStore) GenerateAndStore() (string, error) {
	key, err := generateRecoveryKey()
	if err != nil {
		return "", fmt.Errorf("recovery: generate: %w", err)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(key), bcryptCost)
	if err != nil {
		return "", fmt.Errorf("recovery: hash: %w", err)
	}

	// Upsert — INSERT OR REPLACE.
	err = s.db.ExecParams(
		`INSERT OR REPLACE INTO app_config (key, value) VALUES (?, ?)`,
		recoveryKeyConfigKey, string(hash),
	)
	if err != nil {
		return "", fmt.Errorf("recovery: store: %w", err)
	}

	return key, nil
}

// Verify checks a plaintext recovery key against the stored hash.
// Returns true if it matches.
func (s *RecoveryStore) Verify(key string) (bool, error) {
	if key == "" {
		return false, nil
	}

	val, err := s.db.QueryVal(
		`SELECT value FROM app_config WHERE key = ?`, recoveryKeyConfigKey,
	)
	if err != nil {
		return false, fmt.Errorf("recovery: verify: %w", err)
	}
	if val == nil {
		return false, nil // no key stored
	}

	hash, _ := val.(string)
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(key)); err != nil {
		return false, nil // wrong key
	}
	return true, nil
}

// generateRecoveryKey creates a random alphanumeric key formatted in
// groups of 4 for easy reading: XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
func generateRecoveryKey() (string, error) {
	chars := make([]byte, recoveryKeyLength)
	for i := range chars {
		idx, err := rand.Int(rand.Reader, big.NewInt(int64(len(recoveryKeyAlphabet))))
		if err != nil {
			return "", err
		}
		chars[i] = recoveryKeyAlphabet[idx.Int64()]
	}

	// Format as XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
	formatted := make([]byte, 0, recoveryKeyLength+7) // 32 chars + 7 dashes
	for i, c := range chars {
		if i > 0 && i%4 == 0 {
			formatted = append(formatted, '-')
		}
		formatted = append(formatted, c)
	}
	return string(formatted), nil
}
