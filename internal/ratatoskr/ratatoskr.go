// Package ratatoskr wraps the embedded Python interpreter shipped by
// github.com/asgardehs/ratatoskr and exposes the narrow surface that odin
// needs for bulk import: parsing XLSX workbooks into the same row-map
// representation the CSV path already uses.
//
// Building with `-tags ratatoskr_embed` links in the ~122 MB embedded
// Python + pip distribution and makes New() return a usable parser. The
// default build omits the distribution entirely, and New() returns an
// error — callers should treat that as "XLSX import unavailable" rather
// than fatal, so the CSV path keeps working.
package ratatoskr

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"fmt"
	"os"

	"github.com/asgardehs/ratatoskr/python"
)

// parseXLSXScript is the Python source driven by (*XLSX).ParseXLSX.
// Embedded so the odin binary carries everything it needs at
// distribution time.
//
//go:embed scripts/parse_xlsx.py
var parseXLSXScript []byte

// XLSX wraps an initialized EmbeddedPython + openpyxl install and
// exposes a ParseXLSX entrypoint. One instance per server is enough:
// the underlying EmbeddedPython and the pip-installed libraries are
// process-wide and re-entrant (each ParseXLSX call forks a new
// `python -m ...` subprocess).
type XLSX struct {
	ep       *python.EmbeddedPython
	libsPath string // path added to PYTHONPATH so openpyxl is importable
}

// Result is the JSON payload emitted by scripts/parse_xlsx.py.
type Result struct {
	Headers    []string            `json:"headers"`
	Rows       []map[string]string `json:"rows"`
	Sheet      string              `json:"sheet"`
	SheetCount int                 `json:"sheet_count"`
}

// ParseXLSX parses the workbook at the given path and returns its first
// sheet as a list of column headers and one row-map per data row. The
// path must already exist on disk; callers are expected to buffer the
// multipart upload into a tempfile before calling this.
func (x *XLSX) ParseXLSX(path string) (*Result, error) {
	stdout, err := x.RunScript(parseXLSXScript, path)
	if err != nil {
		return nil, fmt.Errorf("parse xlsx: %w", err)
	}
	var res Result
	if err := json.Unmarshal(stdout, &res); err != nil {
		return nil, fmt.Errorf("parse xlsx: decode result: %w", err)
	}
	return &res, nil
}

// RunScript materializes the given Python source to a temp file and
// invokes it via the embedded interpreter with the given argv. Returns
// stdout on success; on failure returns the stderr buffer wrapped.
//
// Primarily intended for running vendored analysis scripts (parse_xlsx.py)
// and for tests that need to generate fixtures through the same embedded
// python — keeps all Python entry points going through one choke point.
func (x *XLSX) RunScript(script []byte, args ...string) ([]byte, error) {
	if x == nil || x.ep == nil {
		return nil, fmt.Errorf("ratatoskr: parser is not available (odin was built without -tags ratatoskr_embed)")
	}

	scriptPath, cleanup, err := writeScriptFile(script)
	if err != nil {
		return nil, err
	}
	defer cleanup()

	cmdArgs := append([]string{scriptPath}, args...)
	cmd, err := x.ep.PythonCmd(cmdArgs...)
	if err != nil {
		return nil, err
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("%w: %s", err, stderr.String())
	}
	return stdout.Bytes(), nil
}

// writeScriptFile drops script bytes into a uniquely-named tempfile and
// returns the path + a cleanup closure. os.CreateTemp generates a unique
// name per call so no caller-side locking is needed.
func writeScriptFile(script []byte) (string, func(), error) {
	f, err := os.CreateTemp("", "odin-py-*.py")
	if err != nil {
		return "", func() {}, err
	}
	if _, err := f.Write(script); err != nil {
		f.Close()
		os.Remove(f.Name())
		return "", func() {}, err
	}
	if err := f.Close(); err != nil {
		os.Remove(f.Name())
		return "", func() {}, err
	}
	return f.Name(), func() { os.Remove(f.Name()) }, nil
}
