package container

import (
	"backend/internal/config"
	"backend/internal/database"
	"backend/internal/handlers"
	"backend/internal/messaging"
	"backend/internal/repositories"
	"backend/internal/routes"
	"backend/internal/services"
	"backend/pkg/utils/captcha"
	"context"
	"errors"
	"fmt"
)

// Container 依赖注入容器
type Container struct {
	Router *routes.Router
}

// ModuleHolders 内部结构，用于在初始化过程中传递模块
type repositoriesHolder struct {
	Task repositories.TaskRepository
	User repositories.UserRepository
	Menu repositories.MenuRepository
}

type servicesHolder struct {
	Task   services.TaskService
	User   services.UserService
	Health services.HealthService
}

// InitializeContainer 初始化容器
// 采用分层初始化的方式，避免主函数过于臃肿
func InitializeContainer(manager *database.Manager, publisher messaging.EventPublisher) (*Container, error) {
	// 1. 初始化 Repositories
	repos := initRepositories(manager)

	// 2. 初始化 Services
	svcs := initServices(repos, manager, publisher)

	// 3. 初始化 Handlers
	h := initHandlers(svcs, manager)

	// 4. 初始化 Router
	router := routes.NewRouter(h)

	return &Container{
		Router: router,
	}, nil
}

// initRepositories 初始化所有 Repository
func initRepositories(manager *database.Manager) *repositoriesHolder {
	return &repositoriesHolder{
		Task: ProvideTaskRepository(manager),
		User: ProvideUserRepository(manager),
		Menu: ProvideMenuRepository(manager),
	}
}

// initServices 初始化所有 Service
func initServices(repos *repositoriesHolder, manager *database.Manager, publisher messaging.EventPublisher) *servicesHolder {
	healthChecks := map[string]services.DependencyCheck{
		"database": {
			Enabled: true,
			Check: func(ctx context.Context) error {
				return manager.Ping(ctx)
			},
		},
		"redis": {
			Enabled: config.AppConfig.RedisAddr != "",
			Check: func(ctx context.Context) error {
				storeType := captcha.StoreType()
				if storeType != "redis" {
					return fmt.Errorf("redis configured but captcha store is %s", storeType)
				}
				return captcha.CheckStoreHealth(ctx)
			},
		},
		"kafka": {
			Enabled: config.AppConfig.KafkaBrokers != "" && config.AppConfig.KafkaTopic != "",
			Check: func(ctx context.Context) error {
				if publisher == nil {
					return errors.New("kafka publisher is nil")
				}
				if err := publisher.HealthCheck(ctx); err != nil {
					if errors.Is(err, messaging.ErrPublisherDisabled) {
						return errors.New("kafka publisher is disabled")
					}
					return err
				}
				return nil
			},
		},
	}

	return &servicesHolder{
		Task:   services.NewTaskService(repos.Task),
		User:   services.NewUserService(repos.User, repos.Menu, publisher),
		Health: services.NewHealthService(healthChecks),
	}
}

// initHandlers 初始化所有 Handler 并组装成 Handlers 结构体
func initHandlers(svcs *servicesHolder, manager *database.Manager) *handlers.Handlers {
	return &handlers.Handlers{
		Task:    handlers.NewTaskHandler(svcs.Task),
		User:    handlers.NewUserHandler(svcs.User),
		Health:  handlers.NewHealthHandler(svcs.Health),
		Captcha: handlers.NewCaptchaHandler(),
		Solara:  handlers.NewSolaraHandler(manager.GetDB()),
	}
}
