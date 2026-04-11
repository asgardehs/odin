// Package database manages the SQLite connection for Odin's EHS data.
//
// It uses ncruces/go-sqlite3 (Wasm-based, no CGO) and configures the
// connection for a single-user desktop application: WAL mode, foreign
// keys enabled, busy timeout for concurrent reads during writes.
package database

import (
	"fmt"

	"github.com/ncruces/go-sqlite3"
)

// DB wraps a sqlite3 connection with Odin-specific configuration.
type DB struct {
	conn *sqlite3.Conn
	path string
}

// Open creates or opens an SQLite database at path and applies pragmas.
func Open(path string) (*DB, error) {
	conn, err := sqlite3.Open(path)
	if err != nil {
		return nil, fmt.Errorf("database: open %s: %w", path, err)
	}

	db := &DB{conn: conn, path: path}
	if err := db.pragmas(); err != nil {
		conn.Close()
		return nil, err
	}
	return db, nil
}

// Conn returns the underlying sqlite3 connection for direct use.
func (db *DB) Conn() *sqlite3.Conn {
	return db.conn
}

// Close closes the database connection.
func (db *DB) Close() error {
	if db.conn != nil {
		return db.conn.Close()
	}
	return nil
}

// Exec executes a SQL statement that returns no rows.
func (db *DB) Exec(sql string) error {
	return db.conn.Exec(sql)
}

// FKViolation describes a foreign key constraint violation.
type FKViolation struct {
	Table  string
	RowID  int64
	Parent string
	FKIdx  int64
}

// CheckFK runs PRAGMA foreign_key_check and returns any violations.
// Returns nil if all foreign key constraints are satisfied.
func (db *DB) CheckFK() ([]FKViolation, error) {
	stmt, _, err := db.conn.Prepare("PRAGMA foreign_key_check")
	if err != nil {
		return nil, fmt.Errorf("database: fk check: %w", err)
	}
	defer stmt.Close()

	var violations []FKViolation
	for stmt.Step() {
		violations = append(violations, FKViolation{
			Table:  stmt.ColumnText(0),
			RowID:  stmt.ColumnInt64(1),
			Parent: stmt.ColumnText(2),
			FKIdx:  stmt.ColumnInt64(3),
		})
	}
	return violations, nil
}

// pragmas configures the connection for a desktop EHS application.
func (db *DB) pragmas() error {
	pragmas := []string{
		"PRAGMA journal_mode=WAL",    // concurrent reads during writes
		"PRAGMA foreign_keys=ON",     // enforce referential integrity
		"PRAGMA busy_timeout=5000",   // 5s retry on lock contention
		"PRAGMA synchronous=NORMAL",  // safe with WAL, better perf than FULL
		"PRAGMA cache_size=-64000",   // 64MB page cache
		"PRAGMA temp_store=MEMORY",   // temp tables in memory
		"PRAGMA mmap_size=268435456", // 256MB memory-mapped I/O
		"PRAGMA optimize",            // run optimizer on open
	}
	for _, p := range pragmas {
		if err := db.conn.Exec(p); err != nil {
			return fmt.Errorf("database: pragma %q: %w", p, err)
		}
	}
	return nil
}
