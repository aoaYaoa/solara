package dto

import (
	"backend/internal/models"
	"time"

	"github.com/google/uuid"
)

// RegisterRequest 用户注册请求
type RegisterRequest struct {
	Username string `json:"username" binding:"required,min=3,max=20"`
	Email    string `json:"email" binding:"omitempty,email"`
	Password string `json:"password" binding:"required,min=6"`
}

// LoginRequest 用户登录请求
type LoginRequest struct {
	Username    string `json:"username" binding:"required"`
	Password    string `json:"password" binding:"required"`
	CaptchaID   string `json:"captcha_id" binding:"required"`
	CaptchaCode string `json:"captcha_code" binding:"required"`
}

// RegisterResponse 注册响应
type RegisterResponse struct {
	ID       uuid.UUID `json:"id"`
	Username string    `json:"username"`
	Email    string    `json:"email"`
	Role     string    `json:"role"`
}

// RoleResponse 角色响应
type RoleResponse struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Code        string    `json:"code"`
	Description string    `json:"description"`
}

// MenuResponse 菜单响应
type MenuResponse struct {
	ID        uuid.UUID  `json:"id"`
	ParentID  *uuid.UUID `json:"parent_id"`
	Name      string     `json:"name"`
	Path      string     `json:"path"`
	Icon      string     `json:"icon"`
	Component string     `json:"component"`
	Sort      int        `json:"sort"`
	Type      string     `json:"type"`
}

// UserResponse 用户信息响应
type UserResponse struct {
	ID        uuid.UUID `json:"id"`
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// LoginResponse 登录响应
type LoginResponse struct {
	User      RegisterResponse `json:"user"`
	Token     string           `json:"token"`
	TokenType string           `json:"token_type"`
	ExpiresIn int64            `json:"expires_in"`
	Roles     []RoleResponse   `json:"roles"`
	Menus     []MenuResponse   `json:"menus"`
}

func ToUserResponse(user *models.User) *UserResponse {
	return &UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		Email:     user.Email,
		Role:      user.Role,
		CreatedAt: user.CreatedAt,
		UpdatedAt: user.UpdatedAt,
	}
}

func ToUserResponseList(users []*models.User) []UserResponse {
	list := make([]UserResponse, len(users))
	for i, user := range users {
		list[i] = *ToUserResponse(user)
	}
	return list
}
