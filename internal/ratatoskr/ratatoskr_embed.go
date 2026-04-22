//go:build ratatoskr_embed

// Full XLSX parser implementation — extracts the embedded Python
// distribution, bootstraps pip from ratatoskr's separate pip package,
// and installs openpyxl into the odin cache dir on first run.
//
// This file is only compiled when building with `-tags ratatoskr_embed`.
// The stub in ratatoskr_stub.go provides matching symbols for builds
// without the tag so importers (internal/server/api_import.go) compile
// either way.

package ratatoskr

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"

	"github.com/asgardehs/ratatoskr/pip"
	"github.com/asgardehs/ratatoskr/python"
)

// openpyxlVersion is pinned so that the first-run pip install produces
// a deterministic dependency set. Bump intentionally.
const openpyxlVersion = "3.1.5"

// New initializes the embedded Python distribution under ~/.cache/odin
// and ensures openpyxl is installed alongside it. First call per user
// is slow (~a few seconds to extract Python + ~5-10s for pip install);
// subsequent calls reuse the cached install and return immediately.
func New() (*XLSX, error) {
	ep, err := python.NewEmbeddedPythonInCacheDir("odin")
	if err != nil {
		return nil, fmt.Errorf("ratatoskr: init embedded python: %w", err)
	}

	libsPath, err := ensureOpenpyxl(ep)
	if err != nil {
		return nil, fmt.Errorf("ratatoskr: install openpyxl: %w", err)
	}
	ep.AddPythonPath(libsPath)

	return &XLSX{ep: ep, libsPath: libsPath}, nil
}

// ensureOpenpyxl installs openpyxl into the odin cache dir if the
// sentinel file is missing. Install is idempotent across process
// restarts: a successful install writes `.installed` alongside the
// extracted wheel and future calls short-circuit on its presence.
//
// python-build-standalone's install_only distributions do NOT bundle
// pip, so we bootstrap it from ratatoskr's separate `pip` package — a
// zipapp extracted per-process and added to PYTHONPATH so `python -m pip`
// works. Once openpyxl is on disk, pip's path is no longer strictly
// needed on subsequent calls.
func ensureOpenpyxl(ep *python.EmbeddedPython) (string, error) {
	cacheRoot, err := os.UserCacheDir()
	if err != nil {
		return "", err
	}
	libsDir := filepath.Join(cacheRoot, "odin", "pylibs", "openpyxl-"+openpyxlVersion)
	sentinel := filepath.Join(libsDir, ".installed")

	if _, err := os.Stat(sentinel); err == nil {
		return libsDir, nil
	}

	if err := os.MkdirAll(libsDir, 0o755); err != nil {
		return "", err
	}

	pipLib, err := pip.NewPipLib("odin")
	if err != nil {
		return "", fmt.Errorf("extract pip: %w", err)
	}
	ep.AddPythonPath(pipLib.GetExtractedPath())

	cmd, err := ep.PythonCmd(
		"-m", "pip", "install",
		"--quiet", "--no-warn-script-location",
		"--target", libsDir,
		"openpyxl=="+openpyxlVersion,
	)
	if err != nil {
		return "", err
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("pip install openpyxl: %w: %s", err, stderr.String())
	}

	if err := os.WriteFile(sentinel, []byte(openpyxlVersion), 0o644); err != nil {
		return "", err
	}
	return libsDir, nil
}
