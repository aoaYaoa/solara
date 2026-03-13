package middlewares

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const (
	TraceIDKey       = "X-Trace-ID"
	traceparentKey   = "traceparent"
	traceIDMinLength = 16
)

// TraceID 中间件：从请求头透传或生成 Trace ID，并写回响应头。
func TraceID() gin.HandlerFunc {
	return func(c *gin.Context) {
		traceID := strings.TrimSpace(c.GetHeader(TraceIDKey))
		if traceID == "" {
			traceID = extractTraceIDFromTraceparent(c.GetHeader(traceparentKey))
		}
		if traceID == "" {
			traceID = uuid.NewString()
		}

		c.Set(TraceIDKey, traceID)
		c.Header(TraceIDKey, traceID)
		c.Next()
	}
}

// GetTraceID 从 Context 中获取 Trace ID。
func GetTraceID(c *gin.Context) string {
	if traceID, exists := c.Get(TraceIDKey); exists {
		if id, ok := traceID.(string); ok {
			return id
		}
	}
	return ""
}

func extractTraceIDFromTraceparent(v string) string {
	parts := strings.Split(strings.TrimSpace(v), "-")
	// traceparent: version-traceid-spanid-flags
	if len(parts) != 4 {
		return ""
	}
	traceID := strings.TrimSpace(parts[1])
	if len(traceID) < traceIDMinLength {
		return ""
	}
	return traceID
}
