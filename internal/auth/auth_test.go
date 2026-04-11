package auth

import (
	"os"
	"testing"
	"time"

	"github.com/asgardehs/odin/internal/database"
)

// testDB creates an in-memory database with the auth schema applied.
func testDB(t *testing.T) *database.DB {
	t.Helper()
	db, err := database.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	sql, err := os.ReadFile("../../embed/migrations/001_app_auth.sql")
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	if err := db.Exec(string(sql)); err != nil {
		t.Fatalf("apply migration: %v", err)
	}
	return db
}

// --- UserStore tests ---

func TestUserCount_Empty(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	count, err := store.UserCount()
	if err != nil {
		t.Fatalf("UserCount: %v", err)
	}
	if count != 0 {
		t.Errorf("count = %d, want 0", count)
	}
}

func TestCreateUser(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, err := store.Create(UserInput{
		Username:    "admin",
		DisplayName: "Site Admin",
		Password:    "s3cret!",
		Role:        "admin",
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if id < 1 {
		t.Fatalf("id = %d, want > 0", id)
	}

	count, _ := store.UserCount()
	if count != 1 {
		t.Errorf("count after create = %d, want 1", count)
	}
}

func TestCreateUser_DuplicateUsername(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	store.Create(UserInput{Username: "admin", Password: "pass1", Role: "admin"})
	_, err := store.Create(UserInput{Username: "admin", Password: "pass2", Role: "user"})
	if err == nil {
		t.Fatal("expected error for duplicate username")
	}
}

func TestCreateUser_CaseInsensitive(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	store.Create(UserInput{Username: "Admin", Password: "pass1", Role: "admin"})
	_, err := store.Create(UserInput{Username: "admin", Password: "pass2", Role: "user"})
	if err == nil {
		t.Fatal("expected error for case-insensitive duplicate")
	}
}

func TestCreateUser_MissingFields(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	if _, err := store.Create(UserInput{Password: "pass"}); err == nil {
		t.Error("expected error for missing username")
	}
	if _, err := store.Create(UserInput{Username: "test"}); err == nil {
		t.Error("expected error for missing password")
	}
}

func TestGetUser(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{
		Username:    "jane",
		DisplayName: "Jane Doe",
		Password:    "password",
		Role:        "user",
	})

	u, err := store.Get(id)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if u == nil {
		t.Fatal("user is nil")
	}
	if u.Username != "jane" {
		t.Errorf("username = %q, want jane", u.Username)
	}
	if u.DisplayName != "Jane Doe" {
		t.Errorf("display_name = %q, want Jane Doe", u.DisplayName)
	}
	if u.Role != "user" {
		t.Errorf("role = %q, want user", u.Role)
	}
	if !u.IsActive {
		t.Error("is_active = false, want true")
	}
}

func TestGetUser_NotFound(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	u, err := store.Get(999)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if u != nil {
		t.Error("expected nil for missing user")
	}
}

func TestGetByUsername(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	store.Create(UserInput{Username: "bob", Password: "pass", Role: "user"})

	u, err := store.GetByUsername("bob")
	if err != nil {
		t.Fatalf("GetByUsername: %v", err)
	}
	if u == nil {
		t.Fatal("user is nil")
	}
	if u.Username != "bob" {
		t.Errorf("username = %q, want bob", u.Username)
	}
}

func TestListUsers(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	store.Create(UserInput{Username: "alice", Password: "pass", Role: "admin"})
	store.Create(UserInput{Username: "bob", Password: "pass", Role: "user"})
	store.Create(UserInput{Username: "charlie", Password: "pass", Role: "readonly"})

	users, err := store.List()
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(users) != 3 {
		t.Fatalf("len = %d, want 3", len(users))
	}
	// Should be ordered by username.
	if users[0].Username != "alice" {
		t.Errorf("first user = %q, want alice", users[0].Username)
	}
}

func TestUpdateUser(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{Username: "jane", DisplayName: "Jane", Password: "pass", Role: "user"})

	err := store.Update(id, UserInput{DisplayName: "Jane Smith", Role: "admin"})
	if err != nil {
		t.Fatalf("Update: %v", err)
	}

	u, _ := store.Get(id)
	if u.DisplayName != "Jane Smith" {
		t.Errorf("display_name = %q, want Jane Smith", u.DisplayName)
	}
	if u.Role != "admin" {
		t.Errorf("role = %q, want admin", u.Role)
	}
}

func TestDeactivateUser(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{Username: "temp", Password: "pass", Role: "user"})

	err := store.Deactivate(id)
	if err != nil {
		t.Fatalf("Deactivate: %v", err)
	}

	u, _ := store.Get(id)
	if u.IsActive {
		t.Error("is_active = true, want false")
	}
}

func TestAuthenticate_Success(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	store.Create(UserInput{Username: "admin", Password: "correct-horse", Role: "admin"})

	u, err := store.Authenticate("admin", "correct-horse")
	if err != nil {
		t.Fatalf("Authenticate: %v", err)
	}
	if u == nil {
		t.Fatal("expected user, got nil")
	}
	if u.Username != "admin" {
		t.Errorf("username = %q, want admin", u.Username)
	}
}

func TestAuthenticate_WrongPassword(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	store.Create(UserInput{Username: "admin", Password: "correct-horse", Role: "admin"})

	u, err := store.Authenticate("admin", "wrong-password")
	if err != nil {
		t.Fatalf("Authenticate: %v", err)
	}
	if u != nil {
		t.Error("expected nil user for wrong password")
	}
}

func TestAuthenticate_UnknownUser(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	u, err := store.Authenticate("nobody", "pass")
	if err != nil {
		t.Fatalf("Authenticate: %v", err)
	}
	if u != nil {
		t.Error("expected nil user for unknown username")
	}
}

func TestAuthenticate_InactiveUser(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{Username: "fired", Password: "pass", Role: "user"})
	store.Deactivate(id)

	u, err := store.Authenticate("fired", "pass")
	if err != nil {
		t.Fatalf("Authenticate: %v", err)
	}
	if u != nil {
		t.Error("expected nil for inactive user")
	}
}

func TestSetPassword(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{Username: "admin", Password: "old-pass", Role: "admin"})

	if err := store.SetPassword(id, "new-pass"); err != nil {
		t.Fatalf("SetPassword: %v", err)
	}

	// Old password should fail.
	u, _ := store.Authenticate("admin", "old-pass")
	if u != nil {
		t.Error("old password should not work")
	}

	// New password should work.
	u, _ = store.Authenticate("admin", "new-pass")
	if u == nil {
		t.Error("new password should work")
	}
}

// --- SessionStore tests ---

func TestSessionCreate_Validate(t *testing.T) {
	db := testDB(t)
	users := NewUserStore(db)
	sessions := NewSessionStore(db, 1*time.Hour)

	id, _ := users.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})

	token, err := sessions.Create(id, "127.0.0.1")
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if token == "" {
		t.Fatal("token is empty")
	}
	if len(token) != 64 { // 32 bytes hex
		t.Errorf("token length = %d, want 64", len(token))
	}

	user, err := sessions.Validate(token)
	if err != nil {
		t.Fatalf("Validate: %v", err)
	}
	if user == nil {
		t.Fatal("expected user, got nil")
	}
	if user.Username != "admin" {
		t.Errorf("username = %q, want admin", user.Username)
	}
}

func TestSessionValidate_InvalidToken(t *testing.T) {
	db := testDB(t)
	sessions := NewSessionStore(db, 1*time.Hour)

	user, err := sessions.Validate("nonexistent-token")
	if err != nil {
		t.Fatalf("Validate: %v", err)
	}
	if user != nil {
		t.Error("expected nil for invalid token")
	}
}

func TestSessionValidate_EmptyToken(t *testing.T) {
	db := testDB(t)
	sessions := NewSessionStore(db, 1*time.Hour)

	user, err := sessions.Validate("")
	if err != nil {
		t.Fatalf("Validate: %v", err)
	}
	if user != nil {
		t.Error("expected nil for empty token")
	}
}

func TestSessionDelete(t *testing.T) {
	db := testDB(t)
	users := NewUserStore(db)
	sessions := NewSessionStore(db, 1*time.Hour)

	id, _ := users.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})
	token, _ := sessions.Create(id, "127.0.0.1")

	if err := sessions.Delete(token); err != nil {
		t.Fatalf("Delete: %v", err)
	}

	user, _ := sessions.Validate(token)
	if user != nil {
		t.Error("session should be invalid after delete")
	}
}

func TestSessionDeleteForUser(t *testing.T) {
	db := testDB(t)
	users := NewUserStore(db)
	sessions := NewSessionStore(db, 1*time.Hour)

	id, _ := users.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})
	token1, _ := sessions.Create(id, "10.0.0.1")
	token2, _ := sessions.Create(id, "10.0.0.2")

	if err := sessions.DeleteForUser(id); err != nil {
		t.Fatalf("DeleteForUser: %v", err)
	}

	u1, _ := sessions.Validate(token1)
	u2, _ := sessions.Validate(token2)
	if u1 != nil || u2 != nil {
		t.Error("all sessions should be invalid after DeleteForUser")
	}
}

func TestSessionValidate_InactiveUser(t *testing.T) {
	db := testDB(t)
	users := NewUserStore(db)
	sessions := NewSessionStore(db, 1*time.Hour)

	id, _ := users.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})
	token, _ := sessions.Create(id, "127.0.0.1")

	// Deactivate user — session should become invalid.
	users.Deactivate(id)

	user, _ := sessions.Validate(token)
	if user != nil {
		t.Error("session should be invalid for deactivated user")
	}
}

func TestSessionDurationClamping(t *testing.T) {
	db := testDB(t)

	// Zero duration should default.
	s1 := NewSessionStore(db, 0)
	if s1.duration != DefaultSessionDuration {
		t.Errorf("zero duration: got %v, want %v", s1.duration, DefaultSessionDuration)
	}

	// Over max should clamp.
	s2 := NewSessionStore(db, 48*time.Hour)
	if s2.duration != MaxSessionDuration {
		t.Errorf("over max: got %v, want %v", s2.duration, MaxSessionDuration)
	}

	// Normal value should pass through.
	s3 := NewSessionStore(db, 8*time.Hour)
	if s3.duration != 8*time.Hour {
		t.Errorf("normal: got %v, want %v", s3.duration, 8*time.Hour)
	}
}

// --- Security question tests ---

func testQuestions() SecurityQuestionsInput {
	return SecurityQuestionsInput{
		Questions: [3]SecurityQuestion{
			{Question: "What city were you born in?", Answer: "Springfield"},
			{Question: "What was your first pet's name?", Answer: "Buddy"},
			{Question: "What street did you grow up on?", Answer: "Oak Lane"},
		},
	}
}

func TestSetAndGetSecurityQuestions(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})

	// Before setting, user should not have security questions.
	u, _ := store.Get(id)
	if u.HasSecurityQuestions {
		t.Error("HasSecurityQuestions should be false before setting")
	}

	// Set the questions.
	if err := store.SetSecurityQuestions(id, testQuestions()); err != nil {
		t.Fatalf("SetSecurityQuestions: %v", err)
	}

	// After setting, user should have security questions.
	u, _ = store.Get(id)
	if !u.HasSecurityQuestions {
		t.Error("HasSecurityQuestions should be true after setting")
	}

	// Get questions — should return questions only, not answers.
	questions, err := store.GetSecurityQuestions("admin")
	if err != nil {
		t.Fatalf("GetSecurityQuestions: %v", err)
	}
	if questions == nil {
		t.Fatal("questions should not be nil")
	}
	if len(questions) != 3 {
		t.Fatalf("len = %d, want 3", len(questions))
	}
	if questions[0] != "What city were you born in?" {
		t.Errorf("q1 = %q", questions[0])
	}
	if questions[1] != "What was your first pet's name?" {
		t.Errorf("q2 = %q", questions[1])
	}
	if questions[2] != "What street did you grow up on?" {
		t.Errorf("q3 = %q", questions[2])
	}
}

func TestGetSecurityQuestions_NotSet(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	store.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})

	questions, err := store.GetSecurityQuestions("admin")
	if err != nil {
		t.Fatalf("GetSecurityQuestions: %v", err)
	}
	if questions != nil {
		t.Error("expected nil when no questions set")
	}
}

func TestResetPassword_Success(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{Username: "admin", Password: "old-pass", Role: "admin"})
	store.SetSecurityQuestions(id, testQuestions())

	// Reset with correct answers (case-sensitive).
	err := store.ResetPassword("admin",
		[3]string{"Springfield", "Buddy", "Oak Lane"},
		"new-pass",
	)
	if err != nil {
		t.Fatalf("ResetPassword: %v", err)
	}

	// Old password should fail.
	u, _ := store.Authenticate("admin", "old-pass")
	if u != nil {
		t.Error("old password should not work after reset")
	}

	// New password should work.
	u, _ = store.Authenticate("admin", "new-pass")
	if u == nil {
		t.Error("new password should work after reset")
	}
}

func TestResetPassword_CaseSensitive(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})
	store.SetSecurityQuestions(id, testQuestions())

	// Wrong case — should fail. Answers are case-sensitive.
	err := store.ResetPassword("admin",
		[3]string{"springfield", "buddy", "oak lane"}, // lowercase
		"new-pass",
	)
	if err == nil {
		t.Fatal("expected error for case-mismatched answers")
	}
}

func TestResetPassword_WrongAnswer(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})
	store.SetSecurityQuestions(id, testQuestions())

	// First two correct, third wrong.
	err := store.ResetPassword("admin",
		[3]string{"Springfield", "Buddy", "Wrong Street"},
		"new-pass",
	)
	if err == nil {
		t.Fatal("expected error for wrong answer")
	}

	// Original password should still work (reset was rejected).
	u, _ := store.Authenticate("admin", "pass")
	if u == nil {
		t.Error("original password should still work after failed reset")
	}
}

func TestResetPassword_NoQuestionsSet(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	store.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})

	err := store.ResetPassword("admin",
		[3]string{"a", "b", "c"},
		"new-pass",
	)
	if err == nil {
		t.Fatal("expected error when no security questions configured")
	}
}

func TestResetPassword_UnknownUser(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	err := store.ResetPassword("nobody",
		[3]string{"a", "b", "c"},
		"new-pass",
	)
	if err == nil {
		t.Fatal("expected error for unknown user")
	}
}

func TestSetSecurityQuestions_MissingFields(t *testing.T) {
	db := testDB(t)
	store := NewUserStore(db)

	id, _ := store.Create(UserInput{Username: "admin", Password: "pass", Role: "admin"})

	// Missing question text.
	err := store.SetSecurityQuestions(id, SecurityQuestionsInput{
		Questions: [3]SecurityQuestion{
			{Question: "", Answer: "answer"},
			{Question: "Q2?", Answer: "answer"},
			{Question: "Q3?", Answer: "answer"},
		},
	})
	if err == nil {
		t.Error("expected error for missing question text")
	}

	// Missing answer.
	err = store.SetSecurityQuestions(id, SecurityQuestionsInput{
		Questions: [3]SecurityQuestion{
			{Question: "Q1?", Answer: "answer"},
			{Question: "Q2?", Answer: ""},
			{Question: "Q3?", Answer: "answer"},
		},
	})
	if err == nil {
		t.Error("expected error for missing answer")
	}
}

// --- RecoveryStore tests ---

func TestRecoveryStore_GenerateAndVerify(t *testing.T) {
	db := testDB(t)
	store := NewRecoveryStore(db)

	// Initially no key.
	has, err := store.HasRecoveryKey()
	if err != nil {
		t.Fatalf("HasRecoveryKey: %v", err)
	}
	if has {
		t.Error("should not have recovery key initially")
	}

	// Generate.
	key, err := store.GenerateAndStore()
	if err != nil {
		t.Fatalf("GenerateAndStore: %v", err)
	}
	if key == "" {
		t.Fatal("key is empty")
	}

	// Should be formatted as XXXX-XXXX-...-XXXX (8 groups of 4).
	if len(key) != 39 { // 32 chars + 7 dashes
		t.Errorf("key length = %d, want 39; key = %q", len(key), key)
	}

	// Now has key.
	has, _ = store.HasRecoveryKey()
	if !has {
		t.Error("should have recovery key after generate")
	}

	// Verify correct key.
	valid, err := store.Verify(key)
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if !valid {
		t.Error("correct key should validate")
	}
}

func TestRecoveryStore_WrongKey(t *testing.T) {
	db := testDB(t)
	store := NewRecoveryStore(db)

	store.GenerateAndStore()

	valid, err := store.Verify("wrong-key-entirely")
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if valid {
		t.Error("wrong key should not validate")
	}
}

func TestRecoveryStore_EmptyKey(t *testing.T) {
	db := testDB(t)
	store := NewRecoveryStore(db)

	valid, _ := store.Verify("")
	if valid {
		t.Error("empty key should not validate")
	}
}

func TestRecoveryStore_NoKeyStored(t *testing.T) {
	db := testDB(t)
	store := NewRecoveryStore(db)

	valid, _ := store.Verify("some-key")
	if valid {
		t.Error("should not validate when no key is stored")
	}
}

func TestRecoveryStore_Regenerate(t *testing.T) {
	db := testDB(t)
	store := NewRecoveryStore(db)

	key1, _ := store.GenerateAndStore()
	key2, _ := store.GenerateAndStore()

	if key1 == key2 {
		t.Error("regenerated key should be different")
	}

	// Old key should no longer work.
	valid, _ := store.Verify(key1)
	if valid {
		t.Error("old key should not validate after regeneration")
	}

	// New key should work.
	valid, _ = store.Verify(key2)
	if !valid {
		t.Error("new key should validate")
	}
}
