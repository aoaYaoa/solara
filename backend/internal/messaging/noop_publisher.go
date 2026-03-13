package messaging

import "context"

type noopPublisher struct{}

// NewNoopPublisher 返回一个不执行任何动作的发布器。
func NewNoopPublisher() EventPublisher {
	return &noopPublisher{}
}

func (n *noopPublisher) Publish(ctx context.Context, key string, payload []byte) error {
	return nil
}

func (n *noopPublisher) HealthCheck(ctx context.Context) error {
	return ErrPublisherDisabled
}

func (n *noopPublisher) Close() error {
	return nil
}
