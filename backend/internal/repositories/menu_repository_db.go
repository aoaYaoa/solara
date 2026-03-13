package repositories

import (
	"backend/internal/models"
	"context"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type menuRepository struct {
	db *gorm.DB
}

// NewMenuRepository 创建菜单仓储实例
func NewMenuRepository(db *gorm.DB) MenuRepository {
	return &menuRepository{db: db}
}

// FindByRoleIDs 根据角色ID列表查询菜单
func (r *menuRepository) FindByRoleIDs(ctx context.Context, roleIDs []uuid.UUID) ([]*models.Menu, error) {
	var menus []*models.Menu

	// 通过 role_menus 关联表查询菜单
	err := r.db.WithContext(ctx).
		Distinct().
		Joins("JOIN role_menus ON role_menus.menu_id = menus.id").
		Where("role_menus.role_id IN ?", roleIDs).
		Where("menus.status = ?", "active").
		Order("menus.sort ASC, menus.created_at ASC").
		Find(&menus).Error

	return menus, err
}

// FindAll 查询所有菜单
func (r *menuRepository) FindAll(ctx context.Context) ([]*models.Menu, error) {
	var menus []*models.Menu

	err := r.db.WithContext(ctx).
		Where("status = ?", "active").
		Order("sort ASC, created_at ASC").
		Find(&menus).Error

	return menus, err
}
