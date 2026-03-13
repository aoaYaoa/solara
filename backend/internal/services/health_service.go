package services

import (
	"context"
	"time"
)

type HealthService interface {
	CheckHealth(ctx context.Context) map[string]any
}

type DependencyCheck struct {
	Enabled bool
	Check   func(context.Context) error
}

type healthServiceImpl struct {
	dependencies map[string]DependencyCheck
}

// NewHealthService 创建健康检查服务实例
func NewHealthService(dependencies map[string]DependencyCheck) HealthService {
	if dependencies == nil {
		dependencies = map[string]DependencyCheck{}
	}
	return &healthServiceImpl{
		dependencies: dependencies,
	}
}

func (s *healthServiceImpl) CheckHealth(ctx context.Context) map[string]any {
	if ctx == nil {
		ctx = context.Background()
	}

	overallStatus := "ok"
	components := map[string]any{}

	for name, dep := range s.dependencies {
		component := map[string]any{}
		if !dep.Enabled {
			component["status"] = "disabled"
			components[name] = component
			continue
		}

		if dep.Check == nil {
			component["status"] = "down"
			component["error"] = "health check is not configured"
			overallStatus = "degraded"
			components[name] = component
			continue
		}

		checkCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		err := dep.Check(checkCtx)
		cancel()
		if err != nil {
			component["status"] = "down"
			component["error"] = err.Error()
			overallStatus = "degraded"
		} else {
			component["status"] = "up"
		}
		components[name] = component
	}

	message := "服务器运行正常"
	if overallStatus != "ok" {
		message = "部分依赖不可用"
	}

	return map[string]any{
		"status":     overallStatus,
		"message":    message,
		"service":    "go-gin-api",
		"timestamp":  time.Now().Format(time.RFC3339),
		"components": components,
	}
}
