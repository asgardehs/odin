//go:build ratatoskr_embed

// These tests exercise the real embedded Python + openpyxl install. They
// only run when the binary is built with `-tags ratatoskr_embed` because
// that's the build tag that activates ratatoskr's //go:embed directives;
// without it, python.NewEmbeddedPython fails at runtime.
//
// First test run per-user is slow (~5-10 s for pip install openpyxl).
// Subsequent runs hit the ~/.cache/odin/pylibs cache and are fast.
package ratatoskr

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

// writeFixture runs openpyxl to produce an .xlsx file under dir/name.
// The script is inline so each test can tune the workbook shape without
// committing binaries.
func writeFixture(t *testing.T, x *XLSX, dir, name, script string) string {
	t.Helper()
	path := filepath.Join(dir, name)
	cmd, err := x.ep.PythonCmd("-c", script+"\nwrite("+pyLit(path)+")\n")
	if err != nil {
		t.Fatalf("PythonCmd: %v", err)
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		t.Fatalf("write fixture %s: %v: %s", name, err, stderr.String())
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("fixture not written: %v", err)
	}
	return path
}

// pyLit produces a double-quoted Python string literal. The paths we
// hand to fixtures don't contain quotes or backslashes in practice —
// t.TempDir() on linux returns /tmp/TestName123/NNN.
func pyLit(s string) string { return `"` + s + `"` }

func newParser(t *testing.T) *XLSX {
	t.Helper()
	x, err := New()
	if err != nil {
		t.Fatalf("ratatoskr.New: %v", err)
	}
	return x
}

func TestParseXLSXPlainGrid(t *testing.T) {
	x := newParser(t)
	path := writeFixture(t, x, t.TempDir(), "plain.xlsx", `
from openpyxl import Workbook
def write(path):
    wb = Workbook()
    ws = wb.active
    ws.title = "Sheet1"
    ws.append(["First Name", "Last Name", "Employee ID"])
    ws.append(["Alice", "Anderson", "E001"])
    ws.append(["Bob",   "Burton",   "E002"])
    wb.save(path)
`)

	res, err := x.ParseXLSX(path)
	if err != nil {
		t.Fatalf("ParseXLSX: %v", err)
	}
	wantHeaders := []string{"First Name", "Last Name", "Employee ID"}
	if !equalSlice(res.Headers, wantHeaders) {
		t.Errorf("headers = %v, want %v", res.Headers, wantHeaders)
	}
	if len(res.Rows) != 2 {
		t.Fatalf("rows = %d, want 2", len(res.Rows))
	}
	if res.Rows[0]["First Name"] != "Alice" || res.Rows[0]["Employee ID"] != "E001" {
		t.Errorf("row[0] = %v", res.Rows[0])
	}
	if res.Rows[1]["Last Name"] != "Burton" {
		t.Errorf("row[1] = %v", res.Rows[1])
	}
	if res.Sheet != "Sheet1" || res.SheetCount != 1 {
		t.Errorf("sheet metadata: sheet=%q count=%d", res.Sheet, res.SheetCount)
	}
}

func TestParseXLSXFormulasDoNotBreakParser(t *testing.T) {
	x := newParser(t)
	// Formula cells are loaded under data_only=True, which returns the
	// value Excel cached the last time the file was saved. openpyxl can't
	// compute formulas itself — so for workbooks that were never opened
	// in Excel/LibreOffice, formula cells parse as None (→ empty string).
	// The assertion here isn't about the math; it's that a workbook with
	// formulas doesn't crash the parser.
	path := writeFixture(t, x, t.TempDir(), "formulas.xlsx", `
from openpyxl import Workbook
def write(path):
    wb = Workbook()
    ws = wb.active
    ws.append(["Label", "Formula"])
    ws["A2"] = "Sum"
    ws["B2"] = "=1+2"
    wb.save(path)
`)

	res, err := x.ParseXLSX(path)
	if err != nil {
		t.Fatalf("ParseXLSX: %v", err)
	}
	if len(res.Rows) != 1 {
		t.Fatalf("rows = %d, want 1", len(res.Rows))
	}
	if res.Rows[0]["Label"] != "Sum" {
		t.Errorf("row[0] Label = %q, want 'Sum'", res.Rows[0]["Label"])
	}
}

func TestParseXLSXMultiSheetTakesFirst(t *testing.T) {
	x := newParser(t)
	path := writeFixture(t, x, t.TempDir(), "multi.xlsx", `
from openpyxl import Workbook
def write(path):
    wb = Workbook()
    a = wb.active
    a.title = "Primary"
    a.append(["Col"])
    a.append(["primary-row"])

    b = wb.create_sheet("Extra")
    b.append(["Col"])
    b.append(["extra-row"])

    wb.save(path)
`)

	res, err := x.ParseXLSX(path)
	if err != nil {
		t.Fatalf("ParseXLSX: %v", err)
	}
	if res.Sheet != "Primary" {
		t.Errorf("sheet = %q, want 'Primary'", res.Sheet)
	}
	if res.SheetCount != 2 {
		t.Errorf("sheet_count = %d, want 2", res.SheetCount)
	}
	if len(res.Rows) != 1 || res.Rows[0]["Col"] != "primary-row" {
		t.Errorf("first-sheet rows = %v", res.Rows)
	}
}

func TestParseXLSXSkipsBlankTrailingRows(t *testing.T) {
	x := newParser(t)
	path := writeFixture(t, x, t.TempDir(), "blank.xlsx", `
from openpyxl import Workbook
def write(path):
    wb = Workbook()
    ws = wb.active
    ws.append(["A", "B"])
    ws.append(["x", "1"])
    ws.append([None, None])
    ws.append(["y", "2"])
    ws.append([None, None])
    wb.save(path)
`)

	res, err := x.ParseXLSX(path)
	if err != nil {
		t.Fatalf("ParseXLSX: %v", err)
	}
	if len(res.Rows) != 2 {
		t.Errorf("rows = %d, want 2 (blanks skipped): %v", len(res.Rows), res.Rows)
	}
}

func TestParseXLSXDateRoundTrip(t *testing.T) {
	x := newParser(t)
	path := writeFixture(t, x, t.TempDir(), "dates.xlsx", `
from openpyxl import Workbook
from datetime import date
def write(path):
    wb = Workbook()
    ws = wb.active
    ws.append(["Name", "Started"])
    ws.append(["Alice", date(2024, 3, 15)])
    wb.save(path)
`)

	res, err := x.ParseXLSX(path)
	if err != nil {
		t.Fatalf("ParseXLSX: %v", err)
	}
	started := res.Rows[0]["Started"]
	// datetime.date.isoformat() → "2024-03-15"; datetime.datetime adds a T.
	if started != "2024-03-15" && started[:10] != "2024-03-15" {
		t.Errorf("Started = %q, want ISO-8601 prefix 2024-03-15", started)
	}
}

func TestParseXLSXMissingFile(t *testing.T) {
	x := newParser(t)
	_, err := x.ParseXLSX(filepath.Join(t.TempDir(), "nope.xlsx"))
	if err == nil {
		t.Fatal("expected error for missing file")
	}
}

func equalSlice(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
