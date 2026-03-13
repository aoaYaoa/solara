package middlewares

import (
	"backend/pkg/utils/logger"

	"github.com/gin-gonic/gin"
)

// Security 安全中间件，设置安全相关的 HTTP 响应头
func Security() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 防止点击劫持
		c.Header("X-Frame-Options", "DENY")

		// 防止 MIME 类型嗅探
		c.Header("X-Content-Type-Options", "nosniff")

		// XSS 保护
		c.Header("X-XSS-Protection", "1; mode=block")

		// 内容安全策略（根据实际情况调整）
		c.Header(
			"Content-Security-Policy",
			"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';",
		)

		// 严格传输安全（仅限 HTTPS）
		// c.Header("Strict-Transport-Security", "max-age=63072000; includeSubDomains")

		// 引用策略
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")

		// 权限策略
		c.Header("Permissions-Policy", "geolocation=(), microphone=(), camera=()")

		logger.Debugf("[Security] 设置安全响应头")
		c.Next()
	}
}

// NoCache 禁用缓存中间件
func NoCache() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Cache-Control", "no-cache, no-store, max-age=0, must-revalidate")
		c.Header("Pragma", "no-cache")
		c.Header("Expires", "0")

		c.Next()
	}
}

// ContentType 内容类型检查中间件
func ContentType() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 对于 POST, PUT, PATCH 请求，要求 Content-Type 为 application/json
		if c.Request.Method == "POST" || c.Request.Method == "PUT" || c.Request.Method == "PATCH" {
			contentType := c.GetHeader("Content-Type")
			if contentType != "" && contentType != "application/json" {
				logger.Warnf("[ContentType] 不支持的 Content-Type: %s", contentType)
				c.JSON(415, gin.H{
					"success": false,
					"error":   "不支持的媒体类型",
				})
				c.Abort()
				return
			}
		}

		c.Next()
	}
}
