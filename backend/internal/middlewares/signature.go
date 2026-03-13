package middlewares

import (
	"backend/internal/config"
	"backend/pkg/utils/logger"
	"backend/pkg/utils/crypto"
	"bytes"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	// SignatureHeader 签名请求头
	SignatureHeader = "X-Signature"

	// TimestampHeader 时间戳请求头
	TimestampHeader = "X-Timestamp"

	// 签名有效期（5分钟）
	signatureMaxAge = 5 * time.Minute
)

// SignatureMiddleware API 签名验证中间件
//
// 验证请求签名，确保请求的完整性和真实性
//
// 签名规则：HMAC-SHA256(method + url + body + timestamp)
//
// 使用示例：
//   router.Use(middlewares.SignatureMiddleware())
//
// 请求头格式：
//   X-Signature: <hmac-sha256-signature>
//   X-Timestamp: <unix-timestamp>
//
// 注意事项：
//   - 签名验证失败会返回 401 错误
//   - 超时的签名会被拒绝（防止重放攻击）
//   - 需要与前端使用相同的签名密钥
func SignatureMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取请求签名
		signature := c.GetHeader(SignatureHeader)
		if signature == "" {
			logger.Warn("[Signature] 缺少签名")
			c.JSON(http.StatusUnauthorized, gin.H{
				"success":   false,
				"error":     "缺少签名",
				"requestID": GetRequestID(c),
			})
			c.Abort()
			return
		}

		// 获取时间戳
		timestamp := c.GetHeader(TimestampHeader)
		if timestamp == "" {
			logger.Warn("[Signature] 缺少时间戳")
			c.JSON(http.StatusUnauthorized, gin.H{
				"success":   false,
				"error":     "缺少时间戳",
				"requestID": GetRequestID(c),
			})
			c.Abort()
			return
		}

		// 验证时间戳（防止重放攻击）
		if err := validateTimestamp(timestamp); err != nil {
			logger.Warnf("[Signature] 时间戳验证失败: %v", err)
			c.JSON(http.StatusUnauthorized, gin.H{
				"success":   false,
				"error":     "签名已过期",
				"requestID": GetRequestID(c),
			})
			c.Abort()
			return
		}

		// 生成待签名字符串
		// 格式：method + url + body + timestamp
		signString, err := buildSignString(c, timestamp)
		if err != nil {
			logger.Errorf("[Signature] 构建签名字符串失败: %v", err)
			c.JSON(http.StatusBadRequest, gin.H{
				"success":   false,
				"error":     "签名验证失败",
				"requestID": GetRequestID(c),
			})
			c.Abort()
			return
		}

		// 计算 HMAC-SHA256 签名
		secretKey := config.AppConfig.SignatureSecret
		expectedSignature := crypto.HMACSHA256(secretKey, signString)

		// 验证签名
		if signature != expectedSignature {
			logger.Warnf("[Signature] 签名验证失败\n期望: %s\n实际: %s", expectedSignature, signature)
			c.JSON(http.StatusUnauthorized, gin.H{
				"success":   false,
				"error":     "签名验证失败",
				"requestID": GetRequestID(c),
			})
			c.Abort()
			return
		}

		// 签名验证成功
		logger.Debugf("[Signature] 签名验证成功: %s", signature[:min(len(signature), 16)]+"...")
		c.Next()
	}
}

// OptionalSignatureMiddleware 可选签名验证中间件
//
// 验证签名，但如果缺少签名也不拒绝请求
// 适用于某些接口支持签名的场景
func OptionalSignatureMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		signature := c.GetHeader(SignatureHeader)
		timestamp := c.GetHeader(TimestampHeader)

		// 如果提供了签名，进行验证
		if signature != "" && timestamp != "" {
			// 验证时间戳
			if err := validateTimestamp(timestamp); err != nil {
				logger.Warnf("[OptionalSignature] 时间戳验证失败: %v", err)
				c.Set("signature_error", "签名已过期")
				c.Next()
				return
			}

			// 构建签名字符串
			signString, err := buildSignString(c, timestamp)
			if err != nil {
				logger.Errorf("[OptionalSignature] 构建签名字符串失败: %v", err)
				c.Set("signature_error", "签名验证失败")
				c.Next()
				return
			}

			// 计算并验证签名
			secretKey := config.AppConfig.SignatureSecret
			expectedSignature := crypto.HMACSHA256(secretKey, signString)
			if signature != expectedSignature {
				logger.Warnf("[OptionalSignature] 签名验证失败")
				c.Set("signature_error", "签名验证失败")
			} else {
				logger.Debugf("[OptionalSignature] 签名验证成功")
				c.Set("signature_valid", true)
			}
		}

		c.Next()
	}
}

// validateTimestamp 验证时间戳是否在有效期内
func validateTimestamp(timestamp string) error {
	// 转换为 Unix 时间戳（秒）
	var ts int64
	_, err := fmt.Sscanf(timestamp, "%d", &ts)
	if err != nil {
		return err
	}

	// 计算时间差
	now := time.Now().Unix()
	diff := now - ts

	// 检查是否超时（前后5分钟）
	if diff < -300 || diff > 300 {
		return fmt.Errorf("时间戳超出有效期范围: %d 秒", diff)
	}

	return nil
}

// buildSignString 构建待签名字符串
//
// 格式：method + url + body + timestamp
func buildSignString(c *gin.Context, timestamp string) (string, error) {
	// 获取请求方法
	method := c.Request.Method

	// 获取请求 URL（包含查询参数）
	url := c.Request.URL.Path
	if c.Request.URL.RawQuery != "" {
		url += "?" + c.Request.URL.RawQuery
	}

	// 获取请求体
	body, err := getRequestBody(c)
	if err != nil {
		return "", err
	}

	// 构建签名字符串
	// 格式：method + url + body + timestamp
	signString := fmt.Sprintf("%s%s%s%s", method, url, body, timestamp)

	return signString, nil
}

// getRequestBody 获取请求体
//
// 注意：只能读取一次请求体，读取后需要重置
func getRequestBody(c *gin.Context) (string, error) {
	if c.Request.Body == nil {
		return "", nil
	}

	// 读取请求体
	bodyBytes, err := io.ReadAll(c.Request.Body)
	if err != nil {
		return "", err
	}

	// 重置请求体（以便后续处理）
	c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

	// 转换为字符串
	return string(bodyBytes), nil
}
