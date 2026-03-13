package captcha

import (
	"testing"
	"time"
)

func TestRedisStore_SetGetDelete(t *testing.T) {
	cfg := StoreConfig{
		Addr:      "127.0.0.1:6379",
		KeyPrefix: "test:captcha:",
	}

	store, err := NewRedisStore(cfg)
	if err != nil {
		t.Skipf("redis not available on 127.0.0.1:6379: %v", err)
	}

	if err := store.Set("id-1", "ABCD", 2*time.Minute); err != nil {
		t.Fatalf("set failed: %v", err)
	}

	code, ok := store.Get("id-1")
	if !ok {
		t.Fatalf("expected key to exist")
	}
	if code != "ABCD" {
		t.Fatalf("unexpected code: got %s", code)
	}

	store.Delete("id-1")
	_, ok = store.Get("id-1")
	if ok {
		t.Fatalf("expected key to be deleted")
	}
}

func TestInitStoreWithConfig_FallbackToMemoryWhenRedisUnavailable(t *testing.T) {
	globalStore = nil
	cfg := StoreConfig{Addr: "127.0.0.1:1", KeyPrefix: "captcha:"}
	InitStoreWithConfig(cfg)

	if globalStore == nil {
		t.Fatalf("globalStore should be initialized")
	}

	id, code := GenerateCaptcha(time.Minute)
	if id == "" || code == "" {
		t.Fatalf("captcha generation failed")
	}
}
