package audit

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/asgardehs/odin/internal/auth"
)

// mockAuth is a test authenticator that accepts any credentials.
type mockAuth struct{ user string }

func (m *mockAuth) Verify(_, _ string) error { return nil }
func (m *mockAuth) CurrentUser() string       { return m.user }

// failAuth rejects all credentials.
type failAuth struct{ user string }

func (f *failAuth) Verify(_, _ string) error { return auth.ErrInvalidCredentials }
func (f *failAuth) CurrentUser() string       { return f.user }

func TestRecordAndHistory(t *testing.T) {
	dir := t.TempDir()
	store, err := NewStore(dir, &mockAuth{user: "testuser"})
	if err != nil {
		t.Fatalf("NewStore: %v", err)
	}

	entry := Entry{
		Action:   ActionCreate,
		Module:   "incidents",
		EntityID: "INC-001",
		Summary:  "created test incident",
	}
	if err := store.Record(entry); err != nil {
		t.Fatalf("Record: %v", err)
	}

	// Verify the JSON file was written.
	files, _ := filepath.Glob(filepath.Join(dir, "incidents", "*.json"))
	if len(files) != 1 {
		t.Fatalf("expected 1 audit file, got %d", len(files))
	}

	// Verify JSON content.
	data, _ := os.ReadFile(files[0])
	var got Entry
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.Action != ActionCreate {
		t.Errorf("action = %q, want %q", got.Action, ActionCreate)
	}
	if got.EntityID != "INC-001" {
		t.Errorf("entity_id = %q, want %q", got.EntityID, "INC-001")
	}
	if got.User != "testuser" {
		t.Errorf("user = %q, want %q", got.User, "testuser")
	}

	// Query history with valid credentials.
	creds := auth.Credentials{Username: "testuser", Password: "pass"}
	entries, err := store.History("incidents", "INC-001", creds)
	if err != nil {
		t.Fatalf("History: %v", err)
	}
	if len(entries) != 1 {
		t.Fatalf("expected 1 history entry, got %d", len(entries))
	}
	if entries[0].CommitHash == "" {
		t.Error("commit hash should not be empty")
	}
}

func TestHistoryRejectsInvalidCredentials(t *testing.T) {
	dir := t.TempDir()
	store, err := NewStore(dir, &failAuth{user: "testuser"})
	if err != nil {
		t.Fatalf("NewStore: %v", err)
	}

	// Record something first (Record doesn't require auth).
	if err := store.Record(Entry{
		Action:   ActionCreate,
		Module:   "incidents",
		EntityID: "INC-002",
		Summary:  "test",
	}); err != nil {
		t.Fatalf("Record: %v", err)
	}

	// History should fail with bad auth.
	creds := auth.Credentials{Username: "bad", Password: "bad"}
	_, err = store.History("incidents", "INC-002", creds)
	if err == nil {
		t.Fatal("expected error for invalid credentials")
	}
}

func TestExportDateRange(t *testing.T) {
	dir := t.TempDir()
	store, err := NewStore(dir, &mockAuth{user: "testuser"})
	if err != nil {
		t.Fatalf("NewStore: %v", err)
	}

	now := time.Now().UTC()
	if err := store.Record(Entry{
		Timestamp: now,
		Action:    ActionCreate,
		Module:    "chemicals",
		EntityID:  "CHEM-001",
		Summary:   "added chemical",
	}); err != nil {
		t.Fatalf("Record: %v", err)
	}

	creds := auth.Credentials{Username: "testuser", Password: "pass"}

	// Range that includes the entry.
	entries, err := store.Export(now.Add(-time.Hour), now.Add(time.Hour), creds)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	if len(entries) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(entries))
	}

	// Range that excludes the entry.
	entries, err = store.Export(now.Add(time.Hour), now.Add(2*time.Hour), creds)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	if len(entries) != 0 {
		t.Fatalf("expected 0 entries, got %d", len(entries))
	}
}

func TestMultipleRecords(t *testing.T) {
	dir := t.TempDir()
	store, err := NewStore(dir, &mockAuth{user: "testuser"})
	if err != nil {
		t.Fatalf("NewStore: %v", err)
	}

	for i, action := range []Action{ActionCreate, ActionUpdate, ActionDelete} {
		if err := store.Record(Entry{
			Timestamp: time.Now().UTC().Add(time.Duration(i) * time.Second),
			Action:    action,
			Module:    "incidents",
			EntityID:  "INC-100",
			Summary:   string(action) + " incident",
		}); err != nil {
			t.Fatalf("Record %d: %v", i, err)
		}
	}

	creds := auth.Credentials{Username: "testuser", Password: "pass"}
	entries, err := store.History("incidents", "INC-100", creds)
	if err != nil {
		t.Fatalf("History: %v", err)
	}
	if len(entries) != 3 {
		t.Fatalf("expected 3 history entries, got %d", len(entries))
	}
}
