package database

import (
	"fmt"
	"net/http"
	"strconv"
)

// Page holds pagination parameters parsed from query strings.
type Page struct {
	Limit  int
	Offset int
}

// DefaultPageSize is the default number of rows per page.
const DefaultPageSize = 50

// MaxPageSize caps page size to prevent unbounded queries.
const MaxPageSize = 500

// PageFromRequest parses ?page=N&per_page=N from the request.
// Defaults to page 1, 50 rows per page.
func PageFromRequest(r *http.Request) Page {
	page := 1
	perPage := DefaultPageSize

	if v := r.URL.Query().Get("page"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			page = n
		}
	}
	if v := r.URL.Query().Get("per_page"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			perPage = n
		}
	}
	if perPage > MaxPageSize {
		perPage = MaxPageSize
	}

	return Page{
		Limit:  perPage,
		Offset: (page - 1) * perPage,
	}
}

// SQL returns "LIMIT ? OFFSET ?" and the corresponding bind values.
func (p Page) SQL() (string, []any) {
	return "LIMIT ? OFFSET ?", []any{p.Limit, p.Offset}
}

// PagedResult wraps a list response with pagination metadata.
type PagedResult struct {
	Data       []Row `json:"data"`
	Total      int64 `json:"total"`
	Page       int   `json:"page"`
	PerPage    int   `json:"per_page"`
	TotalPages int   `json:"total_pages"`
}

// QueryPaged runs a count query and a data query, returning a PagedResult.
// The countSQL should be "SELECT COUNT(*) FROM ...".
// The dataSQL should be "SELECT ... FROM ... LIMIT ? OFFSET ?".
// Args are shared between both queries; limit and offset are appended for data.
func (db *DB) QueryPaged(p Page, countSQL, dataSQL string, args ...any) (*PagedResult, error) {
	totalVal, err := db.QueryVal(countSQL, args...)
	if err != nil {
		return nil, fmt.Errorf("paged: count: %w", err)
	}
	var total int64
	if totalVal != nil {
		total = totalVal.(int64)
	}

	dataArgs := append(args, p.Limit, p.Offset)
	rows, err := db.QueryRows(dataSQL, dataArgs...)
	if err != nil {
		return nil, fmt.Errorf("paged: query: %w", err)
	}
	if rows == nil {
		rows = []Row{}
	}

	totalPages := int(total) / p.Limit
	if int(total)%p.Limit != 0 {
		totalPages++
	}

	return &PagedResult{
		Data:       rows,
		Total:      total,
		Page:       (p.Offset / p.Limit) + 1,
		PerPage:    p.Limit,
		TotalPages: totalPages,
	}, nil
}
