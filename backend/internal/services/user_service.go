package services

import (
	"backend/internal/dto"
	"backend/internal/messaging"
	"backend/internal/models"
	"backend/internal/repositories"
	"backend/pkg/utils/crypto"
	"backend/pkg/utils/jwt"
	"backend/pkg/utils/logger"
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
)

// UserService 用户服务接口
type UserService interface {
	Register(ctx context.Context, req *dto.RegisterRequest) (*dto.RegisterResponse, error)
	Login(ctx context.Context, req *dto.LoginRequest) (*dto.LoginResponse, error)
	GetByID(ctx context.Context, id uuid.UUID) (*models.User, error)
	List(ctx context.Context) ([]*models.User, error)
}

// userService 用户服务实现
type userService struct {
	repo      repositories.UserRepository
	menuRepo  repositories.MenuRepository
	publisher messaging.EventPublisher
}

// NewUserService 创建用户服务实例
func NewUserService(repo repositories.UserRepository, menuRepo repositories.MenuRepository, publisher messaging.EventPublisher) UserService {
	if publisher == nil {
		publisher = messaging.NewNoopPublisher()
	}
	return &userService{
		repo:      repo,
		menuRepo:  menuRepo,
		publisher: publisher,
	}
}

// Register 用户注册
func (s *userService) Register(ctx context.Context, req *dto.RegisterRequest) (*dto.RegisterResponse, error) {
	// 检查用户名是否已存在
	if _, err := s.repo.FindByUsername(ctx, req.Username); err == nil {
		return nil, errors.New("用户名已存在")
	}

	// 检查邮箱是否已被使用（仅当提供了邮箱时）
	if req.Email != "" {
		if _, err := s.repo.FindByEmail(ctx, req.Email); err == nil {
			return nil, errors.New("邮箱已被使用")
		}
	}

	// 哈希密码
	hashedPassword, err := crypto.BcryptHash(req.Password, 10)
	if err != nil {
		logger.Errorf("[UserService] 密码哈希失败: %v", err)
		return nil, errors.New("注册失败")
	}

	// 创建用户
	user := &models.User{
		Username: req.Username,
		Email:    req.Email,
		Password: hashedPassword,
		Role:     "user",
	}

	createdUser, err := s.repo.Create(ctx, user)
	if err != nil {
		logger.Errorf("[UserService] 创建用户失败: %v", err)
		return nil, errors.New("注册失败")
	}

	logger.Infof("[UserService] 用户注册成功: id=%s, username=%s", createdUser.ID.String(), createdUser.Username)

	return &dto.RegisterResponse{
		ID:       createdUser.ID,
		Username: createdUser.Username,
		Email:    createdUser.Email,
		Role:     createdUser.Role,
	}, nil
}

// Login 用户登录
func (s *userService) Login(ctx context.Context, req *dto.LoginRequest) (*dto.LoginResponse, error) {
	// 查找用户（预加载角色）
	user, err := s.repo.FindByUsername(ctx, req.Username)
	if err != nil {
		return nil, errors.New("用户名或密码错误")
	}

	// 验证密码
	if !crypto.BcryptVerify(user.Password, req.Password) {
		return nil, errors.New("用户名或密码错误")
	}

	// 生成 Token (使用 UUID string)
	token, err := jwt.GenerateToken(user.ID.String(), user.Username, user.Role, "", 24*time.Hour)
	if err != nil {
		logger.Errorf("[UserService] 生成 Token 失败: %v", err)
		return nil, errors.New("登录失败")
	}

	// 获取用户角色列表
	logger.Debugf("[UserService] 用户 %s 的角色数量: %d", user.Username, len(user.Roles))
	for i, role := range user.Roles {
		logger.Debugf("[UserService] 角色 %d: ID=%s, Name=%s, Code=%s", i, role.ID, role.Name, role.Code)
	}

	roles := make([]dto.RoleResponse, len(user.Roles))
	roleIDs := make([]uuid.UUID, len(user.Roles))
	for i, role := range user.Roles {
		roles[i] = dto.RoleResponse{
			ID:          role.ID,
			Name:        role.Name,
			Code:        role.Code,
			Description: role.Description,
		}
		roleIDs[i] = role.ID
	}

	// 根据角色获取菜单
	var menus []*models.Menu
	if len(roleIDs) > 0 {
		menus, err = s.menuRepo.FindByRoleIDs(ctx, roleIDs)
		if err != nil {
			logger.Warnf("[UserService] 获取用户菜单失败: %v", err)
			// 不影响登录，继续执行
		}
	}

	// 转换菜单为响应格式
	menuResponses := make([]dto.MenuResponse, len(menus))
	for i, menu := range menus {
		menuResponses[i] = dto.MenuResponse{
			ID:        menu.ID,
			ParentID:  menu.ParentID,
			Name:      menu.Name,
			Path:      menu.Path,
			Icon:      menu.Icon,
			Component: menu.Component,
			Sort:      menu.Sort,
			Type:      menu.Type,
		}
	}

	logger.Infof("[UserService] 用户登录成功: id=%s, username=%s, roles=%d, menus=%d",
		user.ID.String(), user.Username, len(roles), len(menuResponses))

	result := &dto.LoginResponse{
		User: dto.RegisterResponse{
			ID:       user.ID,
			Username: user.Username,
			Email:    user.Email,
			Role:     user.Role,
		},
		Token:     token,
		TokenType: "Bearer",
		ExpiresIn: 86400, // 24 小时（秒）
		Roles:     roles,
		Menus:     menuResponses,
	}

	// 发布登录事件（不影响主流程）
	eventPayload, marshalErr := buildUserLoginEventPayload(user)
	if marshalErr != nil {
		logger.Warnf("[UserService] 构造登录事件失败: %v", marshalErr)
	} else {
		if err := s.publisher.Publish(ctx, user.ID.String(), eventPayload); err != nil {
			logger.Warnf("[UserService] 发布登录事件失败: %v", err)
		}
	}

	return result, nil
}

// GetByID 根据 ID 获取用户
func (s *userService) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	return s.repo.FindByID(ctx, id)
}

// List 列出所有用户
func (s *userService) List(ctx context.Context) ([]*models.User, error) {
	return s.repo.List(ctx)
}

func buildUserLoginEventPayload(user *models.User) ([]byte, error) {
	event := map[string]any{
		"event":       "user.login",
		"user_id":     user.ID.String(),
		"username":    user.Username,
		"role":        user.Role,
		"occurred_at": time.Now().UTC().Format(time.RFC3339),
	}
	return json.Marshal(event)
}
