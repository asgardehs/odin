package schemabuilder

import (
	"fmt"
	"sort"
	"strings"
)

// QueryBuilder generates parameterized SQL for a cx_ table's CRUD
// operations. Column names are drawn from the table's metadata and
// interpolated as quoted identifiers; values are always bound.
//
// The builder is stateless — it carries nothing between calls, so one
// instance per process is fine and calls are safe to use concurrently.
type QueryBuilder struct {
	Executor *Executor
}

// NewQueryBuilder returns a QueryBuilder that reads metadata via ex.
func NewQueryBuilder(ex *Executor) *QueryBuilder {
	return &QueryBuilder{Executor: ex}
}

// SelectOpts controls a Select call.
type SelectOpts struct {
	// Limit + Offset for pagination. A zero Limit means "default 50".
	Limit  int
	Offset int
	// Search is a substring search across all active text/select/date
	// fields. Empty means no search.
	Search string
	// EstablishmentID scopes the result. A non-nil value restricts
	// rows to that establishment; nil returns all rows regardless.
	EstablishmentID *int64
	// IncludeInactive returns rows regardless of any is_active column
	// on the underlying cx_ table. (System metadata is_active isn't
	// applied to record rows — this covers future-defined custom
	// is_active fields.)
	IncludeInactive bool
	// JoinRelations, when true, LEFT JOINs each active belongs_to
	// relation's target and appends a `{fieldName}__label` column
	// containing the relation's display_field value from the target
	// row.
	JoinRelations bool
}

// Select builds a SELECT query for a cx_ table.
// Returns (sql, bound args, error).
func (qb *QueryBuilder) Select(tableID int64, opts SelectOpts) (string, []any, error) {
	t, err := qb.Executor.LoadTable(tableID)
	if err != nil {
		return "", nil, err
	}
	if t == nil {
		return "", nil, fmt.Errorf("table %d not found", tableID)
	}
	if !t.IsActive {
		return "", nil, fmt.Errorf("table %q is inactive", t.Name)
	}

	phys := t.PhysicalName()
	cols := []string{"t.id", "t.establishment_id", "t.created_at", "t.updated_at"}
	for _, f := range t.Fields {
		if !f.IsActive {
			continue
		}
		cols = append(cols, fmt.Sprintf("t.%s", quoteIdent(f.Name)))
	}

	var joins []string
	if opts.JoinRelations {
		joinCols, joinSQL := qb.buildRelationJoins(t)
		cols = append(cols, joinCols...)
		joins = append(joins, joinSQL...)
	}

	var where []string
	var args []any
	if opts.EstablishmentID != nil {
		where = append(where, "t.establishment_id = ?")
		args = append(args, *opts.EstablishmentID)
	}
	if s := strings.TrimSpace(opts.Search); s != "" {
		searchClause, searchArgs := qb.buildSearchClause(t, s)
		if searchClause != "" {
			where = append(where, searchClause)
			args = append(args, searchArgs...)
		}
	}

	limit := opts.Limit
	if limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}

	var b strings.Builder
	b.WriteString("SELECT ")
	b.WriteString(strings.Join(cols, ", "))
	b.WriteString(" FROM ")
	b.WriteString(quoteIdent(phys))
	b.WriteString(" AS t")
	for _, j := range joins {
		b.WriteString(" ")
		b.WriteString(j)
	}
	if len(where) > 0 {
		b.WriteString(" WHERE ")
		b.WriteString(strings.Join(where, " AND "))
	}
	b.WriteString(" ORDER BY t.id DESC LIMIT ? OFFSET ?")
	args = append(args, limit, opts.Offset)

	return b.String(), args, nil
}

// Count mirrors Select but returns the COUNT(*) SQL — used to drive
// pagination in the generic record list.
func (qb *QueryBuilder) Count(tableID int64, opts SelectOpts) (string, []any, error) {
	t, err := qb.Executor.LoadTable(tableID)
	if err != nil {
		return "", nil, err
	}
	if t == nil {
		return "", nil, fmt.Errorf("table %d not found", tableID)
	}
	if !t.IsActive {
		return "", nil, fmt.Errorf("table %q is inactive", t.Name)
	}

	phys := t.PhysicalName()
	var where []string
	var args []any
	if opts.EstablishmentID != nil {
		where = append(where, "t.establishment_id = ?")
		args = append(args, *opts.EstablishmentID)
	}
	if s := strings.TrimSpace(opts.Search); s != "" {
		searchClause, searchArgs := qb.buildSearchClause(t, s)
		if searchClause != "" {
			where = append(where, searchClause)
			args = append(args, searchArgs...)
		}
	}

	var b strings.Builder
	b.WriteString("SELECT COUNT(*) FROM ")
	b.WriteString(quoteIdent(phys))
	b.WriteString(" AS t")
	if len(where) > 0 {
		b.WriteString(" WHERE ")
		b.WriteString(strings.Join(where, " AND "))
	}
	return b.String(), args, nil
}

// SelectByID returns SQL for fetching a single row by id. Relations
// are always joined when present.
func (qb *QueryBuilder) SelectByID(tableID int64, id int64) (string, []any, error) {
	t, err := qb.Executor.LoadTable(tableID)
	if err != nil {
		return "", nil, err
	}
	if t == nil {
		return "", nil, fmt.Errorf("table %d not found", tableID)
	}

	phys := t.PhysicalName()
	cols := []string{"t.id", "t.establishment_id", "t.created_at", "t.updated_at"}
	for _, f := range t.Fields {
		if !f.IsActive {
			continue
		}
		cols = append(cols, fmt.Sprintf("t.%s", quoteIdent(f.Name)))
	}
	joinCols, joinSQL := qb.buildRelationJoins(t)
	cols = append(cols, joinCols...)

	var b strings.Builder
	b.WriteString("SELECT ")
	b.WriteString(strings.Join(cols, ", "))
	b.WriteString(" FROM ")
	b.WriteString(quoteIdent(phys))
	b.WriteString(" AS t")
	for _, j := range joinSQL {
		b.WriteString(" ")
		b.WriteString(j)
	}
	b.WriteString(" WHERE t.id = ?")
	return b.String(), []any{id}, nil
}

// Insert builds an INSERT statement from values, filtering out keys
// that aren't active fields on the table. Allowed system-column keys:
// `establishment_id`.
func (qb *QueryBuilder) Insert(tableID int64, values map[string]any) (string, []any, error) {
	t, err := qb.Executor.LoadTable(tableID)
	if err != nil {
		return "", nil, err
	}
	if t == nil {
		return "", nil, fmt.Errorf("table %d not found", tableID)
	}
	if !t.IsActive {
		return "", nil, fmt.Errorf("table %q is inactive", t.Name)
	}

	allowed := activeFieldSet(t)
	allowed["establishment_id"] = struct{}{}

	cols, args := pickKnown(values, allowed)
	// Required-field enforcement: any active required field must
	// appear in the insert payload.
	for _, f := range t.Fields {
		if !f.IsActive || !f.IsRequired {
			continue
		}
		if _, ok := values[f.Name]; !ok {
			return "", nil, fmt.Errorf("required field %q missing", f.Name)
		}
	}
	if len(cols) == 0 {
		return "", nil, fmt.Errorf("no known columns in payload")
	}

	var b strings.Builder
	b.WriteString("INSERT INTO ")
	b.WriteString(quoteIdent(t.PhysicalName()))
	b.WriteString(" (")
	b.WriteString(joinIdents(cols))
	b.WriteString(") VALUES (")
	b.WriteString(placeholders(len(cols)))
	b.WriteString(")")
	return b.String(), args, nil
}

// Update builds an UPDATE statement from values. Unknown keys filtered
// out. An `updated_at = datetime('now')` is always appended.
func (qb *QueryBuilder) Update(tableID int64, id int64, values map[string]any) (string, []any, error) {
	t, err := qb.Executor.LoadTable(tableID)
	if err != nil {
		return "", nil, err
	}
	if t == nil {
		return "", nil, fmt.Errorf("table %d not found", tableID)
	}
	if !t.IsActive {
		return "", nil, fmt.Errorf("table %q is inactive", t.Name)
	}

	allowed := activeFieldSet(t)
	allowed["establishment_id"] = struct{}{}

	cols, args := pickKnown(values, allowed)
	if len(cols) == 0 {
		return "", nil, fmt.Errorf("no known columns in payload")
	}

	var b strings.Builder
	b.WriteString("UPDATE ")
	b.WriteString(quoteIdent(t.PhysicalName()))
	b.WriteString(" SET ")
	for i, c := range cols {
		if i > 0 {
			b.WriteString(", ")
		}
		b.WriteString(quoteIdent(c))
		b.WriteString(" = ?")
	}
	b.WriteString(", updated_at = datetime('now') WHERE id = ?")
	args = append(args, id)
	return b.String(), args, nil
}

// Delete builds a DELETE statement for one row by id.
func (qb *QueryBuilder) Delete(tableID int64, id int64) (string, []any, error) {
	t, err := qb.Executor.LoadTable(tableID)
	if err != nil {
		return "", nil, err
	}
	if t == nil {
		return "", nil, fmt.Errorf("table %d not found", tableID)
	}
	// Deletes from inactive tables are also blocked here — the record
	// routes return 404 before reaching this builder, but guard anyway.
	if !t.IsActive {
		return "", nil, fmt.Errorf("table %q is inactive", t.Name)
	}
	sql := fmt.Sprintf("DELETE FROM %s WHERE id = ?", quoteIdent(t.PhysicalName()))
	return sql, []any{id}, nil
}

// ============================================================
// Helpers
// ============================================================

// buildRelationJoins returns (extra SELECT columns, JOIN clauses) for
// every active belongs_to relation. The extra column name follows the
// convention `{fieldName}__label`.
func (qb *QueryBuilder) buildRelationJoins(t *CustomTable) ([]string, []string) {
	if len(t.Relations) == 0 {
		return nil, nil
	}
	fieldByID := make(map[int64]CustomField, len(t.Fields))
	for _, f := range t.Fields {
		fieldByID[f.ID] = f
	}

	var extraCols, joins []string
	for i, r := range t.Relations {
		if !r.IsActive || r.RelationType != RelationBelongsTo {
			continue
		}
		f, ok := fieldByID[r.SourceFieldID]
		if !ok || !f.IsActive {
			continue
		}
		alias := fmt.Sprintf("r%d", i)
		extraCols = append(extraCols,
			fmt.Sprintf("%s.%s AS %s",
				alias,
				quoteIdent(r.DisplayField),
				quoteIdent(f.Name+"__label"),
			),
		)
		joins = append(joins, fmt.Sprintf(
			"LEFT JOIN %s AS %s ON %s.id = t.%s",
			quoteIdent(r.TargetTableName),
			alias,
			alias,
			quoteIdent(f.Name),
		))
	}
	return extraCols, joins
}

// buildSearchClause returns a WHERE fragment like
// "(t.col1 LIKE ? OR t.col2 LIKE ?)" searching active text-ish fields.
// An empty result means no searchable fields exist.
func (qb *QueryBuilder) buildSearchClause(t *CustomTable, q string) (string, []any) {
	var parts []string
	var args []any
	pattern := "%" + q + "%"
	for _, f := range t.Fields {
		if !f.IsActive {
			continue
		}
		switch f.FieldType {
		case FieldText, FieldSelect, FieldDate, FieldDatetime:
			parts = append(parts, fmt.Sprintf("t.%s LIKE ?", quoteIdent(f.Name)))
			args = append(args, pattern)
		}
	}
	if len(parts) == 0 {
		return "", nil
	}
	return "(" + strings.Join(parts, " OR ") + ")", args
}

// activeFieldSet returns the set of column names that are legitimate
// targets for insert/update payloads on t.
func activeFieldSet(t *CustomTable) map[string]struct{} {
	out := make(map[string]struct{}, len(t.Fields))
	for _, f := range t.Fields {
		if f.IsActive {
			out[f.Name] = struct{}{}
		}
	}
	return out
}

// pickKnown returns the subset of values keyed by names in allowed,
// with the keys sorted for deterministic SQL.
func pickKnown(values map[string]any, allowed map[string]struct{}) ([]string, []any) {
	cols := make([]string, 0, len(values))
	for k := range values {
		if _, ok := allowed[k]; ok {
			cols = append(cols, k)
		}
	}
	sort.Strings(cols)
	args := make([]any, 0, len(cols))
	for _, c := range cols {
		args = append(args, values[c])
	}
	return cols, args
}

func joinIdents(cols []string) string {
	parts := make([]string, len(cols))
	for i, c := range cols {
		parts[i] = quoteIdent(c)
	}
	return strings.Join(parts, ", ")
}

func placeholders(n int) string {
	if n == 0 {
		return ""
	}
	return strings.Repeat("?,", n-1) + "?"
}
