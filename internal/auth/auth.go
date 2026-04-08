// Package auth provides OS-level user authentication.
//
// On Unix systems (Linux, macOS) it verifies credentials via PAM.
// On Windows it uses the LogonUser API. The rest of the application
// interacts only with the Authenticator interface and never needs
// to know which backend is in use.
package auth

import "errors"

// ErrInvalidCredentials is returned when a username/password pair
// cannot be verified by the operating system.
var ErrInvalidCredentials = errors.New("auth: invalid credentials")

// Authenticator verifies a user's identity against the host OS.
type Authenticator interface {
	// Verify checks the username and password against the OS account
	// database. It returns nil on success or ErrInvalidCredentials
	// (possibly wrapped) on failure.
	Verify(username, password string) error

	// CurrentUser returns the OS username of the process owner.
	CurrentUser() string
}

// Credentials is passed through API boundaries so handlers don't
// need to unpack raw request fields.
type Credentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
}
