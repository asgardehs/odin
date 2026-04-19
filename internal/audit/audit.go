// Package audit provides a git-backed, tamper-evident audit trail.
//
// Every data mutation in Odin is recorded as a JSON file and committed
// to a local Git repository. The SHA-linked commit history provides
// cryptographic proof that records have not been altered after the fact.
//
// Access to the audit trail requires OS-level authentication via the
// auth package — users must re-enter their system password to view,
// compare, or export audit history.
package audit

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/asgardehs/odin/internal/auth"
	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing/object"
)

// Action describes the type of mutation that occurred.
type Action string

const (
	ActionCreate Action = "create"
	ActionUpdate Action = "update"
	ActionDelete Action = "delete"
)

// Entry is a single audit record written as JSON and committed to Git.
type Entry struct {
	Timestamp time.Time       `json:"timestamp"`
	Action    Action          `json:"action"`
	Module    string          `json:"module"`    // e.g. "incidents", "chemicals"
	EntityID  string          `json:"entity_id"` // primary key of the record
	User      string          `json:"user"`      // OS username who made the change
	Summary   string          `json:"summary"`   // human-readable description
	Before    json.RawMessage `json:"before,omitempty"`
	After     json.RawMessage `json:"after,omitempty"`
}

// HistoryEntry is a single item returned when querying the audit log.
type HistoryEntry struct {
	Entry
	CommitHash string    `json:"commit_hash"`
	CommitTime time.Time `json:"commit_time"`
}

// Store manages the git-backed audit repository.
type Store struct {
	root string
	repo *git.Repository
	auth auth.Authenticator
}

// NewStore opens or initialises the audit repository at root.
// The authenticator is used to gate read operations.
func NewStore(root string, authenticator auth.Authenticator) (*Store, error) {
	if err := os.MkdirAll(root, 0o700); err != nil {
		return nil, fmt.Errorf("audit: create dir: %w", err)
	}

	repo, err := git.PlainOpen(root)
	if errors.Is(err, git.ErrRepositoryNotExists) {
		repo, err = git.PlainInit(root, false)
	}
	if err != nil {
		return nil, fmt.Errorf("audit: init repo: %w", err)
	}

	return &Store{root: root, repo: repo, auth: authenticator}, nil
}

// Record writes an audit entry and commits it to the local repository.
// This is called by service-layer code after every data mutation.
func (s *Store) Record(e Entry) error {
	if e.Timestamp.IsZero() {
		e.Timestamp = time.Now().UTC()
	}
	if e.User == "" {
		e.User = s.auth.CurrentUser()
	}

	// Write the JSON file.
	dir := filepath.Join(s.root, e.Module)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return fmt.Errorf("audit: mkdir: %w", err)
	}

	filename := fmt.Sprintf("%s_%s_%s.json",
		e.Timestamp.Format("2006-01-02T15-04-05"),
		e.Action,
		e.EntityID,
	)
	path := filepath.Join(dir, filename)

	data, err := json.MarshalIndent(e, "", "  ")
	if err != nil {
		return fmt.Errorf("audit: marshal: %w", err)
	}

	if err := os.WriteFile(path, data, 0o600); err != nil {
		return fmt.Errorf("audit: write: %w", err)
	}

	// Stage and commit.
	wt, err := s.repo.Worktree()
	if err != nil {
		return fmt.Errorf("audit: worktree: %w", err)
	}

	relPath, _ := filepath.Rel(s.root, path)
	if _, err := wt.Add(relPath); err != nil {
		return fmt.Errorf("audit: stage: %w", err)
	}

	msg := fmt.Sprintf("%s %s %s: %s", e.Action, e.Module, e.EntityID, e.Summary)
	_, err = wt.Commit(msg, &git.CommitOptions{
		Author: &object.Signature{
			Name:  e.User,
			Email: e.User + "@odin.local",
			When:  e.Timestamp,
		},
	})
	if err != nil {
		return fmt.Errorf("audit: commit: %w", err)
	}

	return nil
}

// History returns the audit trail for a specific entity. The caller
// must provide valid OS credentials — this is the gatekeeper.
func (s *Store) History(module, entityID string, creds auth.Credentials) ([]HistoryEntry, error) {
	if err := s.auth.Verify(creds.Username, creds.Password); err != nil {
		// Log the failed access attempt (best-effort).
		_ = s.Record(Entry{
			Action:  ActionRead,
			Module:  "audit_access",
			User:    creds.Username,
			Summary: fmt.Sprintf("failed auth attempt for %s/%s", module, entityID),
		})
		return nil, fmt.Errorf("audit: %w", err)
	}

	return s.readHistory(module, entityID)
}

// ReadHistoryAsAdmin returns entity history for an in-app admin whose
// identity has already been verified by the HTTP layer (session token +
// admin role check). The read is recorded in the audit log so the
// access trail is preserved. This path is weaker than History() — it
// relies on web session auth rather than OS credentials — and is
// intended for day-to-day review inside the app. Formal compliance
// access should continue to use History() with OS credentials.
func (s *Store) ReadHistoryAsAdmin(module, entityID, adminUser string) ([]HistoryEntry, error) {
	_ = s.Record(Entry{
		Action:  ActionRead,
		Module:  "audit_access",
		User:    adminUser,
		Summary: fmt.Sprintf("admin read %s/%s", module, entityID),
	})
	return s.readHistory(module, entityID)
}

// Export returns all audit entries in a date range. Requires auth.
func (s *Store) Export(start, end time.Time, creds auth.Credentials) ([]HistoryEntry, error) {
	if err := s.auth.Verify(creds.Username, creds.Password); err != nil {
		_ = s.Record(Entry{
			Action:  ActionRead,
			Module:  "audit_access",
			User:    creds.Username,
			Summary: "failed auth attempt for export",
		})
		return nil, fmt.Errorf("audit: %w", err)
	}

	return s.readHistoryRange(start, end)
}

// ActionRead is used internally to track audit-log access attempts.
const ActionRead Action = "read"

// readHistory walks the git log and collects entries matching
// the given module and entity ID.
func (s *Store) readHistory(module, entityID string) ([]HistoryEntry, error) {
	pattern := filepath.Join(module, fmt.Sprintf("*_%s.json", entityID))
	return s.walkLog(func(path string) bool {
		matched, _ := filepath.Match(pattern, path)
		return matched
	})
}

// readHistoryRange walks the git log and collects entries within
// the given time range.
func (s *Store) readHistoryRange(start, end time.Time) ([]HistoryEntry, error) {
	return s.walkLog(func(_ string) bool {
		return true // we filter by commit time below
	}, start, end)
}

// walkLog iterates over commits, optionally filtering by time range,
// and collects matching audit entries. Only files introduced or changed
// in each commit are considered (not the full cumulative tree).
func (s *Store) walkLog(matchPath func(string) bool, timeRange ...time.Time) ([]HistoryEntry, error) {
	ref, err := s.repo.Head()
	if err != nil {
		// Empty repo — no history yet.
		return nil, nil
	}

	iter, err := s.repo.Log(&git.LogOptions{From: ref.Hash()})
	if err != nil {
		return nil, fmt.Errorf("audit: log: %w", err)
	}

	var start, end time.Time
	if len(timeRange) == 2 {
		start, end = timeRange[0], timeRange[1]
	}

	var entries []HistoryEntry
	err = iter.ForEach(func(c *object.Commit) error {
		// Time-range filter.
		if !start.IsZero() && c.Author.When.Before(start) {
			return nil
		}
		if !end.IsZero() && c.Author.When.After(end) {
			return nil
		}

		// Get the diff against the parent to find only files changed in this commit.
		currentTree, err := c.Tree()
		if err != nil {
			return nil
		}

		var parentTree *object.Tree
		if c.NumParents() > 0 {
			parent, err := c.Parents().Next()
			if err == nil {
				parentTree, _ = parent.Tree()
			}
		}

		changes, err := object.DiffTree(parentTree, currentTree)
		if err != nil {
			return nil
		}

		for _, change := range changes {
			name := change.To.Name // file path in the new tree
			if name == "" {
				continue // deleted file
			}
			if !matchPath(name) {
				continue
			}

			f, err := currentTree.File(name)
			if err != nil {
				continue
			}

			contents, err := f.Contents()
			if err != nil {
				continue
			}

			var entry Entry
			if err := json.Unmarshal([]byte(contents), &entry); err != nil {
				continue
			}

			entries = append(entries, HistoryEntry{
				Entry:      entry,
				CommitHash: c.Hash.String(),
				CommitTime: c.Author.When,
			})
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("audit: walk: %w", err)
	}

	return entries, nil
}
