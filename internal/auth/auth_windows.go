//go:build windows

package auth

import (
	"fmt"
	"os/user"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

// WinAuthenticator verifies credentials using the Windows LogonUser API.
type WinAuthenticator struct{}

// NewWinAuthenticator returns a Windows credential authenticator.
func NewWinAuthenticator() *WinAuthenticator {
	return &WinAuthenticator{}
}

// Verify checks the username/password against Windows local accounts.
func (a *WinAuthenticator) Verify(username, password string) error {
	uPtr, err := syscall.UTF16PtrFromString(username)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidCredentials, err)
	}

	// Empty domain — authenticate against the local machine.
	dPtr, err := syscall.UTF16PtrFromString(".")
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidCredentials, err)
	}

	pPtr, err := syscall.UTF16PtrFromString(password)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidCredentials, err)
	}

	var token windows.Token
	err = windows.LogonUser(
		(*uint16)(unsafe.Pointer(uPtr)),
		(*uint16)(unsafe.Pointer(dPtr)),
		(*uint16)(unsafe.Pointer(pPtr)),
		windows.LOGON32_LOGON_INTERACTIVE,
		windows.LOGON32_PROVIDER_DEFAULT,
		&token,
	)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidCredentials, err)
	}
	token.Close()
	return nil
}

// CurrentUser returns the OS username of the process owner.
func (a *WinAuthenticator) CurrentUser() string {
	u, err := user.Current()
	if err != nil {
		return "unknown"
	}
	return u.Username
}
