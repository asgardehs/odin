//go:build !windows

package main

import (
	"os"
	"path/filepath"

	"github.com/asgardehs/odin/internal/auth"
)

func newAuthenticator() auth.Authenticator {
	return auth.NewPAMAuthenticator("")
}

func odinDataDir() (string, error) {
	if dir := os.Getenv("ODIN_DATA_DIR"); dir != "" {
		return dir, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "share", "odin"), nil
}
