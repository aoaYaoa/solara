package repositories

import (
	"backend/internal/models"
	"backend/pkg/utils/logger"
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// DBTaskRepository 数据库任务仓储实现
// 使用GORM ORM框架与数据库交互，实现TaskRepository接口
type DBTaskRepository struct {
	db *gorm.DB
}

// NewDBTaskRepository 创建数据库任务仓储实例
func NewDBTaskRepository(db *gorm.DB) TaskRepository {
	return &DBTaskRepository{
		db: db,
	}
}

// GetAll 获取所有任务
// 实现TaskRepository接口方法
func (r *DBTaskRepository) GetAll(ctx context.Context) ([]models.Task, error) {
	var tasks []models.Task
	if err := r.db.WithContext(ctx).Order("created_at desc").Find(&tasks).Error; err != nil {
		logger.Errorf("获取所有任务失败: %v", err)
		return nil, errors.New("获取所有任务失败: " + err.Error())
	}
	return tasks, nil
}

// GetByID 根据ID获取任务
// 实现TaskRepository接口方法
func (r *DBTaskRepository) GetByID(ctx context.Context, id string) (*models.Task, error) {
	var task models.Task
	if err := r.db.WithContext(ctx).Where("id = ?", id).First(&task).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("任务不存在")
		}
		logger.Errorf("根据ID查找任务失败: %v", err)
		return nil, err
	}
	return &task, nil
}

// Create 创建任务
// 实现TaskRepository接口方法，自动生成ID和时间戳
func (r *DBTaskRepository) Create(ctx context.Context, task *models.Task) error {
	// 生成ID（使用 UUID）
	task.ID = uuid.New().String()
	now := time.Now()
	task.CreatedAt = now
	task.UpdatedAt = now

	if err := r.db.WithContext(ctx).Create(task).Error; err != nil {
		logger.Errorf("创建任务失败: %v", err)
		return errors.New("创建任务失败: " + err.Error())
	}

	logger.Infof("任务创建成功: ID=%s, Title=%s", task.ID, task.Title)
	return nil
}

// Update 更新任务
// 实现TaskRepository接口方法
func (r *DBTaskRepository) Update(ctx context.Context, id string, task *models.Task) error {
	// 检查任务是否存在
	var existingTask models.Task
	if err := r.db.WithContext(ctx).Where("id = ?", id).First(&existingTask).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("任务不存在")
		}
		logger.Errorf("查找任务失败: %v", err)
		return err
	}

	// 更新任务
	task.ID = id
	task.CreatedAt = existingTask.CreatedAt
	task.UpdatedAt = time.Now()

	if err := r.db.WithContext(ctx).Save(task).Error; err != nil {
		logger.Errorf("更新任务失败: %v", err)
		return errors.New("更新任务失败: " + err.Error())
	}

	logger.Infof("任务更新成功: ID=%s", id)
	return nil
}

// Delete 删除任务
// 实现TaskRepository接口方法
func (r *DBTaskRepository) Delete(ctx context.Context, id string) error {
	result := r.db.WithContext(ctx).Where("id = ?", id).Delete(&models.Task{})
	if result.Error != nil {
		logger.Errorf("删除任务失败: %v", result.Error)
		return errors.New("删除任务失败: " + result.Error.Error())
	}
	if result.RowsAffected == 0 {
		return errors.New("任务不存在")
	}

	logger.Infof("任务删除成功: ID=%s", id)
	return nil
}
