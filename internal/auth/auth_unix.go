//go:build !windows

package auth

import (
	"fmt"
	"os/user"

	"github.com/msteinert/pam/v2"
)

// PAMAuthenticator verifies credentials through the Pluggable
// Authentication Modules framework. This works on both Linux and macOS.
type PAMAuthenticator struct {
	// ServiceName is the PAM service to authenticate against.
	// Defaults to "login" if empty.
	ServiceName string
}

// NewPAMAuthenticator returns an authenticator using the given PAM
// service name. Pass "" to use the default "login" service.
func NewPAMAuthenticator(service string) *PAMAuthenticator {
	if service == "" {
		service = "login"
	}
	return &PAMAuthenticator{ServiceName: service}
}

// Verify checks the username/password against PAM.
func (a *PAMAuthenticator) Verify(username, password string) error {
	tx, err := pam.StartFunc(a.ServiceName, username,
		func(style pam.Style, msg string) (string, error) {
			switch style {
			case pam.PromptEchoOff: // password prompt
				return password, nil
			case pam.PromptEchoOn: // username prompt
				return username, nil
			default:
				return "", nil
			}
		},
	)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidCredentials, err)
	}

	if err := tx.Authenticate(pam.Silent); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidCredentials, err)
	}

	// Validate the account is not expired/locked.
	if err := tx.AcctMgmt(pam.Silent); err != nil {
		return fmt.Errorf("%w: account check failed: %v", ErrInvalidCredentials, err)
	}

	return nil
}

// CurrentUser returns the OS username of the process owner.
func (a *PAMAuthenticator) CurrentUser() string {
	u, err := user.Current()
	if err != nil {
		return "unknown"
	}
	return u.Username
}
