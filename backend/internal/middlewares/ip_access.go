package middlewares

import (
	"backend/pkg/utils/logger"
	"net"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	// RealIPHeader 获取真实IP的请求头
	RealIPHeader = "X-Real-IP"

	// ForwardedForHeader 获取转发IP的请求头
	ForwardedForHeader = "X-Forwarded-For"
)

// IPAccessConfig IP访问控制配置
type IPAccessConfig struct {
	// 白名单：允许访问的IP列表（如果设置，则只允许这些IP）
	Whitelist []string

	// 黑名单：禁止访问的IP列表
	Blacklist []string

	// 是否启用白名单模式（true=仅白名单可访问，false=禁用白名单）
	EnableWhitelist bool

	// 是否启用黑名单
	EnableBlacklist bool
}

var (
	// 默认IP访问控制配置
	ipAccessConfig = &IPAccessConfig{
		Whitelist:       []string{},
		Blacklist:       []string{},
		EnableWhitelist: false,
		EnableBlacklist: false,
	}
)

// InitIPAccessConfig 初始化IP访问控制配置
func InitIPAccessConfig(config *IPAccessConfig) {
	if config != nil {
		ipAccessConfig = config
		logger.Infof("[IPAccess] IP访问控制配置已更新")
		logger.Infof("[IPAccess] 白名单模式: %v, 黑名单模式: %v",
			ipAccessConfig.EnableWhitelist, ipAccessConfig.EnableBlacklist)
		if ipAccessConfig.EnableWhitelist {
			logger.Infof("[IPAccess] 白名单: %v", ipAccessConfig.Whitelist)
		}
		if ipAccessConfig.EnableBlacklist {
			logger.Infof("[IPAccess] 黑名单: %v", ipAccessConfig.Blacklist)
		}
	}
}

// IPAccessMiddleware IP访问控制中间件
//
// 支持IP白名单和黑名单功能：
// - 白名单模式：只允许白名单中的IP访问
// - 黑名单模式：禁止黑名单中的IP访问
// - 两种模式可以同时启用
//
// 支持以下IP格式：
// - 完整IP：192.168.1.1
// - CIDR格式：192.168.1.0/24
// - 单个IP段：192.168.1
//
// 使用示例：
//   // 启用白名单
//   InitIPAccessConfig(&IPAccessConfig{
//       EnableWhitelist: true,
//       Whitelist: []string{"192.168.1.1", "10.0.0.0/8"},
//   })
//   router.Use(IPAccessMiddleware())
func IPAccessMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := getClientIP(c)

		// 检查黑名单
		if ipAccessConfig.EnableBlacklist && isIPInBlacklist(clientIP) {
			logger.Warnf("[IPAccess] IP %s 在黑名单中，拒绝访问", clientIP)
			c.JSON(http.StatusForbidden, gin.H{
				"success":   false,
				"error":     "访问被拒绝",
				"requestID": GetRequestID(c),
			})
			c.Abort()
			return
		}

		// 检查白名单
		if ipAccessConfig.EnableWhitelist && !isIPInWhitelist(clientIP) {
			logger.Warnf("[IPAccess] IP %s 不在白名单中，拒绝访问", clientIP)
			c.JSON(http.StatusForbidden, gin.H{
				"success":   false,
				"error":     "访问被拒绝",
				"requestID": GetRequestID(c),
			})
			c.Abort()
			return
		}

		logger.Debugf("[IPAccess] IP %s 访问允许", clientIP)
		c.Next()
	}
}

// getClientIP 获取客户端真实IP
func getClientIP(c *gin.Context) string {
	// 尝试从 X-Real-IP 获取
	if realIP := c.GetHeader(RealIPHeader); realIP != "" {
		return realIP
	}

	// 尝试从 X-Forwarded-For 获取（可能包含多个IP，取第一个）
	if forwardedFor := c.GetHeader(ForwardedForHeader); forwardedFor != "" {
		ips := strings.Split(forwardedFor, ",")
		if len(ips) > 0 {
			return strings.TrimSpace(ips[0])
		}
	}

	// 使用 RemoteAddr
	if ip, _, err := net.SplitHostPort(c.Request.RemoteAddr); err == nil {
		return ip
	}

	return c.Request.RemoteAddr
}

// isIPInBlacklist 检查IP是否在黑名单中
func isIPInBlacklist(ip string) bool {
	for _, rule := range ipAccessConfig.Blacklist {
		if matchIP(ip, rule) {
			return true
		}
	}
	return false
}

// isIPInWhitelist 检查IP是否在白名单中
func isIPInWhitelist(ip string) bool {
	for _, rule := range ipAccessConfig.Whitelist {
		if matchIP(ip, rule) {
			return true
		}
	}
	return false
}

// matchIP 匹配IP地址和规则
// 支持格式：
// - 完整IP：192.168.1.1
// - CIDR：192.168.1.0/24
// - IP段：192.168.1（匹配 192.168.1.*）
func matchIP(ip, rule string) bool {
	// CIDR格式匹配
	if strings.Contains(rule, "/") {
		_, ipNet, err := net.ParseCIDR(rule)
		if err != nil {
			logger.Warnf("[IPAccess] 无效的CIDR规则: %s, err: %v", rule, err)
			return false
		}
		parsedIP := net.ParseIP(ip)
		if parsedIP == nil {
			return false
		}
		return ipNet.Contains(parsedIP)
	}

	// IP段匹配（如：192.168.1 匹配 192.168.1.*）
	if !strings.Contains(rule, ".") {
		return false
	}

	if !strings.Contains(ip, ".") {
		return false
	}

	ruleParts := strings.Split(rule, ".")
	ipParts := strings.Split(ip, ".")

	// 检查IP段匹配
	if len(ruleParts) < 4 {
		for i := 0; i < len(ruleParts); i++ {
			if ruleParts[i] != ipParts[i] {
				return false
			}
		}
		return true
	}

	// 完整IP匹配
	return ip == rule
}
