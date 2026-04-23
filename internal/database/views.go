package database

import (
	"fmt"
	"io/fs"
	"sort"
	"strings"
)

// LoadViews re-executes every *.sql file under the given filesystem
// against the database. Unlike Migrate, LoadViews runs on every odin
// startup — no _migrations tracking, no idempotency guard beyond what
// the SQL itself provides (typical pattern is DROP VIEW IF EXISTS
// followed by CREATE VIEW).
//
// This path exists because view definitions evolve more often than
// tables and don't carry data. Tracking view updates in _migrations
// would require bumping the migration name every time a view body
// changed — painful in dev, easy to forget. Re-executing the DDL on
// startup makes pulls propagate to running servers with just a restart.
//
// Files are executed in alphabetical order for deterministic behavior
// when one view references another. Subdirectories are not traversed.
func LoadViews(db *DB, viewsFS fs.FS) error {
	entries, err := fs.ReadDir(viewsFS, ".")
	if err != nil {
		return fmt.Errorf("load views: read dir: %w", err)
	}

	var names []string
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".sql") {
			continue
		}
		names = append(names, e.Name())
	}
	sort.Strings(names)

	for _, name := range names {
		data, err := fs.ReadFile(viewsFS, name)
		if err != nil {
			return fmt.Errorf("load views: read %s: %w", name, err)
		}
		if err := db.Exec(string(data)); err != nil {
			return fmt.Errorf("load views: exec %s: %w", name, err)
		}
	}
	return nil
}
