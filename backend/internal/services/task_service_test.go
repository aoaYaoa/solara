package services

import (
	"backend/internal/dto"
	"backend/internal/models"
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// MockTaskRepository 是 TaskRepository 的 Mock 实现
type MockTaskRepository struct {
	mock.Mock
}

func (m *MockTaskRepository) GetAll(ctx context.Context) ([]models.Task, error) {
	args := m.Called(ctx)
	return args.Get(0).([]models.Task), args.Error(1)
}

func (m *MockTaskRepository) GetByID(ctx context.Context, id string) (*models.Task, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.Task), args.Error(1)
}

func (m *MockTaskRepository) Create(ctx context.Context, task *models.Task) error {
	args := m.Called(ctx, task)
	return args.Error(0)
}

func (m *MockTaskRepository) Update(ctx context.Context, id string, task *models.Task) error {
	args := m.Called(ctx, id, task)
	return args.Error(0)
}

func (m *MockTaskRepository) Delete(ctx context.Context, id string) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func TestCreateTask(t *testing.T) {
	// 1. 设置 Mock
	mockRepo := new(MockTaskRepository)
	service := NewTaskService(mockRepo)
	ctx := context.Background()

	// 2. 准备测试数据
	req := &dto.CreateTaskRequest{
		Title:       "Test Task",
		Description: "Test Description",
	}

	// 3. 设置期望
	mockRepo.On("Create", ctx, mock.AnythingOfType("*models.Task")).Return(nil)

	// 4. 执行测试
	task, err := service.CreateTask(ctx, req)

	// 5. 验证结果
	assert.NoError(t, err)
	assert.NotNil(t, task)
	assert.Equal(t, "Test Task", task.Title)
	assert.Equal(t, "Test Description", task.Description)
	assert.False(t, task.Completed)

	// 验证 Mock 方法是否被调用
	mockRepo.AssertExpectations(t)
}

func TestCreateTask_EmptyTitle(t *testing.T) {
	mockRepo := new(MockTaskRepository)
	service := NewTaskService(mockRepo)
	ctx := context.Background()

	req := &dto.CreateTaskRequest{
		Title: "",
	}

	task, err := service.CreateTask(ctx, req)

	assert.Error(t, err)
	assert.Nil(t, task)
	assert.Equal(t, "任务标题不能为空", err.Error())
}

func TestGetAllTasks(t *testing.T) {
	mockRepo := new(MockTaskRepository)
	service := NewTaskService(mockRepo)
	ctx := context.Background()

	expectedTasks := []models.Task{
		{Title: "Task 1", Completed: false},
		{Title: "Task 2", Completed: true},
	}

	mockRepo.On("GetAll", ctx).Return(expectedTasks, nil)

	tasks, err := service.GetAllTasks(ctx)

	assert.NoError(t, err)
	assert.Equal(t, 2, len(tasks))
	assert.Equal(t, "Task 1", tasks[0].Title)
}
