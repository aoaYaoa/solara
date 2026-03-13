package models

import (
	"time"

	"github.com/google/uuid"
)

// Role 角色模型
type Role struct {
	ID          uuid.UUID `json:"id" gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	Name        string    `json:"name" binding:"required" gorm:"type:text;uniqueIndex"`
	Code        string    `json:"code" binding:"required" gorm:"type:text;uniqueIndex"`
	Description string    `json:"description" gorm:"type:text"`
	Status      string    `json:"status" gorm:"type:text;default:'active'"`
	CreatedAt   time.Time `json:"created_at" gorm:"type:timestamptz;default:now()"`
	UpdatedAt   time.Time `json:"updated_at" gorm:"type:timestamptz;default:now()"`
}

// TableName 指定表名
func (Role) TableName() string {
	return "roles"
}
