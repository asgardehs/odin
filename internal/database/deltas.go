package database

import (
	"fmt"
	"io/fs"
	"regexp"
	"sort"
	"strings"
)

// ApplyDeltas runs forward-only schema deltas from deltaFS. Deltas are
// tracked by name in the existing _migrations table (same mechanism as
// module migrations) so each delta runs exactly once.
//
// Deltas differ from module migrations in what they represent:
//
//   - Module migrations (CollectMigrations) are "here is the whole
//     schema" — meant for fresh installs. Their CREATE TABLE statements
//     use IF NOT EXISTS but their content after initial apply is
//     frozen relative to any given DB (the module is marked applied
//     and never re-runs).
//
//   - Deltas are "here is how to get from an earlier shape to the
//     current shape" — meant for existing DBs that predate a schema
//     change. A delta for adding a column issues ALTER TABLE ADD
//     COLUMN; the runner guards each ALTER with a pragma_table_info
//     check so the statement is a no-op on fresh installs (where the
//     module's CREATE TABLE already included the column).
//
// Non-ALTER statements (CREATE TABLE IF NOT EXISTS, INSERT OR IGNORE,
// UPDATE ... WHERE ...) must be authored idempotently; the runner does
// not transform them. If a change requires more complex idempotency
// (e.g. data backfill where the "already applied" state is ambiguous),
// the delta's author is responsible.
//
// Deltas run in alphabetical order of filename. The convention is
// "YYYY-MM-DD-short-description.sql" for chronological ordering.
func ApplyDeltas(db *DB, deltaFS fs.FS) error {
	entries, err := fs.ReadDir(deltaFS, ".")
	if err != nil {
		return fmt.Errorf("deltas: read dir: %w", err)
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
		applied, err := migrationApplied(db, name)
		if err != nil {
			return fmt.Errorf("deltas: check applied for %s: %w", name, err)
		}
		if applied {
			continue
		}
		data, err := fs.ReadFile(deltaFS, name)
		if err != nil {
			return fmt.Errorf("deltas: read %s: %w", name, err)
		}
		if err := applyDeltaStatements(db, string(data)); err != nil {
			return fmt.Errorf("deltas: apply %s: %w", name, err)
		}
		if err := recordMigration(db, name); err != nil {
			return fmt.Errorf("deltas: record %s: %w", name, err)
		}
	}
	return nil
}

// applyDeltaStatements splits a delta file into statements and executes
// each, guarding ALTER TABLE ADD COLUMN with a pragma_table_info check
// so re-running the delta on an already-migrated DB is a no-op.
func applyDeltaStatements(db *DB, sql string) error {
	for _, stmt := range splitSQLStatements(sql) {
		if table, col, ok := parseAlterAddColumn(stmt); ok {
			exists, err := columnExists(db, table, col)
			if err != nil {
				return fmt.Errorf("column check %s.%s: %w", table, col, err)
			}
			if exists {
				continue
			}
		}
		if err := db.Exec(stmt); err != nil {
			return fmt.Errorf("exec: %w\nstatement:\n%s", err, stmt)
		}
	}
	return nil
}

// alterAddColumnRe matches "ALTER TABLE <name> ADD [COLUMN] <colname>"
// at the start of a statement. Case-insensitive; the optional COLUMN
// keyword is supported because SQLite accepts it either way.
var alterAddColumnRe = regexp.MustCompile(`(?is)^\s*ALTER\s+TABLE\s+(\w+)\s+ADD\s+(?:COLUMN\s+)?(\w+)\b`)

// parseAlterAddColumn returns (table, column, true) if the statement
// is an ALTER TABLE ADD COLUMN statement. Otherwise (_, _, false).
func parseAlterAddColumn(stmt string) (table, col string, ok bool) {
	m := alterAddColumnRe.FindStringSubmatch(stmt)
	if len(m) != 3 {
		return "", "", false
	}
	return m[1], m[2], true
}

// columnExists returns whether the table has a column with the given
// name. Uses pragma_table_info as a table-valued function so the table
// name can be bound as a parameter (safer than string interpolation).
func columnExists(db *DB, table, col string) (bool, error) {
	rows, err := db.QueryRows(`SELECT name FROM pragma_table_info(?)`, table)
	if err != nil {
		return false, err
	}
	for _, r := range rows {
		if name, _ := r["name"].(string); name == col {
			return true, nil
		}
	}
	return false, nil
}

// splitSQLStatements splits a SQL blob on statement-boundary
// semicolons, respecting single-quoted string literals (which may
// contain semicolons) and stripping -- line comments.
//
// Does not handle /* block comments */ — odin's SQL convention uses
// only line comments. Does not handle dollar-quoted strings ($$...$$)
// or other postgres-isms. Suitable for SQLite delta files containing
// CREATE TABLE, INSERT, UPDATE, and ALTER statements.
func splitSQLStatements(sql string) []string {
	var out []string
	var current strings.Builder
	inString := false

	for i := 0; i < len(sql); i++ {
		c := sql[i]

		// Line comment outside a string: skip to newline.
		if !inString && c == '-' && i+1 < len(sql) && sql[i+1] == '-' {
			for i < len(sql) && sql[i] != '\n' {
				i++
			}
			continue
		}

		// String literal boundary. SQL escapes ' as '' (two single
		// quotes in a row); preserve both and stay in-string.
		if c == '\'' {
			if inString && i+1 < len(sql) && sql[i+1] == '\'' {
				current.WriteByte(c)
				current.WriteByte(c)
				i++
				continue
			}
			inString = !inString
			current.WriteByte(c)
			continue
		}

		// Statement boundary.
		if c == ';' && !inString {
			if s := strings.TrimSpace(current.String()); s != "" {
				out = append(out, s)
			}
			current.Reset()
			continue
		}

		current.WriteByte(c)
	}
	if s := strings.TrimSpace(current.String()); s != "" {
		out = append(out, s)
	}
	return out
}
