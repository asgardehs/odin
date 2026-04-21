// Package importer provides the CSV import framework. Each module that
// supports bulk import registers an Importer; the shared Engine handles
// upload, column mapping, validation, and commit. Mappers own their
// per-row validation and the INSERT statement; the engine owns the token
// lifecycle, audit trail, and transaction.
package importer

import (
	"regexp"
	"sort"
	"strings"
)

// IgnoreMarker is the sentinel value in a mapping that marks a source
// column as deliberately unmapped. It distinguishes "no match suggested"
// (empty string) from "user explicitly said ignore this column."
const IgnoreMarker = "__ignore__"

// TargetField describes one mappable column on a target entity.
type TargetField struct {
	Name        string   `json:"name"`        // target column name, e.g. "first_name"
	Label       string   `json:"label"`       // human-facing label, e.g. "First Name"
	Required    bool     `json:"required"`    // must have a mapping; must be non-empty
	Aliases     []string `json:"aliases"`     // synonyms used by the fuzzy matcher
	Description string   `json:"description"` // hover hint in the UI
}

// ValidationError is one row/column validation failure.
type ValidationError struct {
	Row     int    `json:"row"`     // 1-indexed row number (first data row is 1)
	Column  string `json:"column"`  // target field name, or "" for row-level errors
	Message string `json:"message"`
}

// Importer is implemented by each module that supports CSV import.
// Mappers validate rows one at a time and persist them one at a time; the
// engine coordinates the token lifecycle and audit trail.
type Importer interface {
	// ModuleSlug is the URL-safe identifier, e.g. "employees".
	ModuleSlug() string

	// TargetFields returns all user-mappable columns. The order here
	// determines the display order in the mapping UI.
	TargetFields() []TargetField

	// ValidateRow checks a single raw row against the current mapping.
	// raw maps source header -> raw cell value (as a string).
	// mapping maps source header -> target field name (or IgnoreMarker).
	// rowIdx is the 1-indexed row number (for error reporting).
	// On success it returns a validated, type-coerced payload ready for
	// InsertRow; on failure it returns any number of ValidationErrors.
	ValidateRow(
		raw map[string]string,
		mapping map[string]string,
		rowIdx int,
		ctx RowContext,
	) (payload any, errs []ValidationError)

	// InsertRow persists one validated payload. Must be callable inside a
	// transaction; returns the new row's id.
	InsertRow(db Execer, payload any, ctx RowContext) (id int64, err error)
}

// RowContext passes per-import knobs (e.g. the target establishment) into
// each row's validation and insert.
type RowContext struct {
	EstablishmentID *int64 // set when the importer wants every row to land on a specific facility
	UploadedBy      string
	DB              Execer // opt-in: mappers that need FK lookups during validation read from this
}

// Execer is the subset of the database API the importer needs for INSERTs.
// Satisfied by *database.DB (outside a tx) or a tx wrapper (inside one).
type Execer interface {
	ExecParams(sql string, args ...any) error
	QueryVal(sql string, args ...any) (any, error)
}

// ---- Fuzzy match ----------------------------------------------------------

// SuggestMapping proposes a source-header → target-field mapping using
// token-based similarity plus target-field aliases. Source columns with no
// sufficiently-similar target get an IgnoreMarker.
//
// Scoring uses the overlap coefficient — |A ∩ B| / min(|A|, |B|) — rather
// than Jaccard because source headers ("Title", "Surname") are frequently
// one or two tokens while target fields accumulate many aliases; Jaccard
// divides by the union and thereby penalizes exactly the short-source /
// rich-target shape that actually indicates a good match.
func SuggestMapping(sourceHeaders []string, targetFields []TargetField) map[string]string {
	const matchThreshold = 0.6

	// Precompute normalized token sets for target fields and their aliases.
	type candidate struct {
		field  string
		tokens map[string]struct{}
	}
	var candidates []candidate
	for _, tf := range targetFields {
		seen := map[string]struct{}{}
		add := func(s string) {
			for _, tok := range normalizeTokens(s) {
				seen[tok] = struct{}{}
			}
		}
		add(tf.Name)
		add(tf.Label)
		for _, a := range tf.Aliases {
			add(a)
		}
		if len(seen) > 0 {
			candidates = append(candidates, candidate{field: tf.Name, tokens: seen})
		}
	}

	// Track which target fields have already been claimed so we don't map
	// two source headers to the same target. Ties broken by source-header
	// order (stable, deterministic).
	claimed := map[string]bool{}
	out := map[string]string{}

	for _, src := range sourceHeaders {
		srcTokens := normalizeTokens(src)
		if len(srcTokens) == 0 {
			out[src] = IgnoreMarker
			continue
		}
		srcSet := map[string]struct{}{}
		for _, t := range srcTokens {
			srcSet[t] = struct{}{}
		}

		type scored struct {
			field string
			score float64
		}
		var scores []scored
		for _, c := range candidates {
			if claimed[c.field] {
				continue
			}
			scores = append(scores, scored{field: c.field, score: overlap(srcSet, c.tokens)})
		}
		sort.SliceStable(scores, func(i, j int) bool { return scores[i].score > scores[j].score })

		if len(scores) > 0 && scores[0].score >= matchThreshold {
			out[src] = scores[0].field
			claimed[scores[0].field] = true
		} else {
			out[src] = IgnoreMarker
		}
	}
	return out
}

var nonAlnum = regexp.MustCompile(`[^a-z0-9]+`)

// normalizeTokens lowercases, strips punctuation, and splits on
// whitespace / underscores / camelCase boundaries.
func normalizeTokens(s string) []string {
	s = strings.ToLower(strings.TrimSpace(s))
	s = nonAlnum.ReplaceAllString(s, " ")
	var out []string
	for _, tok := range strings.Fields(s) {
		if tok == "" {
			continue
		}
		out = append(out, tok)
	}
	return out
}

// overlap returns |a ∩ b| / min(|a|, |b|). Biased toward small-vs-large
// matches where the smaller set is wholly contained in the larger.
func overlap(a, b map[string]struct{}) float64 {
	if len(a) == 0 || len(b) == 0 {
		return 0
	}
	var inter int
	for k := range a {
		if _, ok := b[k]; ok {
			inter++
		}
	}
	min := len(a)
	if len(b) < min {
		min = len(b)
	}
	return float64(inter) / float64(min)
}
