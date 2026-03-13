package models

import "time"

type PlaybackStore struct {
	Key       string    `json:"key" gorm:"primaryKey;type:text"`
	Value     string    `json:"value" gorm:"type:text"`
	UpdatedAt time.Time `json:"updated_at" gorm:"autoUpdateTime"`
}

func (PlaybackStore) TableName() string {
	return "playback_store"
}

type FavoritesStore struct {
	Key       string    `json:"key" gorm:"primaryKey;type:text"`
	Value     string    `json:"value" gorm:"type:text"`
	UpdatedAt time.Time `json:"updated_at" gorm:"autoUpdateTime"`
}

func (FavoritesStore) TableName() string {
	return "favorites_store"
}
