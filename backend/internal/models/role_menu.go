package models

import (
	"time"

	"github.com/google/uuid"
)

// RoleMenu 角色菜单关联表（多对多）
type RoleMenu struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	RoleID    uuid.UUID `json:"role_id" gorm:"type:uuid;not null;index"`
	MenuID    uuid.UUID `json:"menu_id" gorm:"type:uuid;not null;index"`
	CreatedAt time.Time `json:"created_at" gorm:"type:timestamptz;default:now()"`

	// 关联
	Role Role `json:"role,omitempty" gorm:"foreignKey:RoleID;references:ID"`
	Menu Menu `json:"menu,omitempty" gorm:"foreignKey:MenuID;references:ID"`
}

// TableName 指定表名
func (RoleMenu) TableName() string {
	return "role_menus"
}
