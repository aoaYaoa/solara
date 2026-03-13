package repositories

import (
	"backend/internal/models"
	"context"

	"github.com/google/uuid"
)

// MenuRepository 菜单仓储接口
type MenuRepository interface {
	FindByRoleIDs(ctx context.Context, roleIDs []uuid.UUID) ([]*models.Menu, error)
	FindAll(ctx context.Context) ([]*models.Menu, error)
}
