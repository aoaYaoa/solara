package apperr

import "fmt"

// AppError 自定义应用错误
type AppError struct {
	Code    int    `json:"code"`    // 错误码
	Message string `json:"message"` // 错误消息
	Err     error  `json:"-"`       // 原始错误
}

// Error 实现 error 接口
func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s: %v", e.Message, e.Err)
	}
	return e.Message
}

// Unwrap 返回原始错误
func (e *AppError) Unwrap() error {
	return e.Err
}

// New 创建一个新的 AppError
func New(code int, message string) *AppError {
	return &AppError{
		Code:    code,
		Message: message,
	}
}

// Wrap 在现有错误上包装 AppError
func Wrap(err error, code int, message string) *AppError {
	return &AppError{
		Code:    code,
		Message: message,
		Err:     err,
	}
}

// 常用业务错误码定义
const (
	ErrCodeBadRequest          = 40000 // 请求参数错误
	ErrCodeUnauthorized        = 40100 // 未授权
	ErrCodeForbidden           = 40300 // 禁止访问
	ErrCodeNotFound            = 40400 // 资源不存在
	ErrCodeInternalServerError = 50000 // 服务器内部错误
	ErrCodeConflict            = 40900 // 资源冲突
)

// 常用错误构造函数
var (
	ErrBadRequest          = New(ErrCodeBadRequest, "请求参数错误")
	ErrUnauthorized        = New(ErrCodeUnauthorized, "未授权")
	ErrForbidden           = New(ErrCodeForbidden, "无权访问")
	ErrNotFound            = New(ErrCodeNotFound, "资源不存在")
	ErrInternalServerError = New(ErrCodeInternalServerError, "服务器内部错误")
)

// NewBadRequest 创建参数错误
func NewBadRequest(message string) *AppError {
	return New(ErrCodeBadRequest, message)
}

// NewNotFound 创建未找到错误
func NewNotFound(message string) *AppError {
	return New(ErrCodeNotFound, message)
}

// NewInternalError 创建内部错误
func NewInternalError(err error) *AppError {
	return Wrap(err, ErrCodeInternalServerError, "服务器内部错误")
}
