package handlers

import (
	"backend/internal/dto"
	"backend/internal/services"
	"backend/pkg/utils/logger"
	"backend/pkg/utils/response"

	"github.com/gin-gonic/gin"
)

type TaskHandler interface {
	GetAllTasks(c *gin.Context)
	GetTask(c *gin.Context)
	CreateTask(c *gin.Context)
	UpdateTask(c *gin.Context)
	DeleteTask(c *gin.Context)
	ToggleTask(c *gin.Context)
}

type taskHandler struct {
	service services.TaskService
}

// NewTaskHandler 创建任务处理器实例
func NewTaskHandler(service services.TaskService) TaskHandler {
	return &taskHandler{
		service: service,
	}
}

// GetAllTasks 获取所有任务
func (h *taskHandler) GetAllTasks(c *gin.Context) {
	tasks, err := h.service.GetAllTasks(c.Request.Context())
	if err != nil {
		logger.Errorf("获取任务失败: %v", err)
		response.Fail(c, err)
		return
	}

	response.Success(c, dto.ToTaskResponseList(tasks))
}

// GetTask 获取单个任务
func (h *taskHandler) GetTask(c *gin.Context) {
	id := c.Param("id")

	task, err := h.service.GetTaskByID(c.Request.Context(), id)
	if err != nil {
		logger.Errorf("获取任务失败: %v", err)
		response.Fail(c, err)
		return
	}

	response.Success(c, dto.ToTaskResponse(task))
}

// CreateTask 创建任务
func (h *taskHandler) CreateTask(c *gin.Context) {
	var req dto.CreateTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Errorf("绑定请求失败: %v", err)
		response.ValidationError(c, "无效的请求数据")
		return
	}

	task, err := h.service.CreateTask(c.Request.Context(), &req)
	if err != nil {
		logger.Errorf("创建任务失败: %v", err)
		response.Fail(c, err)
		return
	}

	response.Created(c, dto.ToTaskResponse(task))
}

// UpdateTask 更新任务
func (h *taskHandler) UpdateTask(c *gin.Context) {
	id := c.Param("id")

	var req dto.UpdateTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Errorf("绑定请求失败: %v", err)
		response.ValidationError(c, "无效的请求数据")
		return
	}

	task, err := h.service.UpdateTask(c.Request.Context(), id, &req)
	if err != nil {
		logger.Errorf("更新任务失败: %v", err)
		response.Fail(c, err)
		return
	}

	response.Success(c, dto.ToTaskResponse(task))
}

// DeleteTask 删除任务
func (h *taskHandler) DeleteTask(c *gin.Context) {
	id := c.Param("id")

	if err := h.service.DeleteTask(c.Request.Context(), id); err != nil {
		logger.Errorf("删除任务失败: %v", err)
		response.Fail(c, err)
		return
	}

	response.SuccessWithMessage(c, "任务已删除", gin.H{"id": id})
}

// ToggleTask 切换任务完成状态
func (h *taskHandler) ToggleTask(c *gin.Context) {
	id := c.Param("id")

	task, err := h.service.GetTaskByID(c.Request.Context(), id)
	if err != nil {
		logger.Errorf("获取任务失败: %v", err)
		response.NotFound(c, "任务不存在")
		return
	}

	completed := !task.Completed
	updateReq := dto.UpdateTaskRequest{
		Completed: &completed,
	}

	updatedTask, err := h.service.UpdateTask(c.Request.Context(), id, &updateReq)
	if err != nil {
		logger.Errorf("更新任务失败: %v", err)
		response.Fail(c, err)
		return
	}

	response.Success(c, dto.ToTaskResponse(updatedTask))
}
