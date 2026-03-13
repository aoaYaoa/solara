package middlewares

import (
	"backend/pkg/utils/logger"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

const (
	defaultLimiterEntryTTL      = 30 * time.Minute
	defaultLimiterCleanupWindow = 5 * time.Minute
)

type limiterEntry struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// IPRateLimiter IP 限流器
type IPRateLimiter struct {
	limiters map[string]*limiterEntry
	mu       sync.Mutex
	r        rate.Limit
	b        int

	now             func() time.Time
	entryTTL        time.Duration
	cleanupInterval time.Duration
	lastCleanupAt   time.Time
}

// NewIPRateLimiter 创建 IP 限流器
func NewIPRateLimiter(r rate.Limit, b int) *IPRateLimiter {
	return NewIPRateLimiterWithClock(r, b, time.Now)
}

// NewIPRateLimiterWithClock 允许测试注入时钟。
func NewIPRateLimiterWithClock(r rate.Limit, b int, now func() time.Time) *IPRateLimiter {
	if now == nil {
		now = time.Now
	}
	return &IPRateLimiter{
		limiters:        make(map[string]*limiterEntry),
		r:               r,
		b:               b,
		now:             now,
		entryTTL:        defaultLimiterEntryTTL,
		cleanupInterval: defaultLimiterCleanupWindow,
		lastCleanupAt:   now(),
	}
}

// GetLimiter 获取指定 IP 的限流器
func (i *IPRateLimiter) GetLimiter(ip string) *rate.Limiter {
	i.mu.Lock()
	defer i.mu.Unlock()

	now := i.now()
	if now.Sub(i.lastCleanupAt) >= i.cleanupInterval {
		removed := i.cleanupExpired(now)
		if removed > 0 {
			logger.Debugf("[RateLimit] 已清理过期 IP 限流器: %d", removed)
		}
		i.lastCleanupAt = now
	}

	entry, exists := i.limiters[ip]
	if !exists {
		entry = &limiterEntry{
			limiter:  rate.NewLimiter(i.r, i.b),
			lastSeen: now,
		}
		i.limiters[ip] = entry
	} else {
		entry.lastSeen = now
	}

	return entry.limiter
}

// RateLimit 请求限流中间件
func RateLimit(defaultRate float64, defaultBurst int) gin.HandlerFunc {
	limiter := NewIPRateLimiter(rate.Limit(defaultRate), defaultBurst)

	return func(c *gin.Context) {
		ip := c.ClientIP()
		ipLimiter := limiter.GetLimiter(ip)

		if !ipLimiter.Allow() {
			logger.Warnf("[RateLimit] IP: %s 超过速率限制", ip)
			c.JSON(429, gin.H{
				"success": false,
				"error":   "请求过于频繁，请稍后再试",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// CleanupExpiredLimiters 定期清理过期限流器。
func (i *IPRateLimiter) CleanupExpiredLimiters(interval time.Duration) {
	if interval <= 0 {
		interval = i.cleanupInterval
	}
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for range ticker.C {
		i.mu.Lock()
		removed := i.cleanupExpired(i.now())
		i.lastCleanupAt = i.now()
		i.mu.Unlock()

		if removed > 0 {
			logger.Debugf("[RateLimit] 定时清理过期 IP 限流器: %d", removed)
		}
	}
}

func (i *IPRateLimiter) cleanupExpired(now time.Time) int {
	removed := 0
	for ip, entry := range i.limiters {
		if now.Sub(entry.lastSeen) > i.entryTTL {
			delete(i.limiters, ip)
			removed++
		}
	}
	return removed
}
