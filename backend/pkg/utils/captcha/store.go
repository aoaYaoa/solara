package captcha

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
)

// CaptchaStore 验证码存储接口
type CaptchaStore interface {
	Set(id, code string, expiration time.Duration) error
	Get(id string) (string, bool)
	Delete(id string)
}

// memoryStore 内存存储实现
type memoryStore struct {
	data map[string]*captchaItem
	mu   sync.RWMutex
}

type captchaItem struct {
	code      string
	expiresAt time.Time
}

// NewMemoryStore 创建内存存储实例
func NewMemoryStore() CaptchaStore {
	store := &memoryStore{
		data: make(map[string]*captchaItem),
	}
	// 启动清理过期数据的 goroutine
	go store.cleanExpired()
	return store
}

// Set 存储验证码
func (s *memoryStore) Set(id, code string, expiration time.Duration) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.data[id] = &captchaItem{
		code:      code,
		expiresAt: time.Now().Add(expiration),
	}
	return nil
}

// Get 获取验证码
func (s *memoryStore) Get(id string) (string, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	item, exists := s.data[id]
	if !exists {
		return "", false
	}

	// 检查是否过期
	if time.Now().After(item.expiresAt) {
		return "", false
	}

	return item.code, true
}

// Delete 删除验证码
func (s *memoryStore) Delete(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.data, id)
}

// cleanExpired 定期清理过期数据
func (s *memoryStore) cleanExpired() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		s.mu.Lock()
		now := time.Now()
		for id, item := range s.data {
			if now.After(item.expiresAt) {
				delete(s.data, id)
			}
		}
		s.mu.Unlock()
	}
}

// 全局验证码存储实例
var globalStore CaptchaStore

// StoreType 返回当前验证码存储类型：redis / memory / uninitialized。
func StoreType() string {
	switch globalStore.(type) {
	case *redisStore:
		return "redis"
	case *memoryStore:
		return "memory"
	default:
		return "uninitialized"
	}
}

// CheckStoreHealth 检查当前验证码存储健康状态。
func CheckStoreHealth(ctx context.Context) error {
	if globalStore == nil {
		return errors.New("captcha store is not initialized")
	}

	if checker, ok := globalStore.(interface {
		HealthCheck(context.Context) error
	}); ok {
		return checker.HealthCheck(ctx)
	}

	return nil
}

// InitStore 初始化全局存储
func InitStore() {
	globalStore = NewMemoryStore()
}

// GenerateCaptcha 生成验证码并存储
func GenerateCaptcha(expiration time.Duration) (id, code string) {
	if globalStore == nil {
		InitStore()
	}

	id = uuid.New().String()
	code = GenerateCode()
	globalStore.Set(id, code, expiration)
	return id, code
}

// VerifyCaptcha 验证验证码
func VerifyCaptcha(id, inputCode string) bool {
	if globalStore == nil {
		return false
	}

	code, exists := globalStore.Get(id)
	if !exists {
		return false
	}

	// 验证后删除（一次性使用）
	globalStore.Delete(id)

	return code == inputCode
}
