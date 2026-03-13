package messaging

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/segmentio/kafka-go"
)

// KafkaConfig 定义 Kafka 发布配置。
type KafkaConfig struct {
	Brokers      []string
	Topic        string
	CAFile       string
	CertFile     string
	KeyFile      string
	RequireTLS   bool
	WriteTimeout time.Duration
}

type kafkaPublisher struct {
	writer  *kafka.Writer
	dialer  *kafka.Dialer
	brokers []string
	topic   string
}

// NewKafkaPublisher 创建 Kafka 发布器。
func NewKafkaPublisher(cfg KafkaConfig) (EventPublisher, error) {
	if len(cfg.Brokers) == 0 {
		return nil, errors.New("kafka brokers is empty")
	}
	if strings.TrimSpace(cfg.Topic) == "" {
		return nil, errors.New("kafka topic is empty")
	}

	var tlsConfig *tls.Config
	if cfg.RequireTLS {
		var err error
		tlsConfig, err = loadTLSConfig(cfg.CAFile, cfg.CertFile, cfg.KeyFile)
		if err != nil {
			return nil, err
		}
	}

	transport := &kafka.Transport{}
	if tlsConfig != nil {
		transport.TLS = tlsConfig
	}

	timeout := cfg.WriteTimeout
	if timeout <= 0 {
		timeout = 5 * time.Second
	}

	writer := &kafka.Writer{
		Addr:         kafka.TCP(cfg.Brokers...),
		Topic:        cfg.Topic,
		RequiredAcks: kafka.RequireAll,
		Balancer:     &kafka.Hash{},
		Transport:    transport,
		WriteTimeout: timeout,
	}

	dialer := &kafka.Dialer{Timeout: timeout}
	if tlsConfig != nil {
		dialer.TLS = tlsConfig
	}

	return &kafkaPublisher{
		writer:  writer,
		dialer:  dialer,
		brokers: append([]string(nil), cfg.Brokers...),
		topic:   cfg.Topic,
	}, nil
}

func (p *kafkaPublisher) Publish(ctx context.Context, key string, payload []byte) error {
	if ctx == nil {
		ctx = context.Background()
	}

	msg := kafka.Message{
		Key:   []byte(key),
		Value: payload,
		Time:  time.Now().UTC(),
	}
	return p.writer.WriteMessages(ctx, msg)
}

func (p *kafkaPublisher) Close() error {
	return p.writer.Close()
}

func (p *kafkaPublisher) HealthCheck(ctx context.Context) error {
	if ctx == nil {
		ctx = context.Background()
	}
	if len(p.brokers) == 0 {
		return errors.New("kafka broker is empty")
	}

	checkCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	conn, err := p.dialer.DialContext(checkCtx, "tcp", p.brokers[0])
	if err != nil {
		return fmt.Errorf("dial kafka broker failed: %w", err)
	}
	defer conn.Close()

	if _, err := conn.ReadPartitions(p.topic); err != nil {
		return fmt.Errorf("read kafka partitions failed: %w", err)
	}

	return nil
}

func loadTLSConfig(caFile, certFile, keyFile string) (*tls.Config, error) {
	if strings.TrimSpace(caFile) == "" || strings.TrimSpace(certFile) == "" || strings.TrimSpace(keyFile) == "" {
		return nil, errors.New("kafka TLS files are required when TLS is enabled")
	}

	caPEM, err := os.ReadFile(caFile)
	if err != nil {
		return nil, fmt.Errorf("read kafka ca file failed: %w", err)
	}

	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		return nil, fmt.Errorf("load kafka client cert/key failed: %w", err)
	}

	pool := x509.NewCertPool()
	if ok := pool.AppendCertsFromPEM(caPEM); !ok {
		return nil, errors.New("parse kafka ca file failed")
	}

	return &tls.Config{
		MinVersion:   tls.VersionTLS12,
		RootCAs:      pool,
		Certificates: []tls.Certificate{cert},
	}, nil
}
