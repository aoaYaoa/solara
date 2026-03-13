package repositories

import (
	"backend/internal/models"
	"context"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
)

var (
	taskRepositoryInstance TaskRepository
	once                   sync.Once
)

type TaskRepository interface {
	GetAll(ctx context.Context) ([]models.Task, error)
	GetByID(ctx context.Context, id string) (*models.Task, error)
	Create(ctx context.Context, task *models.Task) error
	Update(ctx context.Context, id string, task *models.Task) error
	Delete(ctx context.Context, id string) error
}

type taskRepositoryImpl struct {
	tasks map[string]models.Task
	mu    sync.RWMutex
}

// NewTaskRepository 创建任务仓储实例
func NewTaskRepository() TaskRepository {
	once.Do(func() {
		impl := &taskRepositoryImpl{
			tasks: make(map[string]models.Task),
		}
		// 初始化示例数据
		impl.InitializeData()
		taskRepositoryInstance = impl
	})
	return taskRepositoryInstance
}

// InitializeData 初始化示例数据
func (r *taskRepositoryImpl) InitializeData() {
	now := time.Now()
	sampleTasks := []models.Task{
		{
			ID:          "1",
			Title:       "学习 Go-Gin",
			Description: "学习 Go-Gin 框架的基础知识",
			Completed:   false,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		{
			ID:          "2",
			Title:       "学习 React 19",
			Description: "学习 React 19 的新特性",
			Completed:   true,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	for _, task := range sampleTasks {
		r.tasks[task.ID] = task
	}
}

func (r *taskRepositoryImpl) GetAll(ctx context.Context) ([]models.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	tasks := make([]models.Task, 0, len(r.tasks))
	for _, task := range r.tasks {
		tasks = append(tasks, task)
	}
	return tasks, nil
}

func (r *taskRepositoryImpl) GetByID(ctx context.Context, id string) (*models.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	task, exists := r.tasks[id]
	if !exists {
		return nil, errors.New("任务不存在")
	}
	return &task, nil
}

func (r *taskRepositoryImpl) Create(ctx context.Context, task *models.Task) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	task.ID = generateID()
	task.CreatedAt = time.Now()
	task.UpdatedAt = time.Now()

	r.tasks[task.ID] = *task
	return nil
}

func (r *taskRepositoryImpl) Update(ctx context.Context, id string, task *models.Task) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	existingTask, exists := r.tasks[id]
	if !exists {
		return errors.New("任务不存在")
	}

	// 只更新允许的字段
	existingTask.Title = task.Title
	existingTask.Description = task.Description
	existingTask.Completed = task.Completed
	existingTask.UpdatedAt = time.Now()

	r.tasks[id] = existingTask
	return nil
}

func (r *taskRepositoryImpl) Delete(ctx context.Context, id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.tasks[id]; !exists {
		return errors.New("任务不存在")
	}

	delete(r.tasks, id)
	return nil
}

func generateID() string {
	return uuid.New().String()
}
