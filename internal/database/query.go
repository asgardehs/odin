package database

import (
	"fmt"

	"github.com/ncruces/go-sqlite3"
)

// Row is a generic result row keyed by column name.
type Row map[string]any

// QueryRows executes a SELECT and returns all result rows.
// Parameters are bound positionally (?1, ?2, ...).
func (db *DB) QueryRows(sql string, args ...any) ([]Row, error) {
	db.mu.Lock()
	defer db.mu.Unlock()
	stmt, _, err := db.conn.Prepare(sql)
	if err != nil {
		return nil, fmt.Errorf("query: prepare: %w", err)
	}
	defer stmt.Close()

	if err := bindArgs(stmt, args); err != nil {
		return nil, err
	}

	var rows []Row
	cols := columnNames(stmt)
	for stmt.Step() {
		row := make(Row, len(cols))
		for i, name := range cols {
			row[name] = columnValue(stmt, i)
		}
		rows = append(rows, row)
	}
	if err := stmt.Err(); err != nil {
		return nil, fmt.Errorf("query: step: %w", err)
	}
	return rows, nil
}

// QueryRow executes a SELECT and returns the first result row.
// Returns nil if no rows match.
func (db *DB) QueryRow(sql string, args ...any) (Row, error) {
	db.mu.Lock()
	defer db.mu.Unlock()
	stmt, _, err := db.conn.Prepare(sql)
	if err != nil {
		return nil, fmt.Errorf("query: prepare: %w", err)
	}
	defer stmt.Close()

	if err := bindArgs(stmt, args); err != nil {
		return nil, err
	}

	if !stmt.Step() {
		if err := stmt.Err(); err != nil {
			return nil, fmt.Errorf("query: step: %w", err)
		}
		return nil, nil
	}

	cols := columnNames(stmt)
	row := make(Row, len(cols))
	for i, name := range cols {
		row[name] = columnValue(stmt, i)
	}
	return row, nil
}

// QueryVal executes a SELECT and returns the first column of the first row.
// Returns the zero value and nil error if no rows match.
func (db *DB) QueryVal(sql string, args ...any) (any, error) {
	db.mu.Lock()
	defer db.mu.Unlock()
	stmt, _, err := db.conn.Prepare(sql)
	if err != nil {
		return nil, fmt.Errorf("query: prepare: %w", err)
	}
	defer stmt.Close()

	if err := bindArgs(stmt, args); err != nil {
		return nil, err
	}

	if !stmt.Step() {
		if err := stmt.Err(); err != nil {
			return nil, fmt.Errorf("query: step: %w", err)
		}
		return nil, nil
	}
	return columnValue(stmt, 0), nil
}

// ExecParams executes a statement with bound parameters.
// Use for INSERT, UPDATE, DELETE with ? placeholders.
func (db *DB) ExecParams(sql string, args ...any) error {
	db.mu.Lock()
	defer db.mu.Unlock()
	stmt, _, err := db.conn.Prepare(sql)
	if err != nil {
		return fmt.Errorf("exec: prepare: %w", err)
	}
	defer stmt.Close()

	if err := bindArgs(stmt, args); err != nil {
		return err
	}

	stmt.Step()
	if err := stmt.Err(); err != nil {
		return fmt.Errorf("exec: step: %w", err)
	}
	return stmt.Close()
}

// bindArgs binds parameters to a prepared statement by position.
// Supports pointer types (*string, *int, *int64, *float64) — nil pointers
// bind as NULL, non-nil pointers dereference to their underlying type.
func bindArgs(stmt *sqlite3.Stmt, args []any) error {
	for i, arg := range args {
		pos := i + 1 // sqlite params are 1-indexed
		// Dereference pointer types to their values, or nil.
		arg = derefPtr(arg)
		switch v := arg.(type) {
		case nil:
			if err := stmt.BindNull(pos); err != nil {
				return fmt.Errorf("query: bind %d: %w", pos, err)
			}
		case int:
			if err := stmt.BindInt(pos, v); err != nil {
				return fmt.Errorf("query: bind %d: %w", pos, err)
			}
		case int64:
			if err := stmt.BindInt64(pos, v); err != nil {
				return fmt.Errorf("query: bind %d: %w", pos, err)
			}
		case float64:
			if err := stmt.BindFloat(pos, v); err != nil {
				return fmt.Errorf("query: bind %d: %w", pos, err)
			}
		case string:
			if err := stmt.BindText(pos, v); err != nil {
				return fmt.Errorf("query: bind %d: %w", pos, err)
			}
		case bool:
			if err := stmt.BindBool(pos, v); err != nil {
				return fmt.Errorf("query: bind %d: %w", pos, err)
			}
		case []byte:
			if err := stmt.BindBlob(pos, v); err != nil {
				return fmt.Errorf("query: bind %d: %w", pos, err)
			}
		default:
			return fmt.Errorf("query: bind %d: unsupported type %T", pos, arg)
		}
	}
	return nil
}

// derefPtr unwraps pointer types to their underlying value, or nil
// if the pointer is nil. This lets repository code pass *string, *int,
// *int64, *float64 directly as bind args.
func derefPtr(v any) any {
	switch p := v.(type) {
	case *string:
		if p == nil {
			return nil
		}
		return *p
	case *int:
		if p == nil {
			return nil
		}
		return *p
	case *int64:
		if p == nil {
			return nil
		}
		return *p
	case *float64:
		if p == nil {
			return nil
		}
		return *p
	case *bool:
		if p == nil {
			return nil
		}
		return *p
	}
	return v
}

// columnNames returns the names of all columns in the result set.
func columnNames(stmt *sqlite3.Stmt) []string {
	n := stmt.ColumnCount()
	names := make([]string, n)
	for i := range n {
		names[i] = stmt.ColumnName(i)
	}
	return names
}

// columnValue reads a column value using SQLite's type affinity.
func columnValue(stmt *sqlite3.Stmt, col int) any {
	switch stmt.ColumnType(col) {
	case sqlite3.INTEGER:
		return stmt.ColumnInt64(col)
	case sqlite3.FLOAT:
		return stmt.ColumnFloat(col)
	case sqlite3.TEXT:
		return stmt.ColumnText(col)
	case sqlite3.BLOB:
		return stmt.ColumnBlob(col, nil)
	default: // NULL
		return nil
	}
}
