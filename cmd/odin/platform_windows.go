//go:build windows

package main

import (
	"os"
	"path/filepath"

	"github.com/asgardehs/odin/internal/auth"
)

func newAuthenticator() auth.Authenticator {
	return auth.NewWinAuthenticator()
}

func odinDataDir() (string, error) {
	if dir := os.Getenv("ODIN_DATA_DIR"); dir != "" {
		return dir, nil
	}
	appData := os.Getenv("LOCALAPPDATA")
	if appData == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		appData = filepath.Join(home, "AppData", "Local")
	}
	return filepath.Join(appData, "Odin"), nil
}
