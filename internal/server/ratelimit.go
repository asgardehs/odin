package server

import (
	"context"
	"fmt"
	"math"
	"net"
	"net/http"
	"sync"
	"time"
)

// RateLimiter implements per-IP token bucket rate limiting.
// Each IP gets a bucket of maxTokens that refills at 1 token per
// refillInterval. When tokens are exhausted requests receive HTTP 429.
type RateLimiter struct {
	mu             sync.Mutex
	buckets        map[string]*tokenBucket
	maxTokens      float64
	refillPerSec   float64 // tokens earned per second
	staleAfter     time.Duration
}

type tokenBucket struct {
	tokens   float64
	lastSeen time.Time
}

// NewRateLimiter creates a RateLimiter.
// maxTokens is the burst capacity; refillInterval is the time to earn 1 token.
func NewRateLimiter(maxTokens int, refillInterval time.Duration) *RateLimiter {
	rl := &RateLimiter{
		buckets:    make(map[string]*tokenBucket),
		maxTokens:  float64(maxTokens),
		staleAfter: 10 * time.Minute,
	}
	if refillInterval > 0 {
		rl.refillPerSec = 1.0 / refillInterval.Seconds()
	}
	return rl
}

// Allow consumes one token for ip. Returns (true, 0) if the request is
// permitted, or (false, retryAfter) with the wait duration if rate-limited.
// Both the allow decision and the retry-after computation are made under a
// single lock to avoid a TOCTOU race between two separate acquisitions.
func (rl *RateLimiter) Allow(ip string) (bool, time.Duration) {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	b, exists := rl.buckets[ip]
	if !exists {
		b = &tokenBucket{tokens: rl.maxTokens, lastSeen: now}
		rl.buckets[ip] = b
	}

	// Refill tokens earned since last request.
	if rl.refillPerSec > 0 {
		elapsed := now.Sub(b.lastSeen).Seconds()
		b.tokens = math.Min(rl.maxTokens, b.tokens+elapsed*rl.refillPerSec)
	}
	b.lastSeen = now

	if b.tokens >= 1.0 {
		b.tokens -= 1.0
		return true, 0
	}

	// Compute retry-after while the lock is still held.
	var retryAfter time.Duration
	if rl.refillPerSec > 0 {
		needed := 1.0 - b.tokens
		retryAfter = time.Duration(needed / rl.refillPerSec * float64(time.Second))
	} else {
		retryAfter = time.Second
	}
	return false, retryAfter
}

// cleanStale removes buckets that haven't been seen recently.
// Call periodically to prevent unbounded memory growth.
func (rl *RateLimiter) cleanStale() {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	cutoff := time.Now().Add(-rl.staleAfter)
	for ip, b := range rl.buckets {
		if b.lastSeen.Before(cutoff) {
			delete(rl.buckets, ip)
		}
	}
}

// startCleanupLoop evicts stale buckets every 15 minutes until ctx is cancelled.
func (rl *RateLimiter) startCleanupLoop(ctx context.Context) {
	ticker := time.NewTicker(15 * time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			rl.cleanStale()
		}
	}
}

// rateLimited wraps a handler, returning 429 when the per-IP bucket is empty.
func (s *Server) rateLimited(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ip := extractClientIP(r.RemoteAddr)
		if allowed, retryAfter := s.limiter.Allow(ip); !allowed {
			w.Header().Set("Retry-After", fmt.Sprintf("%.0f", retryAfter.Seconds()))
			writeError(w, "too many requests — try again later", http.StatusTooManyRequests)
			return
		}
		h(w, r)
	}
}

// extractClientIP strips the port from an addr string like "1.2.3.4:56789".
func extractClientIP(remoteAddr string) string {
	host, _, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		return remoteAddr
	}
	return host
}
