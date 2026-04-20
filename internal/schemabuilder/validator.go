package schemabuilder

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/asgardehs/odin/internal/database"
)

// tableNameRegex matches a valid custom-table metadata name (without
// the `cx_` prefix). Length 2-59 yields a physical name ≤62 chars.
var tableNameRegex = regexp.MustCompile(`^[a-z][a-z0-9_]{1,58}$`)

// fieldNameRegex matches a valid field name. Length 2-63.
var fieldNameRegex = regexp.MustCompile(`^[a-z][a-z0-9_]{1,62}$`)

// Validator checks proposed schema changes against regex, reserved
// names, table collisions, and relation target validity.
//
// A Validator holds a DB handle so it can introspect existing tables
// (via sqlite_master) and existing custom metadata. No state is cached
// — every call re-reads the DB so concurrent admins see current state.
type Validator struct {
	DB *database.DB
}

// NewValidator returns a Validator bound to db.
func NewValidator(db *database.DB) *Validator {
	return &Validator{DB: db}
}

// ValidateTableInput checks a CustomTableInput for a new table.
// Returns the first offending issue; nil means the input is acceptable.
func (v *Validator) ValidateTableInput(in CustomTableInput) error {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return fmt.Errorf("name is required")
	}
	if !tableNameRegex.MatchString(name) {
		return fmt.Errorf("name must match %s (lowercase letter, then letters/digits/underscores, 2-59 chars)", tableNameRegex.String())
	}
	if strings.TrimSpace(in.DisplayName) == "" {
		return fmt.Errorf("display_name is required")
	}

	physical := TablePrefix + name
	exists, err := tableExists(v.DB, physical)
	if err != nil {
		return fmt.Errorf("check collision: %w", err)
	}
	if exists {
		return fmt.Errorf("table %q already exists", physical)
	}

	// Also reject if the raw name collides with any existing table —
	// covers cases like a user trying to name a custom table
	// `incidents` without the prefix in metadata.
	exists, err = tableExists(v.DB, name)
	if err != nil {
		return fmt.Errorf("check collision: %w", err)
	}
	if exists {
		return fmt.Errorf("name %q collides with an existing pre-built table", name)
	}

	return nil
}

// ValidateFieldInput checks a CustomFieldInput being added to the
// table with id tableID. Returns the first offending issue.
func (v *Validator) ValidateFieldInput(tableID int64, in CustomFieldInput) error {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return fmt.Errorf("name is required")
	}
	if !fieldNameRegex.MatchString(name) {
		return fmt.Errorf("name must match %s (lowercase letter, then letters/digits/underscores, 2-63 chars)", fieldNameRegex.String())
	}
	if _, reserved := ReservedFieldNames[name]; reserved {
		return fmt.Errorf("%q is reserved (auto-added on every custom table)", name)
	}
	if strings.TrimSpace(in.DisplayName) == "" {
		return fmt.Errorf("display_name is required")
	}
	if !in.FieldType.Valid() {
		return fmt.Errorf("invalid field_type %q", in.FieldType)
	}

	// Collision with another field on the same table (active or not —
	// we never drop columns, so reusing a name would alias).
	var exists int64
	row, err := v.DB.QueryVal(
		`SELECT 1 FROM _custom_fields WHERE custom_table_id = ? AND name = ?`,
		tableID, name,
	)
	if err != nil {
		return fmt.Errorf("check field collision: %w", err)
	}
	if row != nil {
		exists, _ = row.(int64)
	}
	if exists == 1 {
		return fmt.Errorf("field %q already exists on this table", name)
	}

	return nil
}

// ValidateRelationInput checks a CustomRelationInput. The source field
// must exist, be active, and have field_type = relation. The target
// must be either a whitelisted pre-built table or an existing cx_*
// table. display_field must be a real column on the target.
func (v *Validator) ValidateRelationInput(in CustomRelationInput) error {
	if in.SourceFieldID == 0 {
		return fmt.Errorf("source_field_id is required")
	}
	if strings.TrimSpace(in.TargetTableName) == "" {
		return fmt.Errorf("target_table_name is required")
	}
	if strings.TrimSpace(in.DisplayField) == "" {
		return fmt.Errorf("display_field is required")
	}
	if in.RelationType == "" {
		in.RelationType = RelationBelongsTo
	}
	if in.RelationType != RelationBelongsTo &&
		in.RelationType != RelationHasMany &&
		in.RelationType != RelationManyToMany {
		return fmt.Errorf("invalid relation_type %q", in.RelationType)
	}
	// MVP: only belongs_to is actually wired end-to-end.
	if in.RelationType != RelationBelongsTo {
		return fmt.Errorf("relation_type %q is reserved — only belongs_to is supported in MVP", in.RelationType)
	}

	// Source field must exist, be active, and be of type relation.
	fieldRow, err := v.DB.QueryRow(
		`SELECT field_type, is_active FROM _custom_fields WHERE id = ?`,
		in.SourceFieldID,
	)
	if err != nil {
		return fmt.Errorf("load source field: %w", err)
	}
	if fieldRow == nil {
		return fmt.Errorf("source field %d not found", in.SourceFieldID)
	}
	if ft, _ := fieldRow["field_type"].(string); ft != string(FieldRelation) {
		return fmt.Errorf("source field must be of type %q, got %q", FieldRelation, ft)
	}
	if active, _ := fieldRow["is_active"].(int64); active != 1 {
		return fmt.Errorf("source field is inactive")
	}

	// Target must be whitelisted pre-built OR an existing cx_* table.
	target := in.TargetTableName
	isCx := strings.HasPrefix(target, TablePrefix)
	if !isCx && !IsAllowedRelationTarget(target) {
		return fmt.Errorf("target %q is not a permitted relation target", target)
	}
	exists, err := tableExists(v.DB, target)
	if err != nil {
		return fmt.Errorf("check target existence: %w", err)
	}
	if !exists {
		return fmt.Errorf("target table %q does not exist", target)
	}

	// display_field must be a real column on the target.
	hasCol, err := columnExists(v.DB, target, in.DisplayField)
	if err != nil {
		return fmt.Errorf("inspect target columns: %w", err)
	}
	if !hasCol {
		return fmt.Errorf("target %q has no column %q", target, in.DisplayField)
	}

	return nil
}

// tableExists reports whether a table (or view) of the given name
// exists in the connected SQLite database.
func tableExists(db *database.DB, name string) (bool, error) {
	row, err := db.QueryVal(
		`SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name = ?`,
		name,
	)
	if err != nil {
		return false, err
	}
	return row != nil, nil
}

// columnExists reports whether the given table has a column of the
// given name. Uses PRAGMA table_info — the result set has one row per
// column with name at index 1.
func columnExists(db *database.DB, table, column string) (bool, error) {
	// table_info doesn't accept bind parameters for the table name;
	// it's safe here because we already verified the table exists via
	// a parameterized sqlite_master lookup, so `table` is a known
	// identifier from the DB, not arbitrary user input.
	quoted := strings.ReplaceAll(table, `"`, `""`)
	rows, err := db.QueryRows(fmt.Sprintf(`PRAGMA table_info("%s")`, quoted))
	if err != nil {
		return false, err
	}
	for _, r := range rows {
		if name, _ := r["name"].(string); name == column {
			return true, nil
		}
	}
	return false, nil
}
