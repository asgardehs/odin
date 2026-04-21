package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/asgardehs/odin/internal/audit"
	"github.com/asgardehs/odin/internal/schemabuilder"
)

// schemaRoutes registers the schema-builder HTTP API. All /api/schema/*
// routes require admin role. Record routes (/api/records/*) require a
// valid session — matching the permissive posture the pre-built
// modules use; destructive-gating happens in the frontend today.
func (s *Server) schemaRoutes() {
	if s.schemaExec == nil {
		return
	}

	// -- Schema management (admin-only) --
	s.mux.HandleFunc("POST   /api/schema/tables", s.handleSchemaCreateTable)
	s.mux.HandleFunc("GET    /api/schema/tables", s.handleSchemaListTables)
	s.mux.HandleFunc("GET    /api/schema/tables/{id}", s.handleSchemaGetTable)
	s.mux.HandleFunc("POST   /api/schema/tables/{id}/deactivate", s.handleSchemaDeactivateTable)
	s.mux.HandleFunc("POST   /api/schema/tables/{id}/reactivate", s.handleSchemaReactivateTable)
	s.mux.HandleFunc("POST   /api/schema/tables/{id}/fields", s.handleSchemaAddField)
	s.mux.HandleFunc("POST   /api/schema/tables/{id}/fields/{fid}/deactivate", s.handleSchemaDeactivateField)
	s.mux.HandleFunc("POST   /api/schema/tables/{id}/relations", s.handleSchemaAddRelation)
	s.mux.HandleFunc("POST   /api/schema/tables/{id}/relations/{rid}/deactivate", s.handleSchemaDeactivateRelation)
	s.mux.HandleFunc("GET    /api/schema/tables/{id}/versions", s.handleSchemaListVersions)

	// -- Record CRUD (any authed user) --
	s.mux.HandleFunc("GET    /api/records/{slug}", s.handleRecordList)
	s.mux.HandleFunc("GET    /api/records/{slug}/_schema", s.handleRecordSchema)
	s.mux.HandleFunc("GET    /api/records/{slug}/{id}", s.handleRecordGet)
	s.mux.HandleFunc("POST   /api/records/{slug}", s.handleRecordCreate)
	s.mux.HandleFunc("PUT    /api/records/{slug}/{id}", s.handleRecordUpdate)
	s.mux.HandleFunc("DELETE /api/records/{slug}/{id}", s.handleRecordDelete)
}

// handleRecordSchema returns the active custom table's metadata
// (fields + relations) scoped to a slug. Accessible to any authed
// user so the generic record UI can render without admin rights;
// the write-side schema routes stay admin-only.
func (s *Server) handleRecordSchema(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}
	tbl, ok := s.resolveActiveSlug(w, r)
	if !ok {
		return
	}
	writeJSON(w, tbl)
}

// ============================================================
// Schema management
// ============================================================

func (s *Server) handleSchemaCreateTable(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	var in schemabuilder.CustomTableInput
	if err := readJSON(r, &in); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	id, err := s.schemaExec.CreateTable(admin.Username, in)
	if err != nil {
		writeError(w, err.Error(), schemaErrorStatus(err))
		return
	}
	s.recordSchemaAudit(admin.Username, audit.ActionCreate, id,
		fmt.Sprintf("Created custom table %q (cx_%s)", in.DisplayName, in.Name),
		mustJSON(in))
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, map[string]int64{"id": id})
}

func (s *Server) handleSchemaListTables(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	activeOnly := r.URL.Query().Get("active") == "1"
	tables, err := s.schemaExec.ListTables(activeOnly)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"tables": tables})
}

func (s *Server) handleSchemaGetTable(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	id, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}
	table, err := s.schemaExec.LoadTable(id)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if table == nil {
		writeError(w, "table not found", http.StatusNotFound)
		return
	}
	writeJSON(w, table)
}

func (s *Server) handleSchemaDeactivateTable(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	id, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}
	if err := s.schemaExec.DeactivateTable(admin.Username, id); err != nil {
		writeError(w, err.Error(), schemaErrorStatus(err))
		return
	}
	s.recordSchemaAudit(admin.Username, audit.ActionUpdate, id,
		fmt.Sprintf("Deactivated custom table %d", id), nil)
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleSchemaReactivateTable(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	id, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}
	if err := s.schemaExec.ReactivateTable(admin.Username, id); err != nil {
		writeError(w, err.Error(), schemaErrorStatus(err))
		return
	}
	s.recordSchemaAudit(admin.Username, audit.ActionUpdate, id,
		fmt.Sprintf("Reactivated custom table %d", id), nil)
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleSchemaAddField(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	tableID, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}
	var in schemabuilder.CustomFieldInput
	if err := readJSON(r, &in); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	fieldID, err := s.schemaExec.AddField(admin.Username, tableID, in)
	if err != nil {
		writeError(w, err.Error(), schemaErrorStatus(err))
		return
	}
	s.recordSchemaAudit(admin.Username, audit.ActionUpdate, tableID,
		fmt.Sprintf("Added field %q (%s) to custom table %d", in.Name, in.FieldType, tableID),
		mustJSON(in))
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, map[string]int64{"id": fieldID})
}

func (s *Server) handleSchemaDeactivateField(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	tableID, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}
	fieldID, err := strconv.ParseInt(r.PathValue("fid"), 10, 64)
	if err != nil {
		writeError(w, "invalid field id", http.StatusBadRequest)
		return
	}
	if err := s.schemaExec.DeactivateField(admin.Username, fieldID); err != nil {
		writeError(w, err.Error(), schemaErrorStatus(err))
		return
	}
	s.recordSchemaAudit(admin.Username, audit.ActionUpdate, tableID,
		fmt.Sprintf("Deactivated field %d on custom table %d", fieldID, tableID), nil)
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleSchemaAddRelation(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	tableID, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}
	var in schemabuilder.CustomRelationInput
	if err := readJSON(r, &in); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	relID, err := s.schemaExec.AddRelation(admin.Username, tableID, in)
	if err != nil {
		writeError(w, err.Error(), schemaErrorStatus(err))
		return
	}
	s.recordSchemaAudit(admin.Username, audit.ActionUpdate, tableID,
		fmt.Sprintf("Added relation to %q on custom table %d", in.TargetTableName, tableID),
		mustJSON(in))
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, map[string]int64{"id": relID})
}

func (s *Server) handleSchemaDeactivateRelation(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	tableID, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}
	relID, err := strconv.ParseInt(r.PathValue("rid"), 10, 64)
	if err != nil {
		writeError(w, "invalid relation id", http.StatusBadRequest)
		return
	}
	if err := s.schemaExec.DeactivateRelation(admin.Username, relID); err != nil {
		writeError(w, err.Error(), schemaErrorStatus(err))
		return
	}
	s.recordSchemaAudit(admin.Username, audit.ActionUpdate, tableID,
		fmt.Sprintf("Deactivated relation %d on custom table %d", relID, tableID), nil)
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleSchemaListVersions(w http.ResponseWriter, r *http.Request) {
	admin := s.requireAdmin(w, r)
	if admin == nil {
		return
	}
	id, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}
	versions, err := s.schemaExec.ListVersions(id)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"versions": versions})
}

// ============================================================
// Record CRUD (generic over any active cx_* table)
// ============================================================

func (s *Server) handleRecordList(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}
	tbl, ok := s.resolveActiveSlug(w, r)
	if !ok {
		return
	}

	page := 1
	if v := r.URL.Query().Get("page"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			page = n
		}
	}
	perPage := parsePerPage(r)

	opts := schemabuilder.SelectOpts{
		Search:        r.URL.Query().Get("q"),
		JoinRelations: true,
		Limit:         perPage,
		Offset:        (page - 1) * perPage,
	}
	if est := r.URL.Query().Get("establishment_id"); est != "" {
		if n, err := strconv.ParseInt(est, 10, 64); err == nil {
			opts.EstablishmentID = &n
		}
	}

	countSQL, countArgs, err := s.schemaQB.Count(tbl.ID, opts)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	totalVal, err := s.db.QueryVal(countSQL, countArgs...)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	var total int64
	if totalVal != nil {
		total, _ = totalVal.(int64)
	}

	listSQL, listArgs, err := s.schemaQB.Select(tbl.ID, opts)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	rows, err := s.db.QueryRows(listSQL, listArgs...)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	// Ensure the JSON is [] rather than null when there are no rows.
	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		out = append(out, r)
	}
	totalPages := int(total) / perPage
	if int(total)%perPage != 0 {
		totalPages++
	}
	writeJSON(w, map[string]any{
		"data":        out,
		"total":       total,
		"page":        page,
		"per_page":    perPage,
		"total_pages": totalPages,
	})
}

func (s *Server) handleRecordGet(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}
	tbl, ok := s.resolveActiveSlug(w, r)
	if !ok {
		return
	}
	id, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}

	sql, args, err := s.schemaQB.SelectByID(tbl.ID, id)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	row, err := s.db.QueryRow(sql, args...)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if row == nil {
		writeError(w, "record not found", http.StatusNotFound)
		return
	}
	writeJSON(w, row)
}

func (s *Server) handleRecordCreate(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}
	tbl, ok := s.resolveActiveSlug(w, r)
	if !ok {
		return
	}

	var values map[string]any
	if err := readJSON(r, &values); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	sql, args, err := s.schemaQB.Insert(tbl.ID, values)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := s.db.ExecParams(sql, args...); err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	idVal, err := s.db.QueryVal("SELECT last_insert_rowid()")
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}
	newID, _ := idVal.(int64)

	s.recordRowAudit(user.Username, tbl, audit.ActionCreate, newID,
		fmt.Sprintf("Created %s row %d", tbl.PhysicalName(), newID),
		nil, s.snapshotRecord(tbl, newID))

	w.WriteHeader(http.StatusCreated)
	writeJSON(w, map[string]int64{"id": newID})
}

func (s *Server) handleRecordUpdate(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}
	tbl, ok := s.resolveActiveSlug(w, r)
	if !ok {
		return
	}
	id, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}

	before := s.snapshotRecord(tbl, id)
	if before == nil {
		writeError(w, "record not found", http.StatusNotFound)
		return
	}

	var values map[string]any
	if err := readJSON(r, &values); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	sql, args, err := s.schemaQB.Update(tbl.ID, id, values)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := s.db.ExecParams(sql, args...); err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	s.recordRowAudit(user.Username, tbl, audit.ActionUpdate, id,
		fmt.Sprintf("Updated %s row %d", tbl.PhysicalName(), id),
		before, s.snapshotRecord(tbl, id))

	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleRecordDelete(w http.ResponseWriter, r *http.Request) {
	user := s.requireAuth(w, r)
	if user == nil {
		return
	}
	tbl, ok := s.resolveActiveSlug(w, r)
	if !ok {
		return
	}
	id, err := parseID(r)
	if err != nil {
		writeError(w, "invalid id", http.StatusBadRequest)
		return
	}

	before := s.snapshotRecord(tbl, id)
	if before == nil {
		writeError(w, "record not found", http.StatusNotFound)
		return
	}

	sql, args, err := s.schemaQB.Delete(tbl.ID, id)
	if err != nil {
		writeError(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := s.db.ExecParams(sql, args...); err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	s.recordRowAudit(user.Username, tbl, audit.ActionDelete, id,
		fmt.Sprintf("Deleted %s row %d", tbl.PhysicalName(), id),
		before, nil)

	writeJSON(w, map[string]string{"status": "ok"})
}

// ============================================================
// Helpers
// ============================================================

// resolveActiveSlug reads {slug} from the request path and loads the
// corresponding active custom table. Writes a 404 and returns ok=false
// if the slug is unknown or inactive.
func (s *Server) resolveActiveSlug(w http.ResponseWriter, r *http.Request) (*schemabuilder.CustomTable, bool) {
	slug := strings.TrimSpace(r.PathValue("slug"))
	if slug == "" {
		writeError(w, "missing slug", http.StatusBadRequest)
		return nil, false
	}
	row, err := s.db.QueryRow(
		`SELECT id FROM _custom_tables WHERE name = ? AND is_active = 1`,
		slug,
	)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return nil, false
	}
	if row == nil {
		writeError(w, "table not found", http.StatusNotFound)
		return nil, false
	}
	id, _ := row["id"].(int64)
	tbl, err := s.schemaExec.LoadTable(id)
	if err != nil {
		writeError(w, err.Error(), http.StatusInternalServerError)
		return nil, false
	}
	if tbl == nil || !tbl.IsActive {
		writeError(w, "table not found", http.StatusNotFound)
		return nil, false
	}
	return tbl, true
}

// snapshotRecord fetches a row's current state as JSON for use in
// audit before/after diffs. Returns nil if the row is missing.
func (s *Server) snapshotRecord(tbl *schemabuilder.CustomTable, id int64) json.RawMessage {
	sql, args, err := s.schemaQB.SelectByID(tbl.ID, id)
	if err != nil {
		return nil
	}
	row, err := s.db.QueryRow(sql, args...)
	if err != nil || row == nil {
		return nil
	}
	data, err := json.Marshal(row)
	if err != nil {
		return nil
	}
	return data
}

// recordRowAudit writes an audit entry for a mutation on a custom
// table row. Errors are silently dropped — the mutation has already
// succeeded by this point, and audit failures should not roll it back.
func (s *Server) recordRowAudit(user string, tbl *schemabuilder.CustomTable, action audit.Action,
	id int64, summary string, before, after json.RawMessage) {
	if s.audit == nil {
		return
	}
	_ = s.audit.Record(audit.Entry{
		Action:   action,
		Module:   tbl.PhysicalName(),
		EntityID: strconv.FormatInt(id, 10),
		User:     user,
		Summary:  summary,
		Before:   before,
		After:    after,
	})
}

// recordSchemaAudit mirrors a DDL change into the git-backed audit log
// under module="schema". This is additive to _custom_table_versions
// (the authoritative DDL history), giving admins a single timeline.
func (s *Server) recordSchemaAudit(user string, action audit.Action, tableID int64, summary string, payload json.RawMessage) {
	if s.audit == nil {
		return
	}
	_ = s.audit.Record(audit.Entry{
		Action:   action,
		Module:   "schema",
		EntityID: strconv.FormatInt(tableID, 10),
		User:     user,
		Summary:  summary,
		After:    payload,
	})
}

// schemaErrorStatus maps schemabuilder errors to HTTP status codes.
// Validator errors become 400; not-found errors become 404; everything
// else falls through as 500.
func schemaErrorStatus(err error) int {
	if err == nil {
		return http.StatusOK
	}
	msg := err.Error()
	if strings.Contains(msg, "not found") {
		return http.StatusNotFound
	}
	if strings.Contains(msg, "is required") ||
		strings.Contains(msg, "must match") ||
		strings.Contains(msg, "reserved") ||
		strings.Contains(msg, "invalid") ||
		strings.Contains(msg, "already exists") ||
		strings.Contains(msg, "collides") ||
		strings.Contains(msg, "required field") ||
		strings.Contains(msg, "no known columns") ||
		strings.Contains(msg, "inactive") ||
		strings.Contains(msg, "does not exist") ||
		strings.Contains(msg, "has no column") ||
		strings.Contains(msg, "not a permitted") ||
		strings.Contains(msg, "does not belong") ||
		strings.Contains(msg, "must be of type") {
		return http.StatusBadRequest
	}
	return http.StatusInternalServerError
}

func readJSON(r *http.Request, into any) error {
	body, err := readBody(r)
	if err != nil {
		return err
	}
	if len(body) == 0 {
		return errors.New("empty body")
	}
	return json.Unmarshal(body, into)
}

func mustJSON(v any) json.RawMessage {
	data, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	return data
}

// parsePerPage reads ?per_page=N from the request, clamping to
// [1, 500] with a default of 50.
func parsePerPage(r *http.Request) int {
	raw := r.URL.Query().Get("per_page")
	if raw == "" {
		return 50
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < 1 {
		return 50
	}
	if n > 500 {
		return 500
	}
	return n
}
