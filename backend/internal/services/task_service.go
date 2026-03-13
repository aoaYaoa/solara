package services

import (
	"backend/internal/dto"
	"backend/internal/models"
	"backend/internal/repositories"
	"backend/pkg/apperr"
	"context"
)

type TaskService interface {
	GetAllTasks(ctx context.Context) ([]models.Task, error)
	GetTaskByID(ctx context.Context, id string) (*models.Task, error)
	CreateTask(ctx context.Context, req *dto.CreateTaskRequest) (*models.Task, error)
	UpdateTask(ctx context.Context, id string, req *dto.UpdateTaskRequest) (*models.Task, error)
	DeleteTask(ctx context.Context, id string) error
}

type taskServiceImpl struct {
	repo repositories.TaskRepository
}

// NewTaskService 创建任务服务实例
func NewTaskService(repo repositories.TaskRepository) TaskService {
	return &taskServiceImpl{
		repo: repo,
	}
}

func (s *taskServiceImpl) GetAllTasks(ctx context.Context) ([]models.Task, error) {
	tasks, err := s.repo.GetAll(ctx)
	if err != nil {
		return nil, apperr.NewInternalError(err)
	}
	return tasks, nil
}

func (s *taskServiceImpl) GetTaskByID(ctx context.Context, id string) (*models.Task, error) {
	task, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, apperr.NewNotFound("任务不存在")
	}
	return task, nil
}

func (s *taskServiceImpl) CreateTask(ctx context.Context, req *dto.CreateTaskRequest) (*models.Task, error) {
	if req.Title == "" {
		return nil, apperr.NewBadRequest("任务标题不能为空")
	}

	task := &models.Task{
		Title:       req.Title,
		Description: req.Description,
		Completed:   false,
	}

	if err := s.repo.Create(ctx, task); err != nil {
		return nil, apperr.NewInternalError(err)
	}

	return task, nil
}

func (s *taskServiceImpl) UpdateTask(ctx context.Context, id string, req *dto.UpdateTaskRequest) (*models.Task, error) {
	task, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, apperr.NewNotFound("任务不存在")
	}

	if req.Title != nil {
		task.Title = *req.Title
	}
	if req.Description != nil {
		task.Description = *req.Description
	}
	if req.Completed != nil {
		task.Completed = *req.Completed
	}

	if err := s.repo.Update(ctx, id, task); err != nil {
		return nil, apperr.NewInternalError(err)
	}

	return task, nil
}

func (s *taskServiceImpl) DeleteTask(ctx context.Context, id string) error {
	if err := s.repo.Delete(ctx, id); err != nil {
		// 这里假设 repo Delete 失败是因为不存在，或者你可以进一步检查错误类型
		// 但通常如果是 SQL 错误，最好认为是 InternalError
		// 简单起见，如果 repo 明确返回 fetch error，我们用 NotFound
		return apperr.NewNotFound("任务不存在")
	}
	return nil
}
