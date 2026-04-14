package auth

import (
	"context"
	"testing"
	"time"
)

// TestCleanupLoop_CleansExpiredSessions verifies that StartCleanupLoop
// removes expired sessions when the ticker fires.
// Important: we cancel the context and wait for the goroutine to exit
// BEFORE querying the database, to avoid concurrent access on the single
// WASM SQLite connection.
func TestCleanupLoop_CleansExpiredSessions(t *testing.T) {
	db := testDB(t)
	store := NewSessionStore(db, time.Minute)

	userStore := NewUserStore(db)
	uid, err := userStore.Create(UserInput{
		Username: "cleanup-test", DisplayName: "Cleanup", Password: "pass", Role: "user",
	})
	if err != nil {
		t.Fatalf("create user: %v", err)
	}

	// Insert a session that is already expired.
	expiredAt := time.Now().UTC().Add(-1 * time.Hour).Format(time.DateTime)
	if err := db.ExecParams(
		`INSERT INTO app_sessions (token, user_id, expires_at, ip_address) VALUES (?, ?, ?, ?)`,
		"expired-token-cleanup-test", uid, expiredAt, "127.0.0.1",
	); err != nil {
		t.Fatalf("insert expired session: %v", err)
	}

	// Start the cleanup loop with a very short interval, then cancel it.
	// We wait for the goroutine to fully exit before querying the DB to
	// avoid concurrent access on the single WASM SQLite connection.
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		store.StartCleanupLoop(ctx, 10*time.Millisecond)
		close(done)
	}()

	// Let at least one tick fire.
	time.Sleep(50 * time.Millisecond)
	cancel()

	// Wait for the goroutine to stop before touching the DB.
	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("StartCleanupLoop did not exit after context cancellation")
	}

	// Expired session should be gone.
	row, err := db.QueryRow(`SELECT token FROM app_sessions WHERE token = ?`, "expired-token-cleanup-test")
	if err != nil {
		t.Fatalf("query after cleanup: %v", err)
	}
	if row != nil {
		t.Error("expected expired session to be deleted, but it still exists")
	}
}

// TestCleanupLoop_LeavesActiveSessions verifies that active sessions
// are not removed by the cleanup loop.
func TestCleanupLoop_LeavesActiveSessions(t *testing.T) {
	db := testDB(t)
	store := NewSessionStore(db, time.Hour)

	userStore := NewUserStore(db)
	uid, err := userStore.Create(UserInput{
		Username: "active-session-user", DisplayName: "Active", Password: "pass", Role: "user",
	})
	if err != nil {
		t.Fatalf("create user: %v", err)
	}

	token, err := store.Create(uid, "127.0.0.1")
	if err != nil {
		t.Fatalf("create session: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		store.StartCleanupLoop(ctx, 10*time.Millisecond)
		close(done)
	}()

	time.Sleep(50 * time.Millisecond)
	cancel()

	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("StartCleanupLoop did not exit after context cancellation")
	}

	// Active session must still exist.
	user, err := store.Validate(token)
	if err != nil {
		t.Fatalf("validate after cleanup: %v", err)
	}
	if user == nil {
		t.Error("active session was incorrectly cleaned up")
	}
}
