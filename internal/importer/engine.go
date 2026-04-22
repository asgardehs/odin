package importer

import (
	"crypto/rand"
	"encoding/csv"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/asgardehs/odin/internal/audit"
	"github.com/asgardehs/odin/internal/database"
)

// DefaultTTL is how long an uploaded import waits for a commit before the
// token is considered expired. The engine sweeps expired rows lazily.
const DefaultTTL = 30 * time.Minute

// RowsPreviewLimit caps how many raw rows the engine returns in the
// preview payload. The full row set is still persisted and re-validated
// on mapping changes; this only limits UI payload size.
const RowsPreviewLimit = 20

// MaxFileBytes is the largest CSV we accept in one upload. Keeps memory
// bounded while still fitting typical EHS bulk-entry targets (< 1 MB).
const MaxFileBytes = 10 * 1024 * 1024

// Engine coordinates the upload / map / commit lifecycle against the
// _imports metadata table. It is safe for concurrent use as long as the
// underlying *database.DB is; the _imports row serves as the coordination
// boundary.
type Engine struct {
	DB    *database.DB
	Audit *audit.Store
	TTL   time.Duration // defaults to DefaultTTL when zero
}

// PreviewResponse is the payload returned by Upload + by GetStatus. The
// fields closely mirror the plan's contract for POST /api/import/csv/:module.
type PreviewResponse struct {
	Token              string              `json:"token"`
	Module             string              `json:"module"`
	Status             string              `json:"status"`
	Headers            []string            `json:"headers"`
	MappingSuggestions map[string]string   `json:"mapping_suggestions"`
	Mapping            map[string]string   `json:"mapping"`
	RowCount           int                 `json:"row_count"`
	RowsPreview        []map[string]string `json:"rows_preview"`
	ValidationErrors   []ValidationError   `json:"validation_errors"`
	TargetFields       []TargetField       `json:"target_fields"`
	UploadedAt         string              `json:"uploaded_at"`
	ExpiresAt          string              `json:"expires_at"`
}

// CommitResult captures the outcome of a Commit call.
type CommitResult struct {
	Token          string `json:"token"`
	Module         string `json:"module"`
	InsertedCount  int    `json:"inserted_count"`
	SkippedCount   int    `json:"skipped_count"`
	CommittedAt    string `json:"committed_at"`
	AuditSummary   string `json:"audit_summary"`
}

// ErrExpired is returned when an attempt is made against a token whose
// expires_at is in the past.
var ErrExpired = errors.New("import token expired")

// ErrNotFound is returned when a token does not exist in _imports.
var ErrNotFound = errors.New("import token not found")

// ErrAlreadyCommitted is returned when a commit / discard is attempted
// against a token that has already been committed.
var ErrAlreadyCommitted = errors.New("import already committed")

// ErrUnknownModule is returned when the requested module slug has no
// registered Importer.
var ErrUnknownModule = errors.New("unknown import module")

// Upload parses an in-memory CSV, auto-suggests a column mapping, runs an
// initial validation pass, persists everything in _imports, and returns
// the preview payload. Every Upload call also lazily sweeps expired rows.
func (e *Engine) Upload(module, user, filename string, r io.Reader, targetEstablishmentID *int64) (*PreviewResponse, error) {
	limited := io.LimitReader(r, MaxFileBytes+1)
	headers, rows, err := parseCSV(limited)
	if err != nil {
		return nil, fmt.Errorf("importer: parse csv: %w", err)
	}
	return e.UploadParsed(module, user, filename, headers, rows, targetEstablishmentID)
}

// UploadParsed is the shared entrypoint for already-parsed payloads. The
// CSV path calls it after parseCSV; the XLSX path in internal/server/api_import.go
// calls it after handing the workbook off to ratatoskr. Everything after
// parsing — mapping suggestion, validation, _imports persistence — is
// identical regardless of the source format.
func (e *Engine) UploadParsed(module, user, filename string, headers []string, rows []map[string]string, targetEstablishmentID *int64) (*PreviewResponse, error) {
	imp, ok := Get(module)
	if !ok {
		return nil, ErrUnknownModule
	}
	if len(rows) == 0 {
		return nil, errors.New("importer: no data rows")
	}

	mapping := SuggestMapping(headers, imp.TargetFields())
	token := newToken()
	now := time.Now().UTC()
	expires := now.Add(e.ttl())
	ctx := RowContext{EstablishmentID: targetEstablishmentID, UploadedBy: user, DB: e.DB}

	errs := validateAll(imp, rows, mapping, ctx)

	headersJSON, err := json.Marshal(headers)
	if err != nil {
		return nil, err
	}
	rowsJSON, err := json.Marshal(rows)
	if err != nil {
		return nil, err
	}
	mappingJSON, err := json.Marshal(mapping)
	if err != nil {
		return nil, err
	}
	errsJSON, err := json.Marshal(errs)
	if err != nil {
		return nil, err
	}

	if err := e.sweepExpired(); err != nil {
		return nil, err
	}
	if err := e.DB.ExecParams(
		`INSERT INTO _imports (
		     token, module, status, uploaded_by, uploaded_at, expires_at,
		     original_filename, row_count, target_establishment_id,
		     headers_json, rows_json, mapping_json, validation_errors_json)
		 VALUES (?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		token, module, user,
		now.Format(time.RFC3339), expires.Format(time.RFC3339),
		filename, len(rows), targetEstablishmentID,
		string(headersJSON), string(rowsJSON), string(mappingJSON), string(errsJSON),
	); err != nil {
		return nil, fmt.Errorf("importer: persist: %w", err)
	}

	return e.buildPreview(token, imp, "pending", user, now, expires, headers, rows, mapping, errs), nil
}

// GetStatus returns the current preview for a token.
func (e *Engine) GetStatus(token string) (*PreviewResponse, error) {
	state, imp, err := e.loadState(token)
	if err != nil {
		return nil, err
	}
	return e.buildPreview(token, imp, state.Status, state.UploadedBy, state.UploadedAt, state.ExpiresAt, state.Headers, state.Rows, state.Mapping, state.ValidationErrors), nil
}

// UpdateMapping replaces the mapping for a token and re-runs validation.
// Returns the refreshed preview.
func (e *Engine) UpdateMapping(token, user string, newMapping map[string]string) (*PreviewResponse, error) {
	state, imp, err := e.loadState(token)
	if err != nil {
		return nil, err
	}
	if state.Status != "pending" {
		return nil, ErrAlreadyCommitted
	}

	ctx := RowContext{EstablishmentID: state.TargetEstablishmentID, UploadedBy: user, DB: e.DB}
	errs := validateAll(imp, state.Rows, newMapping, ctx)

	mappingJSON, _ := json.Marshal(newMapping)
	errsJSON, _ := json.Marshal(errs)
	if err := e.DB.ExecParams(
		`UPDATE _imports
		    SET mapping_json = ?, validation_errors_json = ?
		  WHERE token = ?`,
		string(mappingJSON), string(errsJSON), token,
	); err != nil {
		return nil, fmt.Errorf("importer: update mapping: %w", err)
	}

	return e.buildPreview(token, imp, state.Status, state.UploadedBy, state.UploadedAt, state.ExpiresAt, state.Headers, state.Rows, newMapping, errs), nil
}

// Commit validates all rows one more time, inserts each valid row through
// the Importer.InsertRow path wrapped in a single SAVEPOINT, and writes a
// single aggregated audit entry. If skipInvalid is false, any validation
// error aborts the entire commit; if true, only the invalid rows are
// skipped and the valid ones land.
func (e *Engine) Commit(token, user string, skipInvalid bool) (*CommitResult, error) {
	state, imp, err := e.loadState(token)
	if err != nil {
		return nil, err
	}
	if state.Status != "pending" {
		return nil, ErrAlreadyCommitted
	}

	ctx := RowContext{EstablishmentID: state.TargetEstablishmentID, UploadedBy: user, DB: e.DB}
	errs := validateAll(imp, state.Rows, state.Mapping, ctx)
	invalidRows := map[int]bool{}
	for _, v := range errs {
		invalidRows[v.Row] = true
	}
	if len(errs) > 0 && !skipInvalid {
		return nil, fmt.Errorf("importer: %d validation error(s) — re-upload a corrected file or retry with skip_invalid", len(errs))
	}

	// One savepoint for the whole import.
	if err := e.DB.Exec("SAVEPOINT import_commit"); err != nil {
		return nil, fmt.Errorf("importer: savepoint: %w", err)
	}

	inserted, skipped := 0, 0
	for i, raw := range state.Rows {
		rowNum := i + 1
		if invalidRows[rowNum] {
			skipped++
			continue
		}
		payload, rowErrs := imp.ValidateRow(raw, state.Mapping, rowNum, ctx)
		if len(rowErrs) > 0 {
			// Revalidated clean a moment ago; if this fires something raced.
			skipped++
			continue
		}
		if _, insErr := imp.InsertRow(e.DB, payload, ctx); insErr != nil {
			_ = e.DB.Exec("ROLLBACK TO import_commit")
			return nil, fmt.Errorf("importer: insert row %d: %w", rowNum, insErr)
		}
		inserted++
	}

	if err := e.DB.Exec("RELEASE import_commit"); err != nil {
		return nil, fmt.Errorf("importer: release savepoint: %w", err)
	}

	committedAt := time.Now().UTC().Format(time.RFC3339)
	summary := fmt.Sprintf("Imported %d row%s into %s", inserted, pluralS(inserted), state.Module)
	if skipped > 0 {
		summary += fmt.Sprintf(" (%d skipped)", skipped)
	}

	if err := e.DB.ExecParams(
		`UPDATE _imports
		    SET status = 'committed',
		        committed_at = ?, committed_count = ?, skipped_count = ?
		  WHERE token = ?`,
		committedAt, inserted, skipped, token,
	); err != nil {
		return nil, fmt.Errorf("importer: mark committed: %w", err)
	}

	// One audit entry per import (per the plan) — not one per row.
	if e.Audit != nil {
		_ = e.Audit.Record(audit.Entry{
			Action:   audit.ActionCreate,
			Module:   "imports",
			EntityID: token,
			User:     user,
			Summary:  summary,
		})
	}

	return &CommitResult{
		Token:         token,
		Module:        state.Module,
		InsertedCount: inserted,
		SkippedCount:  skipped,
		CommittedAt:   committedAt,
		AuditSummary:  summary,
	}, nil
}

// Discard marks a pending token as discarded. No-op on non-pending tokens.
func (e *Engine) Discard(token, user string) error {
	return e.DB.ExecParams(
		`UPDATE _imports
		    SET status = 'discarded'
		  WHERE token = ? AND status = 'pending'`,
		token,
	)
}

// ---- Internal plumbing ----------------------------------------------------

type importState struct {
	Module                string
	Status                string
	UploadedBy            string
	UploadedAt            time.Time
	ExpiresAt             time.Time
	TargetEstablishmentID *int64
	Headers               []string
	Rows                  []map[string]string
	Mapping               map[string]string
	ValidationErrors      []ValidationError
}

func (e *Engine) loadState(token string) (*importState, Importer, error) {
	row, err := e.DB.QueryRow(
		`SELECT module, status, uploaded_by, uploaded_at, expires_at,
		        target_establishment_id,
		        headers_json, rows_json, mapping_json, validation_errors_json
		   FROM _imports WHERE token = ?`,
		token,
	)
	if err != nil {
		return nil, nil, fmt.Errorf("importer: load: %w", err)
	}
	if row == nil {
		return nil, nil, ErrNotFound
	}

	state := &importState{
		Module:     toStr(row["module"]),
		Status:     toStr(row["status"]),
		UploadedBy: toStr(row["uploaded_by"]),
	}
	if uploaded, err := time.Parse(time.RFC3339, toStr(row["uploaded_at"])); err == nil {
		state.UploadedAt = uploaded
	}
	if expires, err := time.Parse(time.RFC3339, toStr(row["expires_at"])); err == nil {
		state.ExpiresAt = expires
	}
	if v, ok := row["target_establishment_id"].(int64); ok {
		est := v
		state.TargetEstablishmentID = &est
	}
	_ = json.Unmarshal([]byte(toStr(row["headers_json"])), &state.Headers)
	_ = json.Unmarshal([]byte(toStr(row["rows_json"])), &state.Rows)
	_ = json.Unmarshal([]byte(toStr(row["mapping_json"])), &state.Mapping)
	_ = json.Unmarshal([]byte(toStr(row["validation_errors_json"])), &state.ValidationErrors)

	// Expire stale pending tokens (late-bind so callers see ErrExpired
	// without a separate sweep step).
	if state.Status == "pending" && !state.ExpiresAt.IsZero() && time.Now().After(state.ExpiresAt) {
		_ = e.DB.ExecParams(`UPDATE _imports SET status = 'expired' WHERE token = ?`, token)
		return nil, nil, ErrExpired
	}

	imp, ok := Get(state.Module)
	if !ok {
		return state, nil, ErrUnknownModule
	}
	return state, imp, nil
}

func (e *Engine) buildPreview(
	token string, imp Importer, status, user string,
	uploadedAt, expiresAt time.Time,
	headers []string,
	rows []map[string]string,
	mapping map[string]string,
	errs []ValidationError,
) *PreviewResponse {
	preview := rows
	if len(preview) > RowsPreviewLimit {
		preview = preview[:RowsPreviewLimit]
	}
	suggestions := SuggestMapping(headers, imp.TargetFields())
	return &PreviewResponse{
		Token:              token,
		Module:             imp.ModuleSlug(),
		Status:             status,
		Headers:            headers,
		MappingSuggestions: suggestions,
		Mapping:            mapping,
		RowCount:           len(rows),
		RowsPreview:        preview,
		ValidationErrors:   errs,
		TargetFields:       imp.TargetFields(),
		UploadedAt:         uploadedAt.Format(time.RFC3339),
		ExpiresAt:          expiresAt.Format(time.RFC3339),
	}
}

func (e *Engine) ttl() time.Duration {
	if e.TTL > 0 {
		return e.TTL
	}
	return DefaultTTL
}

// sweepExpired drops pending tokens past their expires_at. Cheap enough
// to run opportunistically on every Upload.
func (e *Engine) sweepExpired() error {
	return e.DB.ExecParams(
		`UPDATE _imports
		    SET status = 'expired'
		  WHERE status = 'pending' AND expires_at < ?`,
		time.Now().UTC().Format(time.RFC3339),
	)
}

func validateAll(
	imp Importer,
	rows []map[string]string,
	mapping map[string]string,
	ctx RowContext,
) []ValidationError {
	// Initialize as empty slice, not nil, so json.Marshal emits `[]` and
	// the frontend can iterate it without a null check.
	out := []ValidationError{}
	for i, raw := range rows {
		_, errs := imp.ValidateRow(raw, mapping, i+1, ctx)
		out = append(out, errs...)
	}
	return out
}

func parseCSV(r io.Reader) ([]string, []map[string]string, error) {
	reader := csv.NewReader(r)
	reader.TrimLeadingSpace = true
	reader.FieldsPerRecord = -1 // tolerant of ragged rows

	headerRow, err := reader.Read()
	if err != nil {
		return nil, nil, fmt.Errorf("read header: %w", err)
	}
	// Strip UTF-8 BOM off the first header if present.
	if len(headerRow) > 0 {
		headerRow[0] = strings.TrimPrefix(headerRow[0], "\ufeff")
	}
	headers := make([]string, len(headerRow))
	for i, h := range headerRow {
		headers[i] = strings.TrimSpace(h)
	}

	var rows []map[string]string
	for {
		rec, err := reader.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, nil, fmt.Errorf("read row: %w", err)
		}
		m := map[string]string{}
		for i, h := range headers {
			if h == "" || i >= len(rec) {
				continue
			}
			m[h] = strings.TrimSpace(rec[i])
		}
		rows = append(rows, m)
	}
	return headers, rows, nil
}

func newToken() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}

func toStr(v any) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	return fmt.Sprint(v)
}

func pluralS(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}
