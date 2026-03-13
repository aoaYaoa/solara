package middlewares

import (
	"backend/pkg/utils/logger"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const (
	RequestIDKey = "X-Request-ID"
)

// RequestID 请求ID中间件，为每个请求生成唯一ID
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 尝试从请求头获取 Request ID
		requestID := c.GetHeader(RequestIDKey)
		if requestID == "" {
			// 如果没有，生成新的 UUID
			requestID = uuid.New().String()
		}

		// 设置到 Context 中
		c.Set(RequestIDKey, requestID)

		// 设置响应头
		c.Header(RequestIDKey, requestID)

		// 在日志中记录 Request ID
		logger.Debugf("[%s] %s %s", requestID, c.Request.Method, c.Request.URL.Path)

		c.Next()
	}
}

// GetRequestID 从 Context 中获取 Request ID
func GetRequestID(c *gin.Context) string {
	if requestID, exists := c.Get(RequestIDKey); exists {
		if id, ok := requestID.(string); ok {
			return id
		}
	}
	return ""
}
