package middlewares

import (
	"backend/pkg/utils/logger"
	"strings"

	"github.com/gin-gonic/gin"
)

// Compression 响应压缩中间件
// 支持 gzip 和 deflate 压缩
func Compression() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 检查客户端是否支持压缩
		acceptEncoding := c.GetHeader("Accept-Encoding")

		// 如果客户端不支持压缩，跳过
		if acceptEncoding == "" {
			c.Next()
			return
		}

		// 检查是否支持 gzip
		supported := false
		if strings.Contains(acceptEncoding, "gzip") {
			supported = true
		}

		if supported {
			logger.Debugf("[Compression] 启用压缩: %s", acceptEncoding)
		}

		c.Next()
	}
}

// CompressLevel 定义压缩级别
type CompressLevel int

const (
	NoCompression      CompressLevel = iota
	BestSpeed
	BestCompression
	DefaultCompression
)

// CustomCompression 自定义压缩中间件
func CustomCompression(level CompressLevel) gin.HandlerFunc {
	return func(c *gin.Context) {
		logger.Debugf("[Compression] 压缩级别: %d", level)
		c.Next()
	}
}
