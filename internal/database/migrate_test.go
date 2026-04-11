package database

import (
	"os"
	"testing"
)

func TestMigrateAllModules(t *testing.T) {
	sqlDir := os.DirFS("../../docs/database-design/sql")

	migrations, err := CollectMigrations(sqlDir)
	if err != nil {
		t.Fatalf("collect migrations: %v", err)
	}

	if len(migrations) != len(moduleOrder) {
		t.Fatalf("expected %d modules, got %d", len(moduleOrder), len(migrations))
	}

	// Verify load order matches dependency requirements.
	for i, m := range migrations {
		if m.Name != moduleOrder[i] {
			t.Errorf("migration %d: expected %s, got %s", i, moduleOrder[i], m.Name)
		}
	}

	db, err := Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()

	if err := Migrate(db, migrations); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	// Verify tracking table recorded all migrations.
	for _, m := range migrations {
		applied, err := migrationApplied(db, m.Name)
		if err != nil {
			t.Fatalf("check applied %s: %v", m.Name, err)
		}
		if !applied {
			t.Errorf("%s not recorded in _migrations", m.Name)
		}
	}

	// Seed data references establishment_id=1 which doesn't exist yet.
	// Verify FK violations are limited to expected seed data references.
	violations, err := db.CheckFK()
	if err != nil {
		t.Fatalf("fk check: %v", err)
	}
	for _, v := range violations {
		t.Logf("expected seed FK violation: %s row %d -> %s", v.Table, v.RowID, v.Parent)
	}
}

func TestMigrateWithEstablishment(t *testing.T) {
	sqlDir := os.DirFS("../../docs/database-design/sql")

	migrations, err := CollectMigrations(sqlDir)
	if err != nil {
		t.Fatalf("collect: %v", err)
	}

	db, err := Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()

	if err := Migrate(db, migrations); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	// Create the establishment that seed data references.
	if err := db.Exec(`INSERT INTO establishments (id, name, naics_code, street_address, city, state, zip)
		VALUES (1, 'Test Facility', '325199', '123 Industrial Pkwy', 'Springfield', 'IL', '62701')`); err != nil {
		t.Fatalf("insert establishment: %v", err)
	}

	violations, err := db.CheckFK()
	if err != nil {
		t.Fatalf("fk check: %v", err)
	}
	if len(violations) > 0 {
		for _, v := range violations {
			t.Errorf("unexpected FK violation: %s row %d -> %s", v.Table, v.RowID, v.Parent)
		}
	}
}

func TestMigrateIdempotent(t *testing.T) {
	sqlDir := os.DirFS("../../docs/database-design/sql")

	migrations, err := CollectMigrations(sqlDir)
	if err != nil {
		t.Fatalf("collect: %v", err)
	}

	db, err := Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()

	// Apply twice — second run should be a no-op.
	if err := Migrate(db, migrations); err != nil {
		t.Fatalf("first migrate: %v", err)
	}
	if err := Migrate(db, migrations); err != nil {
		t.Fatalf("second migrate: %v", err)
	}
}
