package messaging

import (
	"backend/pkg/utils/logger"
	"context"
	"errors"
	"sync"
	"time"
)

type OutboxPublisherConfig struct {
	PollInterval        time.Duration
	BatchSize           int
	PublishTimeout      time.Duration
	MaxRetries          int
	MaxDeliveryAttempts int
	RetryBackoff        time.Duration
	MaxRetryBackoff     time.Duration
	CleanupInterval     time.Duration
	SentRetention       time.Duration
	CleanupBatchSize    int
	ShutdownTimeout     time.Duration
}

type outboxPublisher struct {
	store  OutboxStore
	target EventPublisher
	cfg    OutboxPublisherConfig

	ticker  *time.Ticker
	cleaner *time.Ticker
	signal  chan struct{}
	stopCh  chan struct{}

	mu        sync.RWMutex
	isClosed  bool
	closeOnce sync.Once
	wg        sync.WaitGroup
}

func NewOutboxPublisher(store OutboxStore, target EventPublisher, cfg OutboxPublisherConfig) EventPublisher {
	if store == nil {
		return target
	}
	if target == nil {
		target = NewNoopPublisher()
	}

	cfg = withDefaultOutboxConfig(cfg)
	p := &outboxPublisher{
		store:   store,
		target:  target,
		cfg:     cfg,
		ticker:  time.NewTicker(cfg.PollInterval),
		cleaner: time.NewTicker(cfg.CleanupInterval),
		signal:  make(chan struct{}, 1),
		stopCh:  make(chan struct{}),
	}

	p.wg.Add(1)
	go p.loop()

	return p
}

func (p *outboxPublisher) Publish(ctx context.Context, key string, payload []byte) error {
	if ctx == nil {
		ctx = context.Background()
	}

	p.mu.RLock()
	closed := p.isClosed
	p.mu.RUnlock()
	if closed {
		return ErrPublisherClosed
	}

	event := OutboxEvent{
		Key:         key,
		Payload:     append([]byte(nil), payload...),
		Attempts:    0,
		NextRetryAt: time.Now().UTC(),
	}

	if _, err := p.store.Enqueue(ctx, event); err != nil {
		return err
	}

	select {
	case p.signal <- struct{}{}:
	default:
	}
	return nil
}

func (p *outboxPublisher) HealthCheck(ctx context.Context) error {
	if ctx == nil {
		ctx = context.Background()
	}
	if err := p.store.HealthCheck(ctx); err != nil {
		return err
	}
	if err := p.target.HealthCheck(ctx); err != nil {
		return err
	}
	return nil
}

func (p *outboxPublisher) Close() error {
	var closeErr error
	p.closeOnce.Do(func() {
		p.mu.Lock()
		p.isClosed = true
		close(p.stopCh)
		p.mu.Unlock()

		done := make(chan struct{})
		go func() {
			p.wg.Wait()
			close(done)
		}()

		select {
		case <-done:
		case <-time.After(p.cfg.ShutdownTimeout):
			closeErr = errors.New("outbox publisher shutdown timeout")
		}

		if err := p.target.Close(); err != nil && closeErr == nil {
			closeErr = err
		}
	})

	return closeErr
}

func (p *outboxPublisher) loop() {
	defer p.wg.Done()
	defer p.ticker.Stop()
	defer p.cleaner.Stop()

	for {
		select {
		case <-p.stopCh:
			return
		case <-p.ticker.C:
			p.flush()
		case <-p.cleaner.C:
			p.cleanupSent()
		case <-p.signal:
			p.flush()
		}
	}
}

func (p *outboxPublisher) flush() {
	ctx, cancel := context.WithTimeout(context.Background(), p.cfg.PublishTimeout)
	events, err := p.store.ListPending(ctx, time.Now().UTC(), p.cfg.BatchSize)
	cancel()
	if err != nil {
		logger.Warnf("[Outbox] 读取待发送事件失败: %v", err)
		return
	}

	for _, event := range events {
		p.publishOne(event)
	}
}

func (p *outboxPublisher) publishOne(event OutboxEvent) {
	ctx, cancel := context.WithTimeout(context.Background(), p.cfg.PublishTimeout)
	err := p.target.Publish(ctx, event.Key, event.Payload)
	cancel()
	if err == nil {
		if markErr := p.store.MarkSent(context.Background(), event.ID); markErr != nil {
			logger.Warnf("[Outbox] 标记发送成功失败: id=%s err=%v", event.ID, markErr)
		}
		return
	}

	attempt := event.Attempts + 1
	if attempt >= p.cfg.MaxDeliveryAttempts {
		if markErr := p.store.MarkFailed(context.Background(), event.ID, err.Error()); markErr != nil {
			logger.Warnf("[Outbox] 标记失败终态失败: id=%s err=%v", event.ID, markErr)
			return
		}
		logger.Errorf("[Outbox] 事件达到最大重试次数，标记失败: id=%s attempts=%d err=%v", event.ID, attempt, err)
		return
	}

	backoff := p.nextBackoff(event.Attempts + 1)
	nextRetry := time.Now().UTC().Add(backoff)
	if markErr := p.store.MarkRetry(context.Background(), event.ID, nextRetry, err.Error()); markErr != nil {
		logger.Warnf("[Outbox] 标记重试失败: id=%s err=%v", event.ID, markErr)
		return
	}
	logger.Warnf("[Outbox] 事件发送失败，等待重试: id=%s attempt=%d err=%v", event.ID, event.Attempts+1, err)
}

func (p *outboxPublisher) cleanupSent() {
	before := time.Now().UTC().Add(-p.cfg.SentRetention)
	ctx, cancel := context.WithTimeout(context.Background(), p.cfg.PublishTimeout)
	removed, err := p.store.CleanupSentBefore(ctx, before, p.cfg.CleanupBatchSize)
	cancel()
	if err != nil {
		logger.Warnf("[Outbox] 清理已发送事件失败: %v", err)
		return
	}
	if removed > 0 {
		logger.Debugf("[Outbox] 清理已发送事件: removed=%d", removed)
	}
}

func (p *outboxPublisher) nextBackoff(attempt int) time.Duration {
	if attempt < 1 {
		attempt = 1
	}

	cappedAttempt := attempt
	if p.cfg.MaxRetries > 0 && cappedAttempt > p.cfg.MaxRetries {
		cappedAttempt = p.cfg.MaxRetries
	}

	backoff := p.cfg.RetryBackoff
	for i := 1; i < cappedAttempt; i++ {
		backoff *= 2
		if backoff >= p.cfg.MaxRetryBackoff {
			return p.cfg.MaxRetryBackoff
		}
	}

	if backoff > p.cfg.MaxRetryBackoff {
		return p.cfg.MaxRetryBackoff
	}
	return backoff
}

func withDefaultOutboxConfig(cfg OutboxPublisherConfig) OutboxPublisherConfig {
	if cfg.PollInterval <= 0 {
		cfg.PollInterval = 1 * time.Second
	}
	if cfg.BatchSize <= 0 {
		cfg.BatchSize = 100
	}
	if cfg.PublishTimeout <= 0 {
		cfg.PublishTimeout = 2 * time.Second
	}
	if cfg.MaxRetries <= 0 {
		cfg.MaxRetries = 6
	}
	if cfg.MaxDeliveryAttempts <= 0 {
		if cfg.MaxRetries > 0 {
			cfg.MaxDeliveryAttempts = cfg.MaxRetries
		} else {
			cfg.MaxDeliveryAttempts = 6
		}
	}
	if cfg.RetryBackoff <= 0 {
		cfg.RetryBackoff = 200 * time.Millisecond
	}
	if cfg.MaxRetryBackoff <= 0 {
		cfg.MaxRetryBackoff = 30 * time.Second
	}
	if cfg.CleanupInterval <= 0 {
		cfg.CleanupInterval = 10 * time.Minute
	}
	if cfg.SentRetention <= 0 {
		cfg.SentRetention = 7 * 24 * time.Hour
	}
	if cfg.CleanupBatchSize <= 0 {
		cfg.CleanupBatchSize = 1000
	}
	if cfg.ShutdownTimeout <= 0 {
		cfg.ShutdownTimeout = 5 * time.Second
	}
	return cfg
}
