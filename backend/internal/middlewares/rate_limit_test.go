package middlewares

import (
	"testing"
	"time"

	"golang.org/x/time/rate"
)

func TestIPRateLimiterCleanupRemovesIdleEntries(t *testing.T) {
	now := time.Now()
	clock := func() time.Time { return now }

	limiter := NewIPRateLimiterWithClock(rate.Limit(10), 20, clock)
	limiter.entryTTL = 2 * time.Minute

	_ = limiter.GetLimiter("10.0.0.1")
	_ = limiter.GetLimiter("10.0.0.2")

	now = now.Add(3 * time.Minute)
	removed := limiter.cleanupExpired(now)
	if removed != 2 {
		t.Fatalf("expected 2 removed entries, got %d", removed)
	}
	if got := len(limiter.limiters); got != 0 {
		t.Fatalf("expected limiter map empty, got %d", got)
	}
}
