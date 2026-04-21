// Package schemabuilder implements Odin's runtime schema builder: the
// metadata-backed system that lets admins design tables, fields, and
// relationships at runtime without a code deploy.
//
// Principles (see docs/plans/2026-04-19-schema-builder.md):
//
//   - Custom tables live beside pre-built modules. Every user-defined
//     table is created with the `cx_` prefix; pre-built schemas are never
//     altered at runtime.
//   - DDL is additive only. No DROP or RENAME — deactivation is a
//     metadata flip (`is_active = 0`) and the SQLite table/column stays
//     intact so the audit trail remains coherent.
//   - Metadata-driven. The UI renders from _custom_tables /
//     _custom_fields / _custom_relations, not per-table pages.
package schemabuilder

import (
	"encoding/json"
	"slices"
)

// TablePrefix is prepended to the metadata name to form the real
// SQLite table name. A metadata row `name = "projects"` lives in
// SQLite as `cx_projects`.
const TablePrefix = "cx_"

// FieldType enumerates the eight value types a custom field can hold.
// The wire form (JSON) uses the lowercase string values.
type FieldType string

const (
	FieldText     FieldType = "text"
	FieldNumber   FieldType = "number"
	FieldDecimal  FieldType = "decimal"
	FieldDate     FieldType = "date"
	FieldDatetime FieldType = "datetime"
	FieldBoolean  FieldType = "boolean"
	FieldSelect   FieldType = "select"
	FieldRelation FieldType = "relation"
)

// SQLiteType returns the SQLite column type used to back a field type.
// This mapping is authoritative and mirrored in the public
// schema-builder documentation.
func (t FieldType) SQLiteType() string {
	switch t {
	case FieldNumber, FieldBoolean, FieldRelation:
		return "INTEGER"
	case FieldDecimal:
		return "REAL"
	case FieldText, FieldDate, FieldDatetime, FieldSelect:
		return "TEXT"
	}
	return ""
}

// Valid reports whether t is one of the known field types.
func (t FieldType) Valid() bool {
	return t.SQLiteType() != ""
}

// RelationType enumerates the supported relation kinds. MVP supports
// `belongs_to` only — the others are reserved in the schema so future
// migrations don't need a CHECK change.
type RelationType string

const (
	RelationBelongsTo   RelationType = "belongs_to"
	RelationHasMany     RelationType = "has_many"
	RelationManyToMany  RelationType = "many_to_many"
)

// ReservedFieldNames are auto-added to every cx_ table and cannot be
// redefined by a user. Case-insensitive comparison is done elsewhere.
var ReservedFieldNames = map[string]struct{}{
	"id":               {},
	"establishment_id": {},
	"created_at":       {},
	"updated_at":       {},
}

// RelationTargetAllowlist lists the pre-built tables that a custom
// relation field is allowed to target. Any `cx_*` table is also a
// valid target (handled separately in the validator).
//
// Order is the canonical presentation order in admin UIs.
var RelationTargetAllowlist = []string{
	"establishments",
	"employees",
	"incidents",
	"chemicals",
	"training_courses",
	"training_completions",
	"storage_locations",
	"work_areas",
}

// IsAllowedRelationTarget reports whether target is one of the
// whitelisted pre-built tables. (cx_* targets are checked separately.)
func IsAllowedRelationTarget(target string) bool {
	return slices.Contains(RelationTargetAllowlist, target)
}

// CustomTableInput is the payload for creating a new custom table.
type CustomTableInput struct {
	Name        string  `json:"name"`
	DisplayName string  `json:"display_name"`
	Description *string `json:"description,omitempty"`
	Icon        *string `json:"icon,omitempty"`
}

// CustomFieldInput is the payload for adding a field to a custom table.
type CustomFieldInput struct {
	Name         string          `json:"name"`
	DisplayName  string          `json:"display_name"`
	FieldType    FieldType       `json:"field_type"`
	IsRequired   bool            `json:"is_required,omitempty"`
	DefaultValue *string         `json:"default_value,omitempty"`
	Config       json.RawMessage `json:"config,omitempty"`
	DisplayOrder int             `json:"display_order,omitempty"`
}

// CustomRelationInput is the payload for adding a relation. The
// source_field_id must reference an already-created field of type
// `relation`.
type CustomRelationInput struct {
	SourceFieldID   int64        `json:"source_field_id"`
	TargetTableName string       `json:"target_table_name"`
	DisplayField    string       `json:"display_field"`
	RelationType    RelationType `json:"relation_type"`
}

// CustomTable is the persisted shape returned by the repository.
//
// Fields and Relations are always serialized as a JSON array (never
// omitted or null) so the frontend can rely on .filter/.map without
// null guards.
type CustomTable struct {
	ID           int64            `json:"id"`
	Name         string           `json:"name"`         // without prefix
	DisplayName  string           `json:"display_name"`
	Description  *string          `json:"description,omitempty"`
	Icon         *string          `json:"icon,omitempty"`
	DisplayOrder int              `json:"display_order"`
	IsActive     bool             `json:"is_active"`
	CreatedAt    string           `json:"created_at"`
	UpdatedAt    string           `json:"updated_at"`
	Fields       []CustomField    `json:"fields"`
	Relations    []CustomRelation `json:"relations"`
}

// PhysicalName returns the real SQLite table name (prefix + metadata name).
func (t *CustomTable) PhysicalName() string {
	return TablePrefix + t.Name
}

// CustomField is a persisted field on a custom table.
type CustomField struct {
	ID            int64           `json:"id"`
	CustomTableID int64           `json:"custom_table_id"`
	Name          string          `json:"name"`
	DisplayName   string          `json:"display_name"`
	FieldType     FieldType       `json:"field_type"`
	IsRequired    bool            `json:"is_required"`
	DefaultValue  *string         `json:"default_value,omitempty"`
	Config        json.RawMessage `json:"config,omitempty"`
	DisplayOrder  int             `json:"display_order"`
	IsActive      bool            `json:"is_active"`
	CreatedAt     string          `json:"created_at"`
	UpdatedAt     string          `json:"updated_at"`
}

// CustomRelation is a persisted relation between two tables.
type CustomRelation struct {
	ID              int64        `json:"id"`
	SourceTableID   int64        `json:"source_table_id"`
	SourceFieldID   int64        `json:"source_field_id"`
	TargetTableName string       `json:"target_table_name"`
	DisplayField    string       `json:"display_field"`
	RelationType    RelationType `json:"relation_type"`
	IsActive        bool         `json:"is_active"`
	CreatedAt       string       `json:"created_at"`
	UpdatedAt       string       `json:"updated_at"`
}

// TableVersion is one row in _custom_table_versions: a timestamped
// record of a DDL change (create, add_field, deactivate_field, etc.).
type TableVersion struct {
	ID             int64           `json:"id"`
	CustomTableID  int64           `json:"custom_table_id"`
	ChangeType     string          `json:"change_type"`
	ChangePayload  json.RawMessage `json:"change_payload"`
	ChangedBy      string          `json:"changed_by"`
	ChangedAt      string          `json:"changed_at"`
}
