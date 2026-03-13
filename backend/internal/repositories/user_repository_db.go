package repositories

import (
	"backend/internal/models"
	"backend/pkg/utils/logger"
	"context"
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// DBUserRepository 数据库用户仓储实现
// 使用GORM ORM框架与数据库交互，支持MySQL等多种数据库
type DBUserRepository struct {
	db *gorm.DB
}

// NewDBUserRepository 创建数据库用户仓储实例
// 需要传入已初始化的GORM数据库实例
func NewDBUserRepository(db *gorm.DB) UserRepository {
	return &DBUserRepository{
		db: db,
	}
}

// Create 创建用户
// 将用户信息插入数据库表，自动生成ID和时间戳
func (r *DBUserRepository) Create(ctx context.Context, user *models.User) (*models.User, error) {
	// 使用GORM创建记录，GORM会自动处理ID和时间戳
	if err := r.db.WithContext(ctx).Create(user).Error; err != nil {
		logger.Errorf("创建用户失败: %v", err)
		return nil, errors.New("创建用户失败: " + err.Error())
	}

	logger.Infof("用户创建成功: ID=%s, Username=%s", user.ID.String(), user.Username)
	return user, nil
}

// FindByID 根据ID查找用户
// 返回完整的用户信息，不包括密码（通过json标签控制）
func (r *DBUserRepository) FindByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	var user models.User

	// 使用GORM查询，First返回第一条匹配的记录
	if err := r.db.WithContext(ctx).First(&user, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("用户不存在")
		}
		logger.Errorf("根据ID查找用户失败: %v", err)
		return nil, err
	}

	return &user, nil
}

// FindByUsername 根据用户名查找用户
// 用于用户登录验证和唯一性检查
func (r *DBUserRepository) FindByUsername(ctx context.Context, username string) (*models.User, error) {
	var user models.User

	// 使用Where条件查询用户名，并预加载角色信息
	if err := r.db.WithContext(ctx).Preload("Roles").Where("username = ?", username).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("用户不存在")
		}
		logger.Errorf("根据用户名查找用户失败: %v", err)
		return nil, err
	}

	return &user, nil
}

// FindByEmail 根据邮箱查找用户
// 用于邮箱唯一性检查和用户找回密码等功能
func (r *DBUserRepository) FindByEmail(ctx context.Context, email string) (*models.User, error) {
	var user models.User

	// 使用Where条件查询邮箱
	if err := r.db.WithContext(ctx).Where("email = ?", email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("用户不存在")
		}
		logger.Errorf("根据邮箱查找用户失败: %v", err)
		return nil, err
	}

	return &user, nil
}

// Update 更新用户信息
// 支持部分字段更新，自动更新UpdatedAt时间戳
func (r *DBUserRepository) Update(ctx context.Context, user *models.User) (*models.User, error) {
	// 使用Save更新用户，如果记录不存在会创建新记录
	// 如果只想更新现有记录，可以使用Updates
	if err := r.db.WithContext(ctx).Save(user).Error; err != nil {
		logger.Errorf("更新用户失败: %v", err)
		return nil, errors.New("更新用户失败: " + err.Error())
	}

	logger.Infof("用户更新成功: ID=%s", user.ID.String())
	return user, nil
}

// Delete 删除用户
func (r *DBUserRepository) Delete(ctx context.Context, id uuid.UUID) error {
	result := r.db.WithContext(ctx).Delete(&models.User{}, "id = ?", id)
	if result.Error != nil {
		logger.Errorf("删除用户失败: %v", result.Error)
		return errors.New("删除用户失败: " + result.Error.Error())
	}
	if result.RowsAffected == 0 {
		return errors.New("用户不存在")
	}

	logger.Infof("用户删除成功: ID=%s", id.String())
	return nil
}

// List 列出所有用户
func (r *DBUserRepository) List(ctx context.Context) ([]*models.User, error) {
	var users []*models.User
	if err := r.db.WithContext(ctx).Find(&users).Error; err != nil {
		logger.Errorf("获取用户列表失败: %v", err)
		return nil, errors.New("获取用户列表失败: " + err.Error())
	}
	return users, nil
}

// ExistsByUsername 检查用户名是否已存在（辅助方法）
// 用于注册时验证用户名唯一性
func (r *DBUserRepository) ExistsByUsername(username string) (bool, error) {
	var count int64
	if err := r.db.Model(&models.User{}).Where("username = ?", username).Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

// ExistsByEmail 检查邮箱是否已存在（辅助方法）
// 用于注册时验证邮箱唯一性
func (r *DBUserRepository) ExistsByEmail(email string) (bool, error) {
	var count int64
	if err := r.db.Model(&models.User{}).Where("email = ?", email).Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}
