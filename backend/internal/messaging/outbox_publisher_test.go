package messaging

import (
	"backend/pkg/utils/logger"
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

type memoryOutboxStore struct {
	mu      sync.Mutex
	events  []OutboxEvent
	cleaned int64
}

func (s *memoryOutboxStore) Enqueue(ctx context.Context, event OutboxEvent) (OutboxEvent, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	event.ID = "id-1"
	event.Status = OutboxStatusPending
	s.events = append(s.events, event)
	return event, nil
}

func (s *memoryOutboxStore) ListPending(ctx context.Context, now time.Time, limit int) ([]OutboxEvent, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]OutboxEvent, 0, len(s.events))
	for _, ev := range s.events {
		if ev.Status == OutboxStatusPending {
			out = append(out, ev)
		}
	}
	return out, nil
}

func (s *memoryOutboxStore) MarkSent(ctx context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.events {
		if s.events[i].ID == id {
			sentAt := time.Now().UTC()
			s.events[i].Status = OutboxStatusSent
			s.events[i].SentAt = &sentAt
		}
	}
	return nil
}

func (s *memoryOutboxStore) MarkRetry(ctx context.Context, id string, nextRetryAt time.Time, lastErr string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.events {
		if s.events[i].ID == id {
			s.events[i].Attempts++
			s.events[i].NextRetryAt = nextRetryAt
			s.events[i].LastError = lastErr
			s.events[i].Status = OutboxStatusPending
		}
	}
	return nil
}

func (s *memoryOutboxStore) MarkFailed(ctx context.Context, id string, lastErr string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.events {
		if s.events[i].ID == id {
			s.events[i].Attempts++
			s.events[i].LastError = lastErr
			s.events[i].Status = OutboxStatusFailed
		}
	}
	return nil
}

func (s *memoryOutboxStore) CleanupSentBefore(ctx context.Context, before time.Time, limit int) (int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if limit <= 0 {
		limit = 100
	}
	filtered := make([]OutboxEvent, 0, len(s.events))
	var removed int64
	for _, ev := range s.events {
		if removed < int64(limit) && ev.Status == OutboxStatusSent && ev.SentAt != nil && ev.SentAt.Before(before) {
			removed++
			continue
		}
		filtered = append(filtered, ev)
	}
	s.events = filtered
	s.cleaned += removed
	return removed, nil
}

func (s *memoryOutboxStore) HealthCheck(ctx context.Context) error {
	return nil
}

type flakyOutboxTarget struct {
	mu       sync.Mutex
	calls    int
	failures int
}

func (f *flakyOutboxTarget) Publish(ctx context.Context, key string, payload []byte) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	if f.calls <= f.failures {
		return errors.New("temporary publish failure")
	}
	return nil
}

func (f *flakyOutboxTarget) HealthCheck(ctx context.Context) error { return nil }
func (f *flakyOutboxTarget) Close() error                          { return nil }

func TestOutboxPublisher_PersistThenRetryUntilSuccess(t *testing.T) {
	logger.Init()

	store := &memoryOutboxStore{}
	target := &flakyOutboxTarget{failures: 2}

	pub := NewOutboxPublisher(store, target, OutboxPublisherConfig{
		PollInterval:        20 * time.Millisecond,
		BatchSize:           10,
		PublishTimeout:      200 * time.Millisecond,
		MaxDeliveryAttempts: 4,
		RetryBackoff:        10 * time.Millisecond,
		CleanupInterval:     time.Hour,
		SentRetention:       time.Hour,
		ShutdownTimeout:     time.Second,
	})
	defer pub.Close()

	if err := pub.Publish(context.Background(), "user-1", []byte("payload")); err != nil {
		t.Fatalf("expected enqueue success, got error: %v", err)
	}

	deadline := time.Now().Add(1500 * time.Millisecond)
	for time.Now().Before(deadline) {
		target.mu.Lock()
		calls := target.calls
		target.mu.Unlock()
		if calls >= 3 {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}

	target.mu.Lock()
	calls := target.calls
	target.mu.Unlock()
	t.Fatalf("expected at least 3 publish attempts, got %d", calls)
}

func TestOutboxPublisher_MarkFailedAfterMaxAttempts(t *testing.T) {
	logger.Init()

	store := &memoryOutboxStore{}
	target := &flakyOutboxTarget{failures: 100}

	pub := NewOutboxPublisher(store, target, OutboxPublisherConfig{
		PollInterval:        20 * time.Millisecond,
		BatchSize:           10,
		PublishTimeout:      200 * time.Millisecond,
		MaxDeliveryAttempts: 2,
		RetryBackoff:        10 * time.Millisecond,
		CleanupInterval:     time.Hour,
		SentRetention:       time.Hour,
		ShutdownTimeout:     time.Second,
	})
	defer pub.Close()

	if err := pub.Publish(context.Background(), "user-2", []byte("payload")); err != nil {
		t.Fatalf("expected enqueue success, got error: %v", err)
	}

	deadline := time.Now().Add(1500 * time.Millisecond)
	for time.Now().Before(deadline) {
		store.mu.Lock()
		if len(store.events) > 0 && store.events[0].Status == OutboxStatusFailed {
			store.mu.Unlock()
			return
		}
		store.mu.Unlock()
		time.Sleep(20 * time.Millisecond)
	}

	store.mu.Lock()
	defer store.mu.Unlock()
	if len(store.events) == 0 || store.events[0].Status != OutboxStatusFailed {
		t.Fatalf("expected event status failed, got %+v", store.events)
	}
}

func TestOutboxPublisher_CleanupSentEvents(t *testing.T) {
	logger.Init()

	store := &memoryOutboxStore{}
	target := &flakyOutboxTarget{failures: 0}

	pub := NewOutboxPublisher(store, target, OutboxPublisherConfig{
		PollInterval:        20 * time.Millisecond,
		BatchSize:           10,
		PublishTimeout:      200 * time.Millisecond,
		MaxDeliveryAttempts: 2,
		RetryBackoff:        10 * time.Millisecond,
		CleanupInterval:     20 * time.Millisecond,
		SentRetention:       time.Nanosecond,
		CleanupBatchSize:    100,
		ShutdownTimeout:     time.Second,
	})
	defer pub.Close()

	if err := pub.Publish(context.Background(), "user-3", []byte("payload")); err != nil {
		t.Fatalf("expected enqueue success, got error: %v", err)
	}

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		store.mu.Lock()
		cleaned := store.cleaned
		store.mu.Unlock()
		if cleaned > 0 {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}

	store.mu.Lock()
	defer store.mu.Unlock()
	t.Fatalf("expected sent events to be cleaned, cleaned=%d", store.cleaned)
}
