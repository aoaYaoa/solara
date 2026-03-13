package middlewares

import (
	"backend/pkg/utils/jwt"
	"backend/pkg/utils/logger"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	// AuthHeader 认证头
	AuthHeader = "Authorization"
	// BearerPrefix Bearer 前缀
	BearerPrefix = "Bearer "
)

// AuthMiddleware JWT 认证中间件
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取 Authorization 头
		authHeader := c.GetHeader(AuthHeader)

		// 检查是否存在
		if authHeader == "" {
			logger.Warn("[Auth] 缺少 Authorization 头")
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "未提供认证令牌",
			})
			c.Abort()
			return
		}

		// 检查 Bearer 前缀
		if !strings.HasPrefix(authHeader, BearerPrefix) {
			logger.Warnf("[Auth] 无效的 Authorization 格式: %s", authHeader)
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "无效的认证令牌格式",
			})
			c.Abort()
			return
		}

		// 提取令牌
		token := strings.TrimPrefix(authHeader, BearerPrefix)
		if token == "" {
			logger.Warn("[Auth] 空的认证令牌")
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "认证令牌不能为空",
			})
			c.Abort()
			return
		}

		// 验证 JWT 令牌
		claims, err := jwt.ValidateToken(token, "")
		if err != nil {
			logger.Warnf("[Auth] 令牌验证失败: %v", err)
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "无效的认证令牌",
			})
			c.Abort()
			return
		}

		// 将用户信息存储到 Context 中
		c.Set("user_id", claims.UserID)
		c.Set("username", claims.Username)
		c.Set("role", claims.Role)
		c.Set("claims", claims)

		logger.Debugf("[Auth] 认证成功: user_id=%s, username=%s", claims.UserID, claims.Username)

		c.Next()
	}
}

// OptionalAuth 可选认证中间件
// 用户可以选择是否提供认证令牌
func OptionalAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader(AuthHeader)

		if authHeader != "" {
			if strings.HasPrefix(authHeader, BearerPrefix) {
				token := strings.TrimPrefix(authHeader, BearerPrefix)
				if token != "" {
					// 尝试验证令牌
					if claims, err := jwt.ValidateToken(token, ""); err == nil {
						// 验证成功，存储用户信息
						c.Set("user_id", claims.UserID)
						c.Set("username", claims.Username)
						c.Set("role", claims.Role)
						c.Set("claims", claims)
						logger.Debugf("[OptionalAuth] 检测到有效认证令牌: user_id=%s", claims.UserID)
					} else {
						logger.Debugf("[OptionalAuth] 检测到无效认证令牌: %s", token[:min(len(token), 10)]+"...")
					}
				}
			}
		}

		c.Next()
	}
}

// RoleBasedAuth 基于角色的认证中间件
func RoleBasedAuth(requiredRoles []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 先进行认证
		authHeader := c.GetHeader(AuthHeader)
		if authHeader == "" {
			logger.Warn("[RoleBasedAuth] 缺少认证令牌")
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "未认证",
			})
			c.Abort()
			return
		}

		// 检查 Bearer 前缀
		if !strings.HasPrefix(authHeader, BearerPrefix) {
			logger.Warn("[RoleBasedAuth] 无效的认证令牌格式")
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "无效的认证令牌格式",
			})
			c.Abort()
			return
		}

		// 提取令牌
		token := strings.TrimPrefix(authHeader, BearerPrefix)
		if token == "" {
			logger.Warn("[RoleBasedAuth] 空的认证令牌")
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "认证令牌不能为空",
			})
			c.Abort()
			return
		}

		// 验证令牌
		claims, err := jwt.ValidateToken(token, "")
		if err != nil {
			logger.Warnf("[RoleBasedAuth] 令牌验证失败: %v", err)
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "无效的认证令牌",
			})
			c.Abort()
			return
		}

		// 检查用户角色
		if !hasRequiredRole(claims.Role, requiredRoles) {
			logger.Warnf("[RoleBasedAuth] 权限不足: user_role=%s, required=%v", claims.Role, requiredRoles)
			c.JSON(http.StatusForbidden, gin.H{
				"success": false,
				"error":   "权限不足",
			})
			c.Abort()
			return
		}

		// 将用户信息存储到 Context 中
		c.Set("user_id", claims.UserID)
		c.Set("username", claims.Username)
		c.Set("role", claims.Role)
		c.Set("claims", claims)

		logger.Debugf("[RoleBasedAuth] 角色验证通过: role=%s", claims.Role)

		c.Next()
	}
}

// hasRequiredRole 检查用户是否有所需的角色
func hasRequiredRole(userRole string, requiredRoles []string) bool {
	for _, role := range requiredRoles {
		if strings.EqualFold(userRole, role) {
			return true
		}
	}
	return false
}

// GetTokenFromRequest 从请求中获取令牌
func GetTokenFromRequest(c *gin.Context) (string, error) {
	authHeader := c.GetHeader(AuthHeader)
	if authHeader == "" {
		return "", http.ErrNoCookie
	}

	if !strings.HasPrefix(authHeader, BearerPrefix) {
		return "", http.ErrNoCookie
	}

	token := strings.TrimPrefix(authHeader, BearerPrefix)
	if token == "" {
		return "", http.ErrNoCookie
	}

	return token, nil
}
