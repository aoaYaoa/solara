package models

import (
	"time"

	"github.com/google/uuid"
)

// User 用户模型
// 完全兼容 Supabase public.users 表结构
type User struct {
	ID       uuid.UUID `json:"id" gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	Email    string    `json:"email" binding:"omitempty,email" gorm:"type:text;uniqueIndex"`
	Username string    `json:"username" binding:"required,min=3,max=20" gorm:"type:text;uniqueIndex"`
	Password string    `json:"-" binding:"required,min=6" gorm:"type:text"`
	Role     string    `json:"role" gorm:"type:text;default:'user'"`

	// Supabase 扩展字段
	FullName    *string    `json:"full_name,omitempty" gorm:"type:text;column:full_name"`
	AvatarURL   *string    `json:"avatar_url,omitempty" gorm:"type:text;column:avatar_url"`
	Phone       *string    `json:"phone,omitempty" gorm:"type:text;column:phone"`
	Gender      *string    `json:"gender,omitempty" gorm:"type:text;column:gender"`
	Birthday    *time.Time `json:"birthday,omitempty" gorm:"type:date;column:birthday"`
	Bio         *string    `json:"bio,omitempty" gorm:"type:text;column:bio"`
	Status      string     `json:"status" gorm:"type:text;default:'active';column:status"`
	IsVerified  bool       `json:"is_verified" gorm:"type:boolean;default:false;column:is_verified"`
	LastLoginAt *time.Time `json:"last_login_at,omitempty" gorm:"type:timestamptz;column:last_login_at"`
	Country     *string    `json:"country,omitempty" gorm:"type:text;column:country"`
	City        *string    `json:"city,omitempty" gorm:"type:text;column:city"`
	Address     *string    `json:"address,omitempty" gorm:"type:text;column:address"`

	CreatedAt time.Time `json:"created_at" gorm:"type:timestamptz;default:now()"`
	UpdatedAt time.Time `json:"updated_at" gorm:"type:timestamptz;default:now()"`

	// 关联
	Roles []Role `json:"roles,omitempty" gorm:"many2many:user_roles;foreignKey:ID;joinForeignKey:UserID;References:ID;joinReferences:RoleID"`
}

// TableName 指定表名
func (User) TableName() string {
	return "users"
}
