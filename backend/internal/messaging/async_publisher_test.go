package messaging

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

type flakyPublisher struct {
	mu       sync.Mutex
	calls    int
	failures int
}

func (f *flakyPublisher) Publish(ctx context.Context, key string, payload []byte) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	if f.calls <= f.failures {
		return errors.New("temporary error")
	}
	return nil
}

func (f *flakyPublisher) HealthCheck(ctx context.Context) error { return nil }
func (f *flakyPublisher) Close() error                          { return nil }

func TestAsyncPublisherRetriesAndEventuallySucceeds(t *testing.T) {
	base := &flakyPublisher{failures: 2}
	pub := NewAsyncPublisher(base, AsyncPublisherConfig{
		QueueSize:       8,
		PublishTimeout:  100 * time.Millisecond,
		MaxRetries:      3,
		RetryBackoff:    10 * time.Millisecond,
		WorkerCount:     1,
		ShutdownTimeout: time.Second,
	})
	defer pub.Close()

	if err := pub.Publish(context.Background(), "k", []byte("v")); err != nil {
		t.Fatalf("enqueue failed: %v", err)
	}

	deadline := time.Now().Add(1500 * time.Millisecond)
	for time.Now().Before(deadline) {
		base.mu.Lock()
		calls := base.calls
		base.mu.Unlock()
		if calls >= 3 {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}

	base.mu.Lock()
	calls := base.calls
	base.mu.Unlock()
	t.Fatalf("expected at least 3 publish attempts, got %d", calls)
}
