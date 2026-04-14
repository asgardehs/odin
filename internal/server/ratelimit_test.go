package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// newTestLimiter creates a RateLimiter with a tiny refill interval for fast tests.
// maxTokens: bucket capacity; refillInterval: time to earn 1 token back.
func newTestLimiter(maxTokens int, refillInterval time.Duration) *RateLimiter {
	return NewRateLimiter(maxTokens, refillInterval)
}

// TestRateLimiter_Allow5Block6 verifies that exactly maxTokens requests
// are allowed before the next one is blocked.
func TestRateLimiter_Allow5Block6(t *testing.T) {
	rl := newTestLimiter(5, time.Hour) // large refill interval — no refill during test
	ip := "192.0.2.1"

	for i := range 5 {
		if !rl.Allow(ip) {
			t.Errorf("request %d should be allowed (have tokens), but was blocked", i+1)
		}
	}
	if rl.Allow(ip) {
		t.Error("request 6 should be blocked (no tokens), but was allowed")
	}
}

// TestRateLimiter_RefillAfterDelay verifies that tokens refill after time passes.
func TestRateLimiter_RefillAfterDelay(t *testing.T) {
	// 2 tokens, 1 token per 20ms — exhaust, wait, try again.
	rl := newTestLimiter(2, 20*time.Millisecond)
	ip := "192.0.2.2"

	// Exhaust all tokens.
	rl.Allow(ip)
	rl.Allow(ip)
	if rl.Allow(ip) {
		t.Fatal("should be blocked after exhausting tokens")
	}

	// Wait for at least 1 token to refill.
	time.Sleep(30 * time.Millisecond)

	if !rl.Allow(ip) {
		t.Error("should be allowed after token refill")
	}
}

// TestRateLimiter_PerIP verifies that different IPs have independent buckets.
func TestRateLimiter_PerIP(t *testing.T) {
	rl := newTestLimiter(1, time.Hour) // 1 token per IP
	ipA := "192.0.2.10"
	ipB := "192.0.2.20"

	// Exhaust ipA's bucket.
	if !rl.Allow(ipA) {
		t.Fatal("ipA first request should be allowed")
	}
	if rl.Allow(ipA) {
		t.Error("ipA second request should be blocked")
	}

	// ipB should still be unaffected.
	if !rl.Allow(ipB) {
		t.Error("ipB should be allowed (independent bucket)")
	}
}

// TestRateLimiter_RetryAfterHeader verifies the HTTP wrapper returns a
// Retry-After header when a request is rate-limited.
func TestRateLimiter_RetryAfterHeader(t *testing.T) {
	srv := newTestServer(t)
	// Replace the limiter with a test one — 0 tokens (pre-exhausted).
	srv.limiter = newTestLimiter(0, time.Hour)

	req := httptest.NewRequest("POST", "/api/auth/login", nil)
	w := httptest.NewRecorder()
	srv.mux.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("status = %d, want 429", w.Code)
	}
	if w.Header().Get("Retry-After") == "" {
		t.Error("Retry-After header missing on 429 response")
	}
}
