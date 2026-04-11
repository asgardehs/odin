package database

import (
	"fmt"
	"io/fs"
	"sort"
	"strings"
)

// Migration is a named SQL script to apply in order.
type Migration struct {
	Name string // filename, e.g. "module_c_osha300.sql"
	SQL  string
}

// moduleOrder defines the load order for EHS schema modules.
// Module C provides shared foundation tables (establishments, employees,
// corrective_actions, incidents). Training provides hazard_type_codes and
// work_areas. Everything else depends on one or both of those.
var moduleOrder = []string{
	"module_c_osha300.sql",
	"module_training.sql",
	"module_a_epcra_tri.sql",
	"module_b_title_v_caa.sql",
	"module_inspections_audits.sql",
	"module_permits_licenses.sql",
	"module_industrial_waste_streams.sql",
	"module_ppe.sql",
}

// orderIndex maps module filenames to their required load position.
func orderIndex() map[string]int {
	m := make(map[string]int, len(moduleOrder))
	for i, name := range moduleOrder {
		m[name] = i
	}
	return m
}

// CollectMigrations reads all module_*.sql files from sqlFS and returns
// them sorted in dependency order. Files not in the known order list are
// appended alphabetically at the end.
func CollectMigrations(sqlFS fs.FS) ([]Migration, error) {
	entries, err := fs.ReadDir(sqlFS, ".")
	if err != nil {
		return nil, fmt.Errorf("migrate: read dir: %w", err)
	}

	idx := orderIndex()
	var migrations []Migration

	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || !strings.HasPrefix(name, "module_") || !strings.HasSuffix(name, ".sql") {
			continue
		}
		data, err := fs.ReadFile(sqlFS, name)
		if err != nil {
			return nil, fmt.Errorf("migrate: read %s: %w", name, err)
		}
		migrations = append(migrations, Migration{Name: name, SQL: string(data)})
	}

	sort.Slice(migrations, func(i, j int) bool {
		oi, okI := idx[migrations[i].Name]
		oj, okJ := idx[migrations[j].Name]
		if okI && okJ {
			return oi < oj
		}
		if okI {
			return true // known modules before unknown
		}
		if okJ {
			return false
		}
		return migrations[i].Name < migrations[j].Name
	})

	return migrations, nil
}

// Migrate applies all pending migrations inside a transaction.
// It tracks applied migrations in a _migrations table so modules
// are not re-applied on subsequent runs.
func Migrate(db *DB, migrations []Migration) error {
	if err := db.Exec(`CREATE TABLE IF NOT EXISTS _migrations (
		name    TEXT PRIMARY KEY,
		applied TEXT NOT NULL DEFAULT (datetime('now'))
	)`); err != nil {
		return fmt.Errorf("migrate: create tracking table: %w", err)
	}

	// Defer FK enforcement during migration. Modules contain seed data
	// that may reference tables defined in earlier modules. We verify
	// FK integrity after all migrations complete.
	if err := db.Exec("PRAGMA foreign_keys=OFF"); err != nil {
		return fmt.Errorf("migrate: disable fk: %w", err)
	}
	defer db.Exec("PRAGMA foreign_keys=ON")

	for _, m := range migrations {
		applied, err := migrationApplied(db, m.Name)
		if err != nil {
			return err
		}
		if applied {
			continue
		}

		if err := db.Exec("SAVEPOINT migration"); err != nil {
			return fmt.Errorf("migrate: savepoint %s: %w", m.Name, err)
		}

		if err := db.Exec(m.SQL); err != nil {
			_ = db.Exec("ROLLBACK TO migration")
			return fmt.Errorf("migrate: apply %s: %w", m.Name, err)
		}

		stmt, _, err := db.conn.Prepare(`INSERT INTO _migrations (name) VALUES (?)`)
		if err != nil {
			_ = db.Exec("ROLLBACK TO migration")
			return fmt.Errorf("migrate: record %s: %w", m.Name, err)
		}
		stmt.BindText(1, m.Name)
		stmt.Step()
		if err := stmt.Close(); err != nil {
			_ = db.Exec("ROLLBACK TO migration")
			return fmt.Errorf("migrate: record %s: %w", m.Name, err)
		}

		if err := db.Exec("RELEASE migration"); err != nil {
			return fmt.Errorf("migrate: release %s: %w", m.Name, err)
		}
	}

	return nil
}

// migrationApplied checks if a migration has already been run.
func migrationApplied(db *DB, name string) (bool, error) {
	stmt, _, err := db.conn.Prepare(`SELECT 1 FROM _migrations WHERE name = ?`)
	if err != nil {
		return false, fmt.Errorf("migrate: check %s: %w", name, err)
	}
	defer stmt.Close()
	stmt.BindText(1, name)
	return stmt.Step(), nil
}

// CollectAppMigrations reads all *.sql files from sqlFS and returns
// them sorted alphabetically (numeric prefix ordering: 001_, 002_, etc.).
// This is used for application-level migrations that don't follow the
// EHS module naming convention.
func CollectAppMigrations(sqlFS fs.FS) ([]Migration, error) {
	entries, err := fs.ReadDir(sqlFS, ".")
	if err != nil {
		return nil, fmt.Errorf("migrate: read dir: %w", err)
	}

	var migrations []Migration
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || !strings.HasSuffix(name, ".sql") {
			continue
		}
		data, err := fs.ReadFile(sqlFS, name)
		if err != nil {
			return nil, fmt.Errorf("migrate: read %s: %w", name, err)
		}
		migrations = append(migrations, Migration{Name: name, SQL: string(data)})
	}

	sort.Slice(migrations, func(i, j int) bool {
		return migrations[i].Name < migrations[j].Name
	})

	return migrations, nil
}
