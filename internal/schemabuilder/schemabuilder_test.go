package schemabuilder

import (
	"encoding/json"
	"os"
	"strings"
	"testing"

	"github.com/asgardehs/odin/internal/database"
)

// ============================================================
// Test setup
// ============================================================

// newTestDB opens an in-memory SQLite, applies the schema-builder
// migration, and creates minimal stubs for the relation-target
// pre-built tables used in tests. Closes on test cleanup.
func newTestDB(t *testing.T) *database.DB {
	t.Helper()
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	for _, file := range []string{
		"../../embed/migrations/002_schemabuilder.sql",
		"../../embed/migrations/004_parent_module.sql",
	} {
		sql, err := os.ReadFile(file)
		if err != nil {
			t.Fatalf("read migration %s: %v", file, err)
		}
		if err := db.Exec(string(sql)); err != nil {
			t.Fatalf("apply migration %s: %v", file, err)
		}
	}

	// Minimal pre-built stubs so relation target validation has real
	// tables to verify against. Columns match the fields the tests
	// use as display_field.
	stubs := []string{
		`CREATE TABLE employees (
			id INTEGER PRIMARY KEY,
			first_name TEXT,
			last_name TEXT
		)`,
		`CREATE TABLE establishments (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL
		)`,
	}
	for _, s := range stubs {
		if err := db.Exec(s); err != nil {
			t.Fatalf("stub: %v", err)
		}
	}
	return db
}

// mustCreateTable creates a custom table and returns its id, or
// fails the test.
func mustCreateTable(t *testing.T, ex *Executor, name, display string) int64 {
	t.Helper()
	id, err := ex.CreateTable("test-admin", CustomTableInput{
		Name:        name,
		DisplayName: display,
	})
	if err != nil {
		t.Fatalf("create table %q: %v", name, err)
	}
	return id
}

// mustAddField adds a field and returns its id.
func mustAddField(t *testing.T, ex *Executor, tableID int64, in CustomFieldInput) int64 {
	t.Helper()
	id, err := ex.AddField("test-admin", tableID, in)
	if err != nil {
		t.Fatalf("add field %q: %v", in.Name, err)
	}
	return id
}

// ============================================================
// Validator — table input
// ============================================================

func TestValidator_TableInput(t *testing.T) {
	db := newTestDB(t)
	v := NewValidator(db)

	cases := []struct {
		name    string
		in      CustomTableInput
		wantErr string // substring of expected error; empty = want ok
	}{
		{"happy path", CustomTableInput{Name: "projects", DisplayName: "Projects"}, ""},
		{"missing name", CustomTableInput{Name: "", DisplayName: "X"}, "name is required"},
		{"missing display", CustomTableInput{Name: "projects", DisplayName: ""}, "display_name is required"},
		{"regex uppercase", CustomTableInput{Name: "Projects", DisplayName: "X"}, "must match"},
		{"regex starts digit", CustomTableInput{Name: "1projects", DisplayName: "X"}, "must match"},
		{"regex has dash", CustomTableInput{Name: "my-projects", DisplayName: "X"}, "must match"},
		{"regex too short", CustomTableInput{Name: "a", DisplayName: "X"}, "must match"},
		{"collides with pre-built (employees)", CustomTableInput{Name: "employees", DisplayName: "X"}, "collides"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := v.ValidateTableInput(tc.in)
			if tc.wantErr == "" && err != nil {
				t.Fatalf("want ok, got %v", err)
			}
			if tc.wantErr != "" && (err == nil || !strings.Contains(err.Error(), tc.wantErr)) {
				t.Fatalf("want error containing %q, got %v", tc.wantErr, err)
			}
		})
	}
}

func TestValidator_TableCollisionWithExistingCustom(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	v := NewValidator(db)

	mustCreateTable(t, ex, "projects", "Projects")

	err := v.ValidateTableInput(CustomTableInput{Name: "projects", DisplayName: "Dup"})
	if err == nil || !strings.Contains(err.Error(), "already exists") {
		t.Fatalf("expected collision error, got %v", err)
	}
}

// ============================================================
// Validator — field input
// ============================================================

func TestValidator_FieldInput(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	v := NewValidator(db)
	tid := mustCreateTable(t, ex, "projects", "Projects")

	cases := []struct {
		name    string
		in      CustomFieldInput
		wantErr string
	}{
		{"happy text", CustomFieldInput{Name: "title", DisplayName: "Title", FieldType: FieldText}, ""},
		{"missing name", CustomFieldInput{DisplayName: "X", FieldType: FieldText}, "name is required"},
		{"missing display", CustomFieldInput{Name: "title", FieldType: FieldText}, "display_name is required"},
		{"reserved id", CustomFieldInput{Name: "id", DisplayName: "X", FieldType: FieldText}, "reserved"},
		{"reserved establishment_id", CustomFieldInput{Name: "establishment_id", DisplayName: "X", FieldType: FieldText}, "reserved"},
		{"reserved created_at", CustomFieldInput{Name: "created_at", DisplayName: "X", FieldType: FieldText}, "reserved"},
		{"reserved updated_at", CustomFieldInput{Name: "updated_at", DisplayName: "X", FieldType: FieldText}, "reserved"},
		{"bad field type", CustomFieldInput{Name: "xyz", DisplayName: "X", FieldType: "blob"}, "invalid field_type"},
		{"regex uppercase", CustomFieldInput{Name: "Title", DisplayName: "X", FieldType: FieldText}, "must match"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := v.ValidateFieldInput(tid, tc.in)
			if tc.wantErr == "" && err != nil {
				t.Fatalf("want ok, got %v", err)
			}
			if tc.wantErr != "" && (err == nil || !strings.Contains(err.Error(), tc.wantErr)) {
				t.Fatalf("want error containing %q, got %v", tc.wantErr, err)
			}
		})
	}
}

func TestValidator_FieldAllTypesAccepted(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	v := NewValidator(db)
	tid := mustCreateTable(t, ex, "projects", "Projects")

	types := []FieldType{
		FieldText, FieldNumber, FieldDecimal, FieldDate,
		FieldDatetime, FieldBoolean, FieldSelect, FieldRelation,
	}
	for _, ft := range types {
		err := v.ValidateFieldInput(tid, CustomFieldInput{
			Name:        "f_" + string(ft),
			DisplayName: "F " + string(ft),
			FieldType:   ft,
		})
		if err != nil {
			t.Errorf("type %q rejected: %v", ft, err)
		}
	}
}

func TestValidator_FieldDuplicateOnSameTable(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	v := NewValidator(db)
	tid := mustCreateTable(t, ex, "projects", "Projects")
	mustAddField(t, ex, tid, CustomFieldInput{Name: "title", DisplayName: "Title", FieldType: FieldText})

	err := v.ValidateFieldInput(tid, CustomFieldInput{
		Name: "title", DisplayName: "Title Two", FieldType: FieldText,
	})
	if err == nil || !strings.Contains(err.Error(), "already exists") {
		t.Fatalf("expected duplicate error, got %v", err)
	}
}

// ============================================================
// Validator — relation input
// ============================================================

func TestValidator_RelationInput(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	v := NewValidator(db)
	tid := mustCreateTable(t, ex, "projects", "Projects")

	// A relation-typed field is the pre-requisite.
	relFieldID := mustAddField(t, ex, tid, CustomFieldInput{
		Name: "owner", DisplayName: "Owner", FieldType: FieldRelation,
	})
	textFieldID := mustAddField(t, ex, tid, CustomFieldInput{
		Name: "title", DisplayName: "Title", FieldType: FieldText,
	})

	t.Run("happy path employees", func(t *testing.T) {
		err := v.ValidateRelationInput(CustomRelationInput{
			SourceFieldID:   relFieldID,
			TargetTableName: "employees",
			DisplayField:    "last_name",
			RelationType:    RelationBelongsTo,
		})
		if err != nil {
			t.Fatalf("want ok, got %v", err)
		}
	})

	t.Run("target not in allowlist", func(t *testing.T) {
		err := v.ValidateRelationInput(CustomRelationInput{
			SourceFieldID:   relFieldID,
			TargetTableName: "app_users",
			DisplayField:    "username",
			RelationType:    RelationBelongsTo,
		})
		if err == nil || !strings.Contains(err.Error(), "not a permitted relation target") {
			t.Fatalf("want target error, got %v", err)
		}
	})

	t.Run("target does not exist", func(t *testing.T) {
		err := v.ValidateRelationInput(CustomRelationInput{
			SourceFieldID:   relFieldID,
			TargetTableName: "incidents", // whitelisted but not created in test DB
			DisplayField:    "case_number",
			RelationType:    RelationBelongsTo,
		})
		if err == nil || !strings.Contains(err.Error(), "does not exist") {
			t.Fatalf("want existence error, got %v", err)
		}
	})

	t.Run("display_field not on target", func(t *testing.T) {
		err := v.ValidateRelationInput(CustomRelationInput{
			SourceFieldID:   relFieldID,
			TargetTableName: "employees",
			DisplayField:    "does_not_exist",
			RelationType:    RelationBelongsTo,
		})
		if err == nil || !strings.Contains(err.Error(), "has no column") {
			t.Fatalf("want column error, got %v", err)
		}
	})

	t.Run("source field is not relation-typed", func(t *testing.T) {
		err := v.ValidateRelationInput(CustomRelationInput{
			SourceFieldID:   textFieldID,
			TargetTableName: "employees",
			DisplayField:    "last_name",
			RelationType:    RelationBelongsTo,
		})
		if err == nil || !strings.Contains(err.Error(), "must be of type") {
			t.Fatalf("want type error, got %v", err)
		}
	})

	t.Run("has_many reserved in MVP", func(t *testing.T) {
		err := v.ValidateRelationInput(CustomRelationInput{
			SourceFieldID:   relFieldID,
			TargetTableName: "employees",
			DisplayField:    "last_name",
			RelationType:    RelationHasMany,
		})
		if err == nil || !strings.Contains(err.Error(), "reserved") {
			t.Fatalf("want reserved error, got %v", err)
		}
	})
}

// ============================================================
// Executor — DDL side effects
// ============================================================

func TestExecutor_CreateTableRunsDDL(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)

	id := mustCreateTable(t, ex, "projects", "Projects")
	if id <= 0 {
		t.Fatalf("expected positive id, got %d", id)
	}

	// Physical table created.
	row, err := db.QueryVal(
		`SELECT name FROM sqlite_master WHERE type='table' AND name=?`,
		"cx_projects",
	)
	if err != nil || row == nil {
		t.Fatalf("cx_projects not created in sqlite: %v (%v)", row, err)
	}

	// Auto columns present.
	cols, err := db.QueryRows(`PRAGMA table_info("cx_projects")`)
	if err != nil {
		t.Fatalf("pragma: %v", err)
	}
	want := map[string]bool{"id": false, "establishment_id": false, "created_at": false, "updated_at": false}
	for _, c := range cols {
		if n, _ := c["name"].(string); n != "" {
			if _, ok := want[n]; ok {
				want[n] = true
			}
		}
	}
	for n, seen := range want {
		if !seen {
			t.Errorf("missing auto-column %q on cx_projects", n)
		}
	}

	// Version row written.
	versions, err := ex.ListVersions(id)
	if err != nil {
		t.Fatalf("list versions: %v", err)
	}
	if len(versions) != 1 || versions[0].ChangeType != "create_table" {
		t.Fatalf("want 1 create_table version, got %+v", versions)
	}
}

func TestExecutor_AddFieldRunsAlter(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	tid := mustCreateTable(t, ex, "projects", "Projects")

	_ = mustAddField(t, ex, tid, CustomFieldInput{
		Name: "title", DisplayName: "Title", FieldType: FieldText, IsRequired: true,
	})
	_ = mustAddField(t, ex, tid, CustomFieldInput{
		Name: "priority", DisplayName: "Priority", FieldType: FieldNumber,
	})

	cols, err := db.QueryRows(`PRAGMA table_info("cx_projects")`)
	if err != nil {
		t.Fatalf("pragma: %v", err)
	}
	found := map[string]string{}
	for _, c := range cols {
		name, _ := c["name"].(string)
		typ, _ := c["type"].(string)
		found[name] = typ
	}
	if found["title"] == "" {
		t.Errorf("title column not added")
	}
	if found["priority"] != "INTEGER" {
		t.Errorf("priority wrong type: %q (want INTEGER)", found["priority"])
	}

	// Version rows: create + 2 add_field = 3.
	versions, _ := ex.ListVersions(tid)
	if len(versions) != 3 {
		t.Fatalf("want 3 version rows, got %d", len(versions))
	}
}

func TestExecutor_DeactivateFieldIsMetadataOnly(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	tid := mustCreateTable(t, ex, "projects", "Projects")
	fid := mustAddField(t, ex, tid, CustomFieldInput{
		Name: "notes", DisplayName: "Notes", FieldType: FieldText,
	})

	if err := ex.DeactivateField("test-admin", fid); err != nil {
		t.Fatalf("deactivate: %v", err)
	}

	// Metadata flipped.
	row, _ := db.QueryRow(`SELECT is_active FROM _custom_fields WHERE id = ?`, fid)
	if row == nil {
		t.Fatalf("field not found after deactivate")
	}
	if v, _ := row["is_active"].(int64); v != 0 {
		t.Errorf("is_active expected 0, got %d", v)
	}

	// SQLite column still there.
	cols, _ := db.QueryRows(`PRAGMA table_info("cx_projects")`)
	seen := false
	for _, c := range cols {
		if n, _ := c["name"].(string); n == "notes" {
			seen = true
		}
	}
	if !seen {
		t.Errorf("sqlite column 'notes' missing — deactivation should be metadata-only")
	}
}

func TestExecutor_DeactivateThenReactivateTable(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	tid := mustCreateTable(t, ex, "projects", "Projects")

	if err := ex.DeactivateTable("a", tid); err != nil {
		t.Fatalf("deactivate: %v", err)
	}
	tbl, _ := ex.LoadTable(tid)
	if tbl == nil || tbl.IsActive {
		t.Fatalf("table should be inactive")
	}

	if err := ex.ReactivateTable("a", tid); err != nil {
		t.Fatalf("reactivate: %v", err)
	}
	tbl, _ = ex.LoadTable(tid)
	if tbl == nil || !tbl.IsActive {
		t.Fatalf("table should be active again")
	}

	// Version log has all three changes.
	versions, _ := ex.ListVersions(tid)
	types := make([]string, 0, len(versions))
	for _, v := range versions {
		types = append(types, v.ChangeType)
	}
	want := map[string]bool{"create_table": false, "deactivate_table": false, "reactivate_table": false}
	for _, tp := range types {
		if _, ok := want[tp]; ok {
			want[tp] = true
		}
	}
	for k, v := range want {
		if !v {
			t.Errorf("missing version row %q (got %v)", k, types)
		}
	}
}

func TestExecutor_AddRelation(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	tid := mustCreateTable(t, ex, "projects", "Projects")
	fid := mustAddField(t, ex, tid, CustomFieldInput{
		Name: "owner", DisplayName: "Owner", FieldType: FieldRelation,
	})

	rid, err := ex.AddRelation("a", tid, CustomRelationInput{
		SourceFieldID:   fid,
		TargetTableName: "employees",
		DisplayField:    "last_name",
		RelationType:    RelationBelongsTo,
	})
	if err != nil {
		t.Fatalf("add relation: %v", err)
	}
	if rid <= 0 {
		t.Fatalf("bad rid %d", rid)
	}

	tbl, _ := ex.LoadTable(tid)
	if len(tbl.Relations) != 1 || tbl.Relations[0].TargetTableName != "employees" {
		t.Fatalf("relation not loaded: %+v", tbl.Relations)
	}
}

// ============================================================
// Query builder
// ============================================================

func TestQueryBuilder_SelectAndInsert(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	qb := NewQueryBuilder(ex)

	tid := mustCreateTable(t, ex, "projects", "Projects")
	mustAddField(t, ex, tid, CustomFieldInput{
		Name: "title", DisplayName: "Title", FieldType: FieldText, IsRequired: true,
	})
	mustAddField(t, ex, tid, CustomFieldInput{
		Name: "priority", DisplayName: "Priority", FieldType: FieldNumber,
	})

	// Select: no opts.
	sql, args, err := qb.Select(tid, SelectOpts{})
	if err != nil {
		t.Fatalf("select: %v", err)
	}
	if !strings.Contains(sql, `"cx_projects"`) || !strings.Contains(sql, `"title"`) || !strings.Contains(sql, `"priority"`) {
		t.Errorf("select missing quoted identifiers: %s", sql)
	}
	if !strings.Contains(sql, "LIMIT ? OFFSET ?") {
		t.Errorf("select missing pagination: %s", sql)
	}
	if len(args) != 2 {
		t.Errorf("select default args want len 2, got %v", args)
	}

	// Insert happy path.
	sql, args, err = qb.Insert(tid, map[string]any{
		"title":            "Build schema builder",
		"priority":         int64(3),
		"establishment_id": int64(1),
		// An unknown key — should be filtered.
		"evil_drop":        "DROP TABLE employees",
	})
	if err != nil {
		t.Fatalf("insert: %v", err)
	}
	if strings.Contains(sql, "evil_drop") {
		t.Errorf("unknown key leaked into SQL: %s", sql)
	}
	if !strings.Contains(sql, `"title"`) || !strings.Contains(sql, `"priority"`) {
		t.Errorf("insert missing known columns: %s", sql)
	}
	if len(args) != 3 {
		t.Errorf("insert args want 3 (filtered unknown), got %d", len(args))
	}
}

func TestQueryBuilder_InsertMissingRequired(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	qb := NewQueryBuilder(ex)
	tid := mustCreateTable(t, ex, "projects", "Projects")
	mustAddField(t, ex, tid, CustomFieldInput{
		Name: "title", DisplayName: "Title", FieldType: FieldText, IsRequired: true,
	})

	_, _, err := qb.Insert(tid, map[string]any{"establishment_id": int64(1)})
	if err == nil || !strings.Contains(err.Error(), "required field") {
		t.Fatalf("want required-field error, got %v", err)
	}
}

func TestQueryBuilder_SelectJoinsRelation(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	qb := NewQueryBuilder(ex)

	tid := mustCreateTable(t, ex, "projects", "Projects")
	fid := mustAddField(t, ex, tid, CustomFieldInput{
		Name: "owner", DisplayName: "Owner", FieldType: FieldRelation,
	})
	if _, err := ex.AddRelation("a", tid, CustomRelationInput{
		SourceFieldID:   fid,
		TargetTableName: "employees",
		DisplayField:    "last_name",
		RelationType:    RelationBelongsTo,
	}); err != nil {
		t.Fatalf("add relation: %v", err)
	}

	sql, _, err := qb.Select(tid, SelectOpts{JoinRelations: true})
	if err != nil {
		t.Fatalf("select: %v", err)
	}
	if !strings.Contains(sql, `LEFT JOIN "employees"`) {
		t.Errorf("missing LEFT JOIN on employees: %s", sql)
	}
	if !strings.Contains(sql, `"owner__label"`) {
		t.Errorf("missing relation label alias: %s", sql)
	}
}

func TestQueryBuilder_RejectsInactiveTable(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	qb := NewQueryBuilder(ex)
	tid := mustCreateTable(t, ex, "projects", "Projects")
	if err := ex.DeactivateTable("a", tid); err != nil {
		t.Fatalf("deactivate: %v", err)
	}

	if _, _, err := qb.Select(tid, SelectOpts{}); err == nil {
		t.Errorf("select on inactive table should fail")
	}
	if _, _, err := qb.Insert(tid, map[string]any{"establishment_id": int64(1)}); err == nil {
		t.Errorf("insert on inactive table should fail")
	}
}

func TestQueryBuilder_SearchCoversTextFields(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	qb := NewQueryBuilder(ex)
	tid := mustCreateTable(t, ex, "projects", "Projects")
	mustAddField(t, ex, tid, CustomFieldInput{Name: "title", DisplayName: "Title", FieldType: FieldText})
	mustAddField(t, ex, tid, CustomFieldInput{Name: "priority", DisplayName: "P", FieldType: FieldNumber})

	sql, args, err := qb.Select(tid, SelectOpts{Search: "schema"})
	if err != nil {
		t.Fatalf("select: %v", err)
	}
	if !strings.Contains(sql, `"title" LIKE ?`) {
		t.Errorf("search did not cover text field title: %s", sql)
	}
	if strings.Contains(sql, `"priority" LIKE`) {
		t.Errorf("search incorrectly covered number field priority: %s", sql)
	}
	// args: search pattern, limit, offset
	if len(args) != 3 {
		t.Errorf("args want len 3, got %d: %v", len(args), args)
	}
	if s, _ := args[0].(string); s != "%schema%" {
		t.Errorf("bad search pattern: %v", args[0])
	}
}

// ============================================================
// Integration — end-to-end via QueryBuilder + real DB writes
// ============================================================

func TestIntegration_CreateAddInsertSelectUpdateDelete(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	qb := NewQueryBuilder(ex)

	tid := mustCreateTable(t, ex, "projects", "Projects")
	mustAddField(t, ex, tid, CustomFieldInput{
		Name: "title", DisplayName: "Title", FieldType: FieldText, IsRequired: true,
	})
	mustAddField(t, ex, tid, CustomFieldInput{
		Name: "priority", DisplayName: "Priority", FieldType: FieldNumber,
	})

	// Insert.
	sql, args, err := qb.Insert(tid, map[string]any{
		"title":            "Build phase 0",
		"priority":         int64(1),
		"establishment_id": int64(7),
	})
	if err != nil {
		t.Fatalf("build insert: %v", err)
	}
	if err := db.ExecParams(sql, args...); err != nil {
		t.Fatalf("exec insert: %v", err)
	}
	insertedID, err := db.QueryVal("SELECT last_insert_rowid()")
	if err != nil {
		t.Fatalf("last_insert_rowid: %v", err)
	}
	rowID := insertedID.(int64)

	// Select by id.
	sql, args, err = qb.SelectByID(tid, rowID)
	if err != nil {
		t.Fatalf("build select by id: %v", err)
	}
	row, err := db.QueryRow(sql, args...)
	if err != nil {
		t.Fatalf("exec select by id: %v", err)
	}
	if row == nil {
		t.Fatalf("row not found")
	}
	if title, _ := row["title"].(string); title != "Build phase 0" {
		t.Errorf("title mismatch: %q", title)
	}

	// Update.
	sql, args, err = qb.Update(tid, rowID, map[string]any{
		"title":    "Build phase 0 — in progress",
		"priority": int64(2),
	})
	if err != nil {
		t.Fatalf("build update: %v", err)
	}
	if err := db.ExecParams(sql, args...); err != nil {
		t.Fatalf("exec update: %v", err)
	}

	row, _ = db.QueryRow(`SELECT title, priority FROM "cx_projects" WHERE id = ?`, rowID)
	if row == nil {
		t.Fatalf("row missing after update")
	}
	if row["title"].(string) != "Build phase 0 — in progress" || row["priority"].(int64) != 2 {
		t.Errorf("update didn't stick: %+v", row)
	}

	// Delete.
	sql, args, err = qb.Delete(tid, rowID)
	if err != nil {
		t.Fatalf("build delete: %v", err)
	}
	if err := db.ExecParams(sql, args...); err != nil {
		t.Fatalf("exec delete: %v", err)
	}
	row, _ = db.QueryRow(`SELECT id FROM "cx_projects" WHERE id = ?`, rowID)
	if row != nil {
		t.Fatalf("row still present after delete")
	}
}

// ============================================================
// Sanity — version payload is readable JSON
// ============================================================

func TestVersionPayloadIsJSON(t *testing.T) {
	db := newTestDB(t)
	ex := NewExecutor(db)
	tid := mustCreateTable(t, ex, "projects", "Projects")
	mustAddField(t, ex, tid, CustomFieldInput{
		Name: "title", DisplayName: "Title", FieldType: FieldText,
	})
	versions, err := ex.ListVersions(tid)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	for _, v := range versions {
		var decoded map[string]any
		if err := json.Unmarshal(v.ChangePayload, &decoded); err != nil {
			t.Errorf("version %d payload is not JSON: %v", v.ID, err)
		}
	}
}
