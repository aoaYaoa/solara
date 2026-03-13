package messaging

import (
	"backend/pkg/utils/logger"
	"context"
	"errors"
	"sync"
	"time"
)

var (
	ErrPublisherClosed    = errors.New("publisher is closed")
	ErrPublisherQueueFull = errors.New("publisher queue is full")
)

type AsyncPublisherConfig struct {
	QueueSize       int
	WorkerCount     int
	PublishTimeout  time.Duration
	MaxRetries      int
	RetryBackoff    time.Duration
	ShutdownTimeout time.Duration
}

type queuedEvent struct {
	key     string
	payload []byte
}

type asyncPublisher struct {
	base   EventPublisher
	cfg    AsyncPublisherConfig
	queue  chan queuedEvent
	closed chan struct{}

	closeOnce sync.Once
	wg        sync.WaitGroup
	mu        sync.RWMutex
	isClosed  bool
}

// NewAsyncPublisher 返回异步发布器包装器。
// 发布请求会先入队，再由后台 worker 重试发送，避免阻塞主流程。
func NewAsyncPublisher(base EventPublisher, cfg AsyncPublisherConfig) EventPublisher {
	if base == nil {
		base = NewNoopPublisher()
	}

	cfg = withDefaultAsyncConfig(cfg)
	p := &asyncPublisher{
		base:   base,
		cfg:    cfg,
		queue:  make(chan queuedEvent, cfg.QueueSize),
		closed: make(chan struct{}),
	}

	for i := 0; i < cfg.WorkerCount; i++ {
		p.wg.Add(1)
		go p.worker(i + 1)
	}

	return p
}

func (p *asyncPublisher) Publish(ctx context.Context, key string, payload []byte) error {
	if ctx == nil {
		ctx = context.Background()
	}

	msg := queuedEvent{
		key:     key,
		payload: append([]byte(nil), payload...),
	}

	p.mu.RLock()
	defer p.mu.RUnlock()
	if p.isClosed {
		return ErrPublisherClosed
	}

	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-p.closed:
		return ErrPublisherClosed
	case p.queue <- msg:
		return nil
	default:
		return ErrPublisherQueueFull
	}
}

func (p *asyncPublisher) HealthCheck(ctx context.Context) error {
	return p.base.HealthCheck(ctx)
}

func (p *asyncPublisher) Close() error {
	var closeErr error

	p.closeOnce.Do(func() {
		p.mu.Lock()
		p.isClosed = true
		close(p.closed)
		close(p.queue)
		p.mu.Unlock()

		done := make(chan struct{})
		go func() {
			p.wg.Wait()
			close(done)
		}()

		select {
		case <-done:
		case <-time.After(p.cfg.ShutdownTimeout):
			closeErr = errors.New("async publisher shutdown timeout")
		}

		if err := p.base.Close(); err != nil && closeErr == nil {
			closeErr = err
		}
	})

	return closeErr
}

func (p *asyncPublisher) worker(workerID int) {
	defer p.wg.Done()

	for msg := range p.queue {
		p.publishWithRetry(msg, workerID)
	}
}

func (p *asyncPublisher) publishWithRetry(msg queuedEvent, workerID int) {
	attempts := p.cfg.MaxRetries + 1
	for i := 0; i < attempts; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), p.cfg.PublishTimeout)
		err := p.base.Publish(ctx, msg.key, msg.payload)
		cancel()
		if err == nil {
			return
		}

		if i == attempts-1 {
			logger.Warnf("[Messaging] 异步发布失败(丢弃): worker=%d key=%s attempts=%d err=%v",
				workerID, msg.key, attempts, err)
			return
		}

		sleep := p.cfg.RetryBackoff * time.Duration(1<<i)
		if sleep > time.Second {
			sleep = time.Second
		}
		time.Sleep(sleep)
	}
}

func withDefaultAsyncConfig(cfg AsyncPublisherConfig) AsyncPublisherConfig {
	if cfg.QueueSize <= 0 {
		cfg.QueueSize = 256
	}
	if cfg.WorkerCount <= 0 {
		cfg.WorkerCount = 1
	}
	if cfg.PublishTimeout <= 0 {
		cfg.PublishTimeout = 2 * time.Second
	}
	if cfg.MaxRetries < 0 {
		cfg.MaxRetries = 0
	}
	if cfg.RetryBackoff <= 0 {
		cfg.RetryBackoff = 100 * time.Millisecond
	}
	if cfg.ShutdownTimeout <= 0 {
		cfg.ShutdownTimeout = 3 * time.Second
	}
	return cfg
}
