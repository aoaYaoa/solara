package messaging

import (
	"context"
	"errors"
)

var ErrPublisherDisabled = errors.New("publisher is disabled")

// EventPublisher 统一事件发布接口。
type EventPublisher interface {
	Publish(ctx context.Context, key string, payload []byte) error
	HealthCheck(ctx context.Context) error
	Close() error
}
