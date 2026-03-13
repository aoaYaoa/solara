package models

import (
	"time"

	"github.com/google/uuid"
)

// UserRole 用户角色关联表（多对多）
type UserRole struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	UserID    uuid.UUID `json:"user_id" gorm:"type:uuid;not null;index"`
	RoleID    uuid.UUID `json:"role_id" gorm:"type:uuid;not null;index"`
	CreatedAt time.Time `json:"created_at" gorm:"type:timestamptz;default:now()"`

	// 关联
	User User `json:"user,omitempty" gorm:"foreignKey:UserID;references:ID"`
	Role Role `json:"role,omitempty" gorm:"foreignKey:RoleID;references:ID"`
}

// TableName 指定表名
func (UserRole) TableName() string {
	return "user_roles"
}
