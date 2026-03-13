package dto

import (
	"backend/internal/models"
	"time"
)

type CreateTaskRequest struct {
	Title       string `json:"title" binding:"required,min=1,max=100"`
	Description string `json:"description" binding:"max=500"`
}

type UpdateTaskRequest struct {
	Title       *string `json:"title" binding:"omitempty,min=1,max=100"`
	Description *string `json:"description" binding:"omitempty,max=500"`
	Completed   *bool   `json:"completed"`
}

type TaskResponse struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Completed   bool      `json:"completed"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func ToTaskResponse(task *models.Task) *TaskResponse {
	return &TaskResponse{
		ID:          task.ID,
		Title:       task.Title,
		Description: task.Description,
		Completed:   task.Completed,
		CreatedAt:   task.CreatedAt,
		UpdatedAt:   task.UpdatedAt,
	}
}

func ToTaskResponseList(tasks []models.Task) []TaskResponse {
	list := make([]TaskResponse, len(tasks))
	for i, task := range tasks {
		list[i] = *ToTaskResponse(&task)
	}
	return list
}
