package schemabuilder

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/asgardehs/odin/internal/database"
)

// Executor performs the write half of the schema builder: creating
// tables, adding fields, deactivating metadata rows. Every mutation
// records a row in _custom_table_versions inside the same transaction
// that performs the DDL, so the version log cannot drift from reality.
//
// The Executor composes a Validator — every input is validated before
// any DDL runs.
type Executor struct {
	DB        *database.DB
	Validator *Validator
}

// NewExecutor returns an Executor bound to db.
func NewExecutor(db *database.DB) *Executor {
	return &Executor{DB: db, Validator: NewValidator(db)}
}

// ============================================================
// CreateTable — metadata row + CREATE TABLE cx_{name}
// ============================================================

// CreateTable validates the input, inserts the metadata row, executes
// `CREATE TABLE cx_{name}` with the auto-added system columns, and
// records a version entry. All of these happen inside a single
// savepoint so a failure anywhere rolls the whole change back.
func (e *Executor) CreateTable(user string, in CustomTableInput) (int64, error) {
	if err := e.Validator.ValidateTableInput(in); err != nil {
		return 0, err
	}

	var newID int64
	err := e.withSavepoint("create_table", func() error {
		if err := e.DB.ExecParams(
			`INSERT INTO _custom_tables (name, display_name, description, icon)
			 VALUES (?, ?, ?, ?)`,
			in.Name, in.DisplayName, in.Description, in.Icon,
		); err != nil {
			return fmt.Errorf("insert metadata: %w", err)
		}

		id, err := lastInsertID(e.DB)
		if err != nil {
			return err
		}
		newID = id

		physical := TablePrefix + in.Name
		// Identifier is validated by ValidateTableInput so it is safe
		// to interpolate. SQLite `CREATE TABLE` does not accept bind
		// params for identifiers.
		createSQL := fmt.Sprintf(
			`CREATE TABLE %s (
				id                INTEGER PRIMARY KEY AUTOINCREMENT,
				establishment_id  INTEGER,
				created_at        TEXT NOT NULL DEFAULT (datetime('now')),
				updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
			)`,
			quoteIdent(physical),
		)
		if err := e.DB.Exec(createSQL); err != nil {
			return fmt.Errorf("create table: %w", err)
		}
		idxSQL := fmt.Sprintf(
			`CREATE INDEX %s ON %s (establishment_id)`,
			quoteIdent("idx_"+physical+"_establishment"),
			quoteIdent(physical),
		)
		if err := e.DB.Exec(idxSQL); err != nil {
			return fmt.Errorf("create index: %w", err)
		}

		payload, _ := json.Marshal(map[string]any{
			"name":         in.Name,
			"display_name": in.DisplayName,
			"physical":     physical,
		})
		return e.recordVersion(newID, "create_table", payload, user)
	})
	if err != nil {
		return 0, err
	}
	return newID, nil
}

// ============================================================
// AddField — metadata row + ALTER TABLE cx_{name} ADD COLUMN
// ============================================================

// AddField validates the input, inserts the metadata row, runs
// `ALTER TABLE ... ADD COLUMN ...` on the backing SQLite table, and
// records a version entry. All transactional.
func (e *Executor) AddField(user string, tableID int64, in CustomFieldInput) (int64, error) {
	if err := e.Validator.ValidateFieldInput(tableID, in); err != nil {
		return 0, err
	}

	table, err := e.loadTable(tableID)
	if err != nil {
		return 0, err
	}
	if !table.IsActive {
		return 0, fmt.Errorf("cannot add field to inactive table %d", tableID)
	}

	var newID int64
	err = e.withSavepoint("add_field", func() error {
		if err := e.DB.ExecParams(
			`INSERT INTO _custom_fields (
				custom_table_id, name, display_name, field_type,
				is_required, default_value, config, display_order
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			tableID, in.Name, in.DisplayName, string(in.FieldType),
			boolToInt(in.IsRequired), in.DefaultValue,
			jsonBytesOrNil(in.Config), in.DisplayOrder,
		); err != nil {
			return fmt.Errorf("insert field metadata: %w", err)
		}

		id, err := lastInsertID(e.DB)
		if err != nil {
			return err
		}
		newID = id

		// ALTER TABLE cx_{name} ADD COLUMN {field} {sqliteType}
		alterSQL := fmt.Sprintf(
			`ALTER TABLE %s ADD COLUMN %s %s`,
			quoteIdent(table.PhysicalName()),
			quoteIdent(in.Name),
			in.FieldType.SQLiteType(),
		)
		if err := e.DB.Exec(alterSQL); err != nil {
			return fmt.Errorf("alter table: %w", err)
		}

		payload, _ := json.Marshal(map[string]any{
			"field_id":    newID,
			"name":        in.Name,
			"field_type":  in.FieldType,
			"is_required": in.IsRequired,
		})
		return e.recordVersion(tableID, "add_field", payload, user)
	})
	if err != nil {
		return 0, err
	}
	return newID, nil
}

// ============================================================
// AddRelation — metadata only (FK column already exists)
// ============================================================

// AddRelation validates the input and inserts a _custom_relations row.
// No DDL runs: the FK column was added when the relation-typed field
// itself was created via AddField.
func (e *Executor) AddRelation(user string, tableID int64, in CustomRelationInput) (int64, error) {
	if err := e.Validator.ValidateRelationInput(in); err != nil {
		return 0, err
	}

	// Source field must belong to the named table.
	row, err := e.DB.QueryRow(
		`SELECT custom_table_id FROM _custom_fields WHERE id = ?`,
		in.SourceFieldID,
	)
	if err != nil {
		return 0, fmt.Errorf("load source field table: %w", err)
	}
	if row == nil {
		return 0, fmt.Errorf("source field %d not found", in.SourceFieldID)
	}
	if ownerID, _ := row["custom_table_id"].(int64); ownerID != tableID {
		return 0, fmt.Errorf("source field %d does not belong to table %d", in.SourceFieldID, tableID)
	}

	var newID int64
	err = e.withSavepoint("add_relation", func() error {
		if err := e.DB.ExecParams(
			`INSERT INTO _custom_relations (
				source_table_id, source_field_id, target_table_name,
				display_field, relation_type
			) VALUES (?, ?, ?, ?, ?)`,
			tableID, in.SourceFieldID, in.TargetTableName,
			in.DisplayField, string(in.RelationType),
		); err != nil {
			return fmt.Errorf("insert relation metadata: %w", err)
		}

		id, err := lastInsertID(e.DB)
		if err != nil {
			return err
		}
		newID = id

		payload, _ := json.Marshal(map[string]any{
			"relation_id":        newID,
			"source_field_id":    in.SourceFieldID,
			"target_table_name":  in.TargetTableName,
			"display_field":      in.DisplayField,
			"relation_type":      in.RelationType,
		})
		return e.recordVersion(tableID, "add_relation", payload, user)
	})
	if err != nil {
		return 0, err
	}
	return newID, nil
}

// ============================================================
// Deactivation (metadata-only; DDL is additive)
// ============================================================

// DeactivateField flips is_active = 0 on a field. The SQLite column
// is left in place. Returns an error if the field does not exist.
func (e *Executor) DeactivateField(user string, fieldID int64) error {
	row, err := e.DB.QueryRow(
		`SELECT custom_table_id, name FROM _custom_fields WHERE id = ?`,
		fieldID,
	)
	if err != nil {
		return fmt.Errorf("load field: %w", err)
	}
	if row == nil {
		return fmt.Errorf("field %d not found", fieldID)
	}
	tableID, _ := row["custom_table_id"].(int64)
	name, _ := row["name"].(string)

	return e.withSavepoint("deactivate_field", func() error {
		if err := e.DB.ExecParams(
			`UPDATE _custom_fields SET is_active = 0, updated_at = datetime('now')
			 WHERE id = ?`, fieldID,
		); err != nil {
			return fmt.Errorf("deactivate field: %w", err)
		}
		payload, _ := json.Marshal(map[string]any{
			"field_id": fieldID,
			"name":     name,
		})
		return e.recordVersion(tableID, "deactivate_field", payload, user)
	})
}

// DeactivateRelation flips is_active = 0 on a relation.
func (e *Executor) DeactivateRelation(user string, relationID int64) error {
	row, err := e.DB.QueryRow(
		`SELECT source_table_id FROM _custom_relations WHERE id = ?`,
		relationID,
	)
	if err != nil {
		return fmt.Errorf("load relation: %w", err)
	}
	if row == nil {
		return fmt.Errorf("relation %d not found", relationID)
	}
	tableID, _ := row["source_table_id"].(int64)

	return e.withSavepoint("deactivate_relation", func() error {
		if err := e.DB.ExecParams(
			`UPDATE _custom_relations SET is_active = 0, updated_at = datetime('now')
			 WHERE id = ?`, relationID,
		); err != nil {
			return fmt.Errorf("deactivate relation: %w", err)
		}
		payload, _ := json.Marshal(map[string]any{"relation_id": relationID})
		return e.recordVersion(tableID, "deactivate_relation", payload, user)
	})
}

// DeactivateTable flips is_active = 0 on a table. The SQLite table
// and all data remain. ReactivateTable reverses this.
func (e *Executor) DeactivateTable(user string, tableID int64) error {
	return e.flipTableActive(user, tableID, false, "deactivate_table")
}

// ReactivateTable flips is_active = 1 on a previously-deactivated table.
func (e *Executor) ReactivateTable(user string, tableID int64) error {
	return e.flipTableActive(user, tableID, true, "reactivate_table")
}

func (e *Executor) flipTableActive(user string, tableID int64, active bool, changeType string) error {
	row, err := e.DB.QueryRow(
		`SELECT name FROM _custom_tables WHERE id = ?`, tableID,
	)
	if err != nil {
		return fmt.Errorf("load table: %w", err)
	}
	if row == nil {
		return fmt.Errorf("table %d not found", tableID)
	}
	name, _ := row["name"].(string)

	return e.withSavepoint(changeType, func() error {
		if err := e.DB.ExecParams(
			`UPDATE _custom_tables SET is_active = ?, updated_at = datetime('now')
			 WHERE id = ?`, boolToInt(active), tableID,
		); err != nil {
			return fmt.Errorf("flip table active: %w", err)
		}
		payload, _ := json.Marshal(map[string]any{
			"table_id": tableID,
			"name":     name,
			"active":   active,
		})
		return e.recordVersion(tableID, changeType, payload, user)
	})
}

// ============================================================
// Read helpers
// ============================================================

// LoadTable returns a CustomTable populated with all of its fields
// and relations (active and inactive). Returns nil, nil if the id is
// unknown.
func (e *Executor) LoadTable(tableID int64) (*CustomTable, error) {
	return e.loadTable(tableID)
}

// ListTables returns all custom tables. If activeOnly is true, only
// active tables are returned. Fields and relations are NOT populated
// — call LoadTable for a full detail view.
func (e *Executor) ListTables(activeOnly bool) ([]CustomTable, error) {
	q := `SELECT id, name, display_name, description, icon,
	             display_order, is_active, created_at, updated_at
	      FROM _custom_tables`
	if activeOnly {
		q += ` WHERE is_active = 1`
	}
	q += ` ORDER BY display_order, display_name`
	rows, err := e.DB.QueryRows(q)
	if err != nil {
		return nil, err
	}
	out := make([]CustomTable, 0, len(rows))
	for _, r := range rows {
		out = append(out, tableFromRow(r))
	}
	return out, nil
}

// ListVersions returns the DDL history for a single custom table,
// most recent first.
func (e *Executor) ListVersions(tableID int64) ([]TableVersion, error) {
	rows, err := e.DB.QueryRows(
		`SELECT id, custom_table_id, change_type, change_payload,
		        changed_by, changed_at
		 FROM _custom_table_versions
		 WHERE custom_table_id = ?
		 ORDER BY changed_at DESC, id DESC`, tableID,
	)
	if err != nil {
		return nil, err
	}
	out := make([]TableVersion, 0, len(rows))
	for _, r := range rows {
		payload, _ := r["change_payload"].(string)
		out = append(out, TableVersion{
			ID:            asInt64(r["id"]),
			CustomTableID: asInt64(r["custom_table_id"]),
			ChangeType:    asString(r["change_type"]),
			ChangePayload: json.RawMessage(payload),
			ChangedBy:     asString(r["changed_by"]),
			ChangedAt:     asString(r["changed_at"]),
		})
	}
	return out, nil
}

func (e *Executor) loadTable(tableID int64) (*CustomTable, error) {
	row, err := e.DB.QueryRow(
		`SELECT id, name, display_name, description, icon,
		        display_order, is_active, created_at, updated_at
		 FROM _custom_tables WHERE id = ?`, tableID,
	)
	if err != nil {
		return nil, err
	}
	if row == nil {
		return nil, nil
	}
	t := tableFromRow(row)
	t.Fields = []CustomField{}
	t.Relations = []CustomRelation{}

	// Fields.
	fieldRows, err := e.DB.QueryRows(
		`SELECT id, custom_table_id, name, display_name, field_type,
		        is_required, default_value, config, display_order,
		        is_active, created_at, updated_at
		 FROM _custom_fields WHERE custom_table_id = ?
		 ORDER BY display_order, id`, tableID,
	)
	if err != nil {
		return nil, err
	}
	for _, r := range fieldRows {
		t.Fields = append(t.Fields, fieldFromRow(r))
	}

	// Relations.
	relRows, err := e.DB.QueryRows(
		`SELECT id, source_table_id, source_field_id, target_table_name,
		        display_field, relation_type, is_active, created_at, updated_at
		 FROM _custom_relations WHERE source_table_id = ?
		 ORDER BY id`, tableID,
	)
	if err != nil {
		return nil, err
	}
	for _, r := range relRows {
		t.Relations = append(t.Relations, relationFromRow(r))
	}

	return &t, nil
}

// ============================================================
// Internals
// ============================================================

// withSavepoint runs fn inside a named SQLite savepoint. On error, the
// savepoint is rolled back and the original error returned; on nil,
// the savepoint is released (committed into the enclosing transaction
// or into the database directly if there is no outer transaction).
func (e *Executor) withSavepoint(name string, fn func() error) error {
	sp := "sb_" + sanitizeSavepoint(name)
	if err := e.DB.Exec("SAVEPOINT " + sp); err != nil {
		return fmt.Errorf("savepoint %s: %w", name, err)
	}
	if err := fn(); err != nil {
		_ = e.DB.Exec("ROLLBACK TO " + sp)
		_ = e.DB.Exec("RELEASE " + sp)
		return err
	}
	if err := e.DB.Exec("RELEASE " + sp); err != nil {
		return fmt.Errorf("release savepoint %s: %w", name, err)
	}
	return nil
}

func (e *Executor) recordVersion(tableID int64, changeType string, payload json.RawMessage, user string) error {
	return e.DB.ExecParams(
		`INSERT INTO _custom_table_versions
		        (custom_table_id, change_type, change_payload, changed_by)
		 VALUES (?, ?, ?, ?)`,
		tableID, changeType, string(payload), user,
	)
}

// quoteIdent wraps an identifier in double quotes and escapes embedded
// quotes, per SQLite's quoting rules. Callers MUST have validated the
// identifier (regex or known-safe source) before calling — quoting is
// a belt-and-braces defense, not a substitute for validation.
func quoteIdent(id string) string {
	return `"` + strings.ReplaceAll(id, `"`, `""`) + `"`
}

// sanitizeSavepoint strips anything not suitable as an identifier.
func sanitizeSavepoint(s string) string {
	var b strings.Builder
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_' {
			b.WriteRune(r)
		}
	}
	if b.Len() == 0 {
		return "sp"
	}
	return b.String()
}

func lastInsertID(db *database.DB) (int64, error) {
	v, err := db.QueryVal("SELECT last_insert_rowid()")
	if err != nil {
		return 0, fmt.Errorf("last_insert_rowid: %w", err)
	}
	id, ok := v.(int64)
	if !ok {
		return 0, fmt.Errorf("last_insert_rowid returned %T", v)
	}
	return id, nil
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

func jsonBytesOrNil(raw json.RawMessage) *string {
	if len(raw) == 0 {
		return nil
	}
	s := string(raw)
	return &s
}

// ============================================================
// Row-to-struct helpers
// ============================================================

func tableFromRow(r database.Row) CustomTable {
	return CustomTable{
		ID:           asInt64(r["id"]),
		Name:         asString(r["name"]),
		DisplayName:  asString(r["display_name"]),
		Description:  asOptString(r["description"]),
		Icon:         asOptString(r["icon"]),
		DisplayOrder: int(asInt64(r["display_order"])),
		IsActive:     asInt64(r["is_active"]) == 1,
		CreatedAt:    asString(r["created_at"]),
		UpdatedAt:    asString(r["updated_at"]),
	}
}

func fieldFromRow(r database.Row) CustomField {
	cfg := asString(r["config"])
	var raw json.RawMessage
	if cfg != "" {
		raw = json.RawMessage(cfg)
	}
	return CustomField{
		ID:            asInt64(r["id"]),
		CustomTableID: asInt64(r["custom_table_id"]),
		Name:          asString(r["name"]),
		DisplayName:   asString(r["display_name"]),
		FieldType:     FieldType(asString(r["field_type"])),
		IsRequired:    asInt64(r["is_required"]) == 1,
		DefaultValue:  asOptString(r["default_value"]),
		Config:        raw,
		DisplayOrder:  int(asInt64(r["display_order"])),
		IsActive:      asInt64(r["is_active"]) == 1,
		CreatedAt:     asString(r["created_at"]),
		UpdatedAt:     asString(r["updated_at"]),
	}
}

func relationFromRow(r database.Row) CustomRelation {
	return CustomRelation{
		ID:              asInt64(r["id"]),
		SourceTableID:   asInt64(r["source_table_id"]),
		SourceFieldID:   asInt64(r["source_field_id"]),
		TargetTableName: asString(r["target_table_name"]),
		DisplayField:    asString(r["display_field"]),
		RelationType:    RelationType(asString(r["relation_type"])),
		IsActive:        asInt64(r["is_active"]) == 1,
		CreatedAt:       asString(r["created_at"]),
		UpdatedAt:       asString(r["updated_at"]),
	}
}

func asInt64(v any) int64 {
	if v == nil {
		return 0
	}
	if n, ok := v.(int64); ok {
		return n
	}
	return 0
}

func asString(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func asOptString(v any) *string {
	if s, ok := v.(string); ok && s != "" {
		return &s
	}
	return nil
}
