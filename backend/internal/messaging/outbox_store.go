package messaging

import (
	"context"
	"time"
)

const (
	OutboxStatusPending = "pending"
	OutboxStatusSent    = "sent"
	OutboxStatusFailed  = "failed"
)

type OutboxEvent struct {
	ID          string
	Key         string
	Payload     []byte
	Status      string
	Attempts    int
	NextRetryAt time.Time
	LastError   string
	CreatedAt   time.Time
	UpdatedAt   time.Time
	SentAt      *time.Time
}

type OutboxStore interface {
	Enqueue(ctx context.Context, event OutboxEvent) (OutboxEvent, error)
	ListPending(ctx context.Context, now time.Time, limit int) ([]OutboxEvent, error)
	MarkSent(ctx context.Context, id string) error
	MarkRetry(ctx context.Context, id string, nextRetryAt time.Time, lastErr string) error
	MarkFailed(ctx context.Context, id string, lastErr string) error
	CleanupSentBefore(ctx context.Context, before time.Time, limit int) (int64, error)
	HealthCheck(ctx context.Context) error
}
