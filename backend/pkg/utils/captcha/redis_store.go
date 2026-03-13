package captcha

import (
	"bufio"
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net"
	"strconv"
	"strings"
	"time"
)

const (
	defaultRedisKeyPrefix = "captcha:"
	redisTimeout          = 5 * time.Second
)

// StoreConfig 验证码存储配置。
// 当 Addr 为空时会回退到内存存储。
type StoreConfig struct {
	Addr      string
	Username  string
	Password  string
	DB        int
	UseTLS    bool
	KeyPrefix string
}

type redisStore struct {
	addr      string
	username  string
	password  string
	db        int
	useTLS    bool
	keyPrefix string
}

// NewRedisStore 创建 Redis 验证码存储。
func NewRedisStore(cfg StoreConfig) (CaptchaStore, error) {
	if strings.TrimSpace(cfg.Addr) == "" {
		return nil, errors.New("redis address is required")
	}

	prefix := cfg.KeyPrefix
	if prefix == "" {
		prefix = defaultRedisKeyPrefix
	}

	s := &redisStore{
		addr:      cfg.Addr,
		username:  cfg.Username,
		password:  cfg.Password,
		db:        cfg.DB,
		useTLS:    cfg.UseTLS,
		keyPrefix: prefix,
	}

	if err := s.ping(context.Background()); err != nil {
		return nil, err
	}

	return s, nil
}

func (s *redisStore) key(id string) string {
	return s.keyPrefix + id
}

func (s *redisStore) Set(id, code string, expiration time.Duration) error {
	if expiration <= 0 {
		expiration = time.Minute
	}

	ms := int64(math.Ceil(float64(expiration) / float64(time.Millisecond)))
	if ms < 1 {
		ms = 1
	}

	_, err := s.exec(context.Background(), "SET", s.key(id), code, "PX", strconv.FormatInt(ms, 10))
	return err
}

func (s *redisStore) Get(id string) (string, bool) {
	resp, err := s.exec(context.Background(), "GET", s.key(id))
	if err != nil {
		return "", false
	}
	if resp.isNil {
		return "", false
	}
	return resp.str, true
}

func (s *redisStore) Delete(id string) {
	_, _ = s.exec(context.Background(), "DEL", s.key(id))
}

func (s *redisStore) ping(ctx context.Context) error {
	resp, err := s.exec(ctx, "PING")
	if err != nil {
		return err
	}
	if resp.str != "PONG" {
		return fmt.Errorf("unexpected redis ping response: %q", resp.str)
	}
	return nil
}

func (s *redisStore) HealthCheck(ctx context.Context) error {
	return s.ping(ctx)
}

type redisResp struct {
	str   string
	isNil bool
}

func (s *redisStore) exec(ctx context.Context, args ...string) (*redisResp, error) {
	conn, err := s.dial(ctx)
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	if err := s.authAndSelect(conn); err != nil {
		return nil, err
	}

	if err := writeRESP(conn, args...); err != nil {
		return nil, err
	}

	reader := bufio.NewReader(conn)
	return readRESP(reader)
}

func (s *redisStore) dial(ctx context.Context) (net.Conn, error) {
	dialer := &net.Dialer{Timeout: redisTimeout}
	if deadline, ok := ctx.Deadline(); ok {
		dialer.Deadline = deadline
	}

	if s.useTLS {
		conf := &tls.Config{MinVersion: tls.VersionTLS12}
		conn, err := tls.DialWithDialer(dialer, "tcp", s.addr, conf)
		if err != nil {
			return nil, err
		}
		_ = conn.SetDeadline(time.Now().Add(redisTimeout))
		return conn, nil
	}

	conn, err := dialer.DialContext(ctx, "tcp", s.addr)
	if err != nil {
		return nil, err
	}
	_ = conn.SetDeadline(time.Now().Add(redisTimeout))
	return conn, nil
}

func (s *redisStore) authAndSelect(conn net.Conn) error {
	reader := bufio.NewReader(conn)

	if s.password != "" {
		var err error
		if s.username != "" {
			err = writeRESP(conn, "AUTH", s.username, s.password)
		} else {
			err = writeRESP(conn, "AUTH", s.password)
		}
		if err != nil {
			return err
		}
		if _, err := readRESP(reader); err != nil {
			return err
		}
	}

	if s.db > 0 {
		if err := writeRESP(conn, "SELECT", strconv.Itoa(s.db)); err != nil {
			return err
		}
		if _, err := readRESP(reader); err != nil {
			return err
		}
	}

	return nil
}

func writeRESP(w io.Writer, args ...string) error {
	if _, err := fmt.Fprintf(w, "*%d\r\n", len(args)); err != nil {
		return err
	}
	for _, arg := range args {
		if _, err := fmt.Fprintf(w, "$%d\r\n%s\r\n", len(arg), arg); err != nil {
			return err
		}
	}
	return nil
}

func readRESP(reader *bufio.Reader) (*redisResp, error) {
	line, err := reader.ReadString('\n')
	if err != nil {
		return nil, err
	}
	if len(line) < 3 || !strings.HasSuffix(line, "\r\n") {
		return nil, errors.New("invalid redis response")
	}

	prefix := line[0]
	payload := strings.TrimSuffix(line[1:], "\r\n")

	switch prefix {
	case '+':
		return &redisResp{str: payload}, nil
	case '-':
		return nil, errors.New(payload)
	case ':':
		return &redisResp{str: payload}, nil
	case '$':
		sz, err := strconv.Atoi(payload)
		if err != nil {
			return nil, err
		}
		if sz == -1 {
			return &redisResp{isNil: true}, nil
		}
		buf := make([]byte, sz+2)
		if _, err := io.ReadFull(reader, buf); err != nil {
			return nil, err
		}
		return &redisResp{str: string(buf[:sz])}, nil
	default:
		return nil, fmt.Errorf("unsupported redis response type: %q", string(prefix))
	}
}

// InitStoreWithConfig 使用配置初始化全局验证码存储。
// 当 Redis 不可用时，自动回退到内存存储。
func InitStoreWithConfig(cfg StoreConfig) {
	if strings.TrimSpace(cfg.Addr) == "" {
		InitStore()
		log.Printf("[captcha] REDIS_ADDR 未配置，使用内存存储")
		return
	}

	store, err := NewRedisStore(cfg)
	if err != nil {
		log.Printf("[captcha] Redis 初始化失败，回退内存存储: %v", err)
		InitStore()
		return
	}

	globalStore = store
	log.Printf("[captcha] 使用 Redis 存储验证码: %s", cfg.Addr)
}
