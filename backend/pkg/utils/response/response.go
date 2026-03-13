package response

import (
	"backend/pkg/apperr"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
)

type Response struct {
	Success bool   `json:"success"`
	Code    int    `json:"code,omitempty"` // 业务错误码
	Message string `json:"message,omitempty"`
	Data    any    `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}

// Success 成功响应
func Success(c *gin.Context, data any) {
	c.JSON(http.StatusOK, Response{
		Success: true,
		Code:    200,
		Data:    data,
	})
}

// SuccessWithMessage 成功响应带消息
func SuccessWithMessage(c *gin.Context, message string, data any) {
	c.JSON(http.StatusOK, Response{
		Success: true,
		Code:    200,
		Message: message,
		Data:    data,
	})
}

// SuccessWithData 成功响应带数据（别名函数）
func SuccessWithData(c *gin.Context, message string, data any) {
	SuccessWithMessage(c, message, data)
}

// Error 错误响应（通用函数）
func Error(c *gin.Context, message string, statusCode int) {
	c.JSON(statusCode, Response{
		Success: false,
		Code:    statusCode * 100, // 默认业务码
		Error:   message,
	})
}

// Fail 智能错误响应，自动识别 AppError
func Fail(c *gin.Context, err error) {
	var appErr *apperr.AppError
	if errors.As(err, &appErr) {
		// 根据错误码推断 HTTP 状态码
		httpStatus := http.StatusInternalServerError

		// 简单的映射逻辑：如果错误码是标准的 HTTP 状态码倍数
		if appErr.Code >= 100 && appErr.Code < 600 {
			httpStatus = appErr.Code
		} else if appErr.Code >= 10000 {
			httpStatus = appErr.Code / 100
		}

		c.JSON(httpStatus, Response{
			Success: false,
			Code:    appErr.Code,
			Error:   appErr.Message,
		})
		return
	}

	// 默认处理
	c.JSON(http.StatusInternalServerError, Response{
		Success: false,
		Code:    50000,
		Error:   err.Error(),
	})
}

// Created 创建成功响应
func Created(c *gin.Context, data any) {
	c.JSON(http.StatusCreated, Response{
		Success: true,
		Code:    201,
		Data:    data,
	})
}

// BadRequest 错误请求响应
func BadRequest(c *gin.Context, message string) {
	c.JSON(http.StatusBadRequest, Response{
		Success: false,
		Code:    40000,
		Error:   message,
	})
}

// Unauthorized 未授权响应
func Unauthorized(c *gin.Context, message string) {
	c.JSON(http.StatusUnauthorized, Response{
		Success: false,
		Code:    40100,
		Error:   message,
	})
}

// Forbidden 禁止访问响应
func Forbidden(c *gin.Context, message string) {
	c.JSON(http.StatusForbidden, Response{
		Success: false,
		Code:    40300,
		Error:   message,
	})
}

// NotFound 未找到响应
func NotFound(c *gin.Context, message string) {
	c.JSON(http.StatusNotFound, Response{
		Success: false,
		Code:    40400,
		Error:   message,
	})
}

// InternalError 内部错误响应
func InternalError(c *gin.Context, message string) {
	c.JSON(http.StatusInternalServerError, Response{
		Success: false,
		Code:    50000,
		Error:   message,
	})
}

// ValidationError 验证错误响应
func ValidationError(c *gin.Context, message string) {
	BadRequest(c, message)
}
