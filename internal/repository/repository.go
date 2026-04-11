// Package repository provides CRUD operations for EHS entities with
// automatic audit trail recording. Every create, update, and delete
// captures before/after JSON snapshots committed to the git-backed
// audit store.
package repository

import (
	"encoding/json"
	"fmt"
	"strconv"

	"github.com/asgardehs/odin/internal/audit"
	"github.com/asgardehs/odin/internal/database"
)

// Repo is the base for all entity repositories. It holds shared
// dependencies and provides the audit-on-mutation pattern.
type Repo struct {
	DB    *database.DB
	Audit *audit.Store
}

// snapshot fetches a row by ID and returns it as JSON for audit records.
// Returns nil if the row doesn't exist (valid for create-before / delete-after).
func (r *Repo) snapshot(table string, id int64) json.RawMessage {
	row, err := r.DB.QueryRow(
		fmt.Sprintf("SELECT * FROM %s WHERE id = ?", table), id,
	)
	if err != nil || row == nil {
		return nil
	}
	data, err := json.Marshal(row)
	if err != nil {
		return nil
	}
	return data
}

// record writes an audit entry for a mutation.
func (r *Repo) record(action audit.Action, module string, id int64, user, summary string, before, after json.RawMessage) error {
	return r.Audit.Record(audit.Entry{
		Action:   action,
		Module:   module,
		EntityID: strconv.FormatInt(id, 10),
		User:     user,
		Summary:  summary,
		Before:   before,
		After:    after,
	})
}

// insertAndAudit executes an INSERT, retrieves the new row's ID,
// snapshots the result, and records a create audit entry.
func (r *Repo) insertAndAudit(table, module, user, summary, sql string, args ...any) (int64, error) {
	if err := r.DB.ExecParams(sql, args...); err != nil {
		return 0, fmt.Errorf("%s: insert: %w", module, err)
	}

	// Get the last inserted row ID.
	val, err := r.DB.QueryVal("SELECT last_insert_rowid()")
	if err != nil {
		return 0, fmt.Errorf("%s: last_insert_rowid: %w", module, err)
	}
	id := val.(int64)

	after := r.snapshot(table, id)
	if err := r.record(audit.ActionCreate, module, id, user, summary, nil, after); err != nil {
		return id, fmt.Errorf("%s: audit: %w", module, err)
	}
	return id, nil
}

// updateAndAudit snapshots before, executes the UPDATE, snapshots after,
// and records an update audit entry.
func (r *Repo) updateAndAudit(table, module string, id int64, user, summary, sql string, args ...any) error {
	before := r.snapshot(table, id)
	if before == nil {
		return fmt.Errorf("%s: record %d not found", module, id)
	}

	if err := r.DB.ExecParams(sql, args...); err != nil {
		return fmt.Errorf("%s: update: %w", module, err)
	}

	after := r.snapshot(table, id)
	if err := r.record(audit.ActionUpdate, module, id, user, summary, before, after); err != nil {
		return fmt.Errorf("%s: audit: %w", module, err)
	}
	return nil
}

// deleteAndAudit snapshots before, executes the DELETE, and records
// a delete audit entry.
func (r *Repo) deleteAndAudit(table, module string, id int64, user, summary, sql string, args ...any) error {
	before := r.snapshot(table, id)
	if before == nil {
		return fmt.Errorf("%s: record %d not found", module, id)
	}

	if err := r.DB.ExecParams(sql, args...); err != nil {
		return fmt.Errorf("%s: delete: %w", module, err)
	}

	if err := r.record(audit.ActionDelete, module, id, user, summary, before, nil); err != nil {
		return fmt.Errorf("%s: audit: %w", module, err)
	}
	return nil
}
