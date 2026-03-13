package messaging

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type outboxRecord struct {
	ID          string     `gorm:"type:varchar(64);primaryKey"`
	EventKey    string     `gorm:"type:varchar(128);not null;index"`
	Payload     []byte     `gorm:"type:bytea;not null"`
	Attempts    int        `gorm:"not null;default:0"`
	NextRetryAt time.Time  `gorm:"not null;index"`
	Status      string     `gorm:"type:varchar(32);not null;index"`
	LastError   string     `gorm:"type:text"`
	SentAt      *time.Time `gorm:"index"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

func (outboxRecord) TableName() string {
	return "event_outbox"
}

type gormOutboxStore struct {
	db *gorm.DB
}

func NewGormOutboxStore(db *gorm.DB) (OutboxStore, error) {
	if db == nil {
		return nil, fmt.Errorf("gorm db is nil")
	}
	if err := db.AutoMigrate(&outboxRecord{}); err != nil {
		return nil, fmt.Errorf("migrate outbox table failed: %w", err)
	}
	return &gormOutboxStore{db: db}, nil
}

func (s *gormOutboxStore) Enqueue(ctx context.Context, event OutboxEvent) (OutboxEvent, error) {
	if event.ID == "" {
		event.ID = uuid.NewString()
	}
	if event.NextRetryAt.IsZero() {
		event.NextRetryAt = time.Now().UTC()
	}

	record := outboxRecord{
		ID:          event.ID,
		EventKey:    event.Key,
		Payload:     append([]byte(nil), event.Payload...),
		Attempts:    event.Attempts,
		NextRetryAt: event.NextRetryAt.UTC(),
		Status:      OutboxStatusPending,
		LastError:   event.LastError,
	}
	if err := s.db.WithContext(ctx).Create(&record).Error; err != nil {
		return OutboxEvent{}, err
	}

	return OutboxEvent{
		ID:          record.ID,
		Key:         record.EventKey,
		Payload:     append([]byte(nil), record.Payload...),
		Status:      record.Status,
		Attempts:    record.Attempts,
		NextRetryAt: record.NextRetryAt,
		LastError:   record.LastError,
		CreatedAt:   record.CreatedAt,
		UpdatedAt:   record.UpdatedAt,
		SentAt:      record.SentAt,
	}, nil
}

func (s *gormOutboxStore) ListPending(ctx context.Context, now time.Time, limit int) ([]OutboxEvent, error) {
	if limit <= 0 {
		limit = 100
	}

	var rows []outboxRecord
	if err := s.db.WithContext(ctx).
		Where("status = ? AND next_retry_at <= ?", OutboxStatusPending, now.UTC()).
		Order("next_retry_at ASC, created_at ASC").
		Limit(limit).
		Find(&rows).Error; err != nil {
		return nil, err
	}

	events := make([]OutboxEvent, 0, len(rows))
	for _, row := range rows {
		events = append(events, OutboxEvent{
			ID:          row.ID,
			Key:         row.EventKey,
			Payload:     append([]byte(nil), row.Payload...),
			Status:      row.Status,
			Attempts:    row.Attempts,
			NextRetryAt: row.NextRetryAt,
			LastError:   row.LastError,
			CreatedAt:   row.CreatedAt,
			UpdatedAt:   row.UpdatedAt,
			SentAt:      row.SentAt,
		})
	}
	return events, nil
}

func (s *gormOutboxStore) MarkSent(ctx context.Context, id string) error {
	now := time.Now().UTC()
	return s.db.WithContext(ctx).
		Model(&outboxRecord{}).
		Where("id = ?", id).
		Updates(map[string]any{
			"status":     OutboxStatusSent,
			"last_error": "",
			"sent_at":    &now,
		}).Error
}

func (s *gormOutboxStore) MarkRetry(ctx context.Context, id string, nextRetryAt time.Time, lastErr string) error {
	return s.db.WithContext(ctx).
		Model(&outboxRecord{}).
		Where("id = ?", id).
		Updates(map[string]any{
			"attempts":      gorm.Expr("attempts + ?", 1),
			"next_retry_at": nextRetryAt.UTC(),
			"last_error":    lastErr,
			"status":        OutboxStatusPending,
		}).Error
}

func (s *gormOutboxStore) MarkFailed(ctx context.Context, id string, lastErr string) error {
	return s.db.WithContext(ctx).
		Model(&outboxRecord{}).
		Where("id = ?", id).
		Updates(map[string]any{
			"attempts":   gorm.Expr("attempts + ?", 1),
			"last_error": lastErr,
			"status":     OutboxStatusFailed,
		}).Error
}

func (s *gormOutboxStore) CleanupSentBefore(ctx context.Context, before time.Time, limit int) (int64, error) {
	if limit <= 0 {
		limit = 1000
	}

	var ids []string
	if err := s.db.WithContext(ctx).
		Model(&outboxRecord{}).
		Where("status = ? AND sent_at IS NOT NULL AND sent_at < ?", OutboxStatusSent, before.UTC()).
		Order("sent_at ASC").
		Limit(limit).
		Pluck("id", &ids).Error; err != nil {
		return 0, err
	}
	if len(ids) == 0 {
		return 0, nil
	}

	res := s.db.WithContext(ctx).Where("id IN ?", ids).Delete(&outboxRecord{})
	if res.Error != nil {
		return 0, res.Error
	}
	return res.RowsAffected, nil
}

func (s *gormOutboxStore) HealthCheck(ctx context.Context) error {
	sqlDB, err := s.db.WithContext(ctx).DB()
	if err != nil {
		return err
	}
	return sqlDB.PingContext(ctx)
}
