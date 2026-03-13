package middlewares

import (
	"backend/pkg/utils/logger"
	"backend/pkg/utils/response"
	"time"

	"github.com/gin-gonic/gin"
)

// Logger 日志中间件
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()
		method := c.Request.Method
		ip := c.ClientIP()
		reqID := c.Writer.Header().Get("X-Request-ID")
		traceID := c.Writer.Header().Get("X-Trace-ID")

		if query != "" {
			path = path + "?" + query
		}

		logger.Infof("[%s] [%s] [%s] %s %s %d %v", reqID, traceID, ip, method, path, status, latency)
	}
}

// Recovery 恢复中间件
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				logger.Errorf("Panic recovered: %v", err)
				response.InternalError(c, "Internal Server Error")
				c.Abort()
			}
		}()
		c.Next()
	}
}
