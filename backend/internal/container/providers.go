package container

import (
	"backend/internal/database"
	"backend/internal/repositories"
)

// ProvideTaskRepository 根据数据库类型提供 TaskRepository
func ProvideTaskRepository(manager *database.Manager) repositories.TaskRepository {
	if manager.IsMySQL() {
		return repositories.NewDBTaskRepository(manager.GetDB())
	}
	return repositories.NewTaskRepository()
}

// ProvideUserRepository 根据数据库类型提供 UserRepository
func ProvideUserRepository(manager *database.Manager) repositories.UserRepository {
	// 使用数据库仓储（支持 PostgreSQL, MySQL 等）
	return repositories.NewDBUserRepository(manager.GetDB())
}

// ProvideMenuRepository 提供 MenuRepository
func ProvideMenuRepository(manager *database.Manager) repositories.MenuRepository {
	return repositories.NewMenuRepository(manager.GetDB())
}
