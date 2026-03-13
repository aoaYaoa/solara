package models

import (
	"time"

	"github.com/google/uuid"
)

// Menu 菜单模型
type Menu struct {
	ID        uuid.UUID  `json:"id" gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	ParentID  *uuid.UUID `json:"parent_id" gorm:"type:uuid"`
	Name      string     `json:"name" binding:"required" gorm:"type:text"`
	Path      string     `json:"path" gorm:"type:text"`
	Icon      string     `json:"icon" gorm:"type:text"`
	Component string     `json:"component" gorm:"type:text"`
	Sort      int        `json:"sort" gorm:"type:integer;default:0"`
	Type      string     `json:"type" gorm:"type:text;default:'menu'"` // menu, button
	Status    string     `json:"status" gorm:"type:text;default:'active'"`
	CreatedAt time.Time  `json:"created_at" gorm:"type:timestamptz;default:now()"`
	UpdatedAt time.Time  `json:"updated_at" gorm:"type:timestamptz;default:now()"`
}

// TableName 指定表名
func (Menu) TableName() string {
	return "menus"
}
