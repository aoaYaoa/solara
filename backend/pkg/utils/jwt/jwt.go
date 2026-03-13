package jwt

import (
	"backend/pkg/utils/logger"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	jwtv5 "github.com/golang-jwt/jwt/v5"
)

const (
	// TokenHeader 认证头
	TokenHeader = "Authorization"

	// BearerPrefix Bearer 前缀
	BearerPrefix = "Bearer "

	// 默认过期时间
	defaultExpDuration = 24 * time.Hour

	// Issuer 签发者
	Issuer = "go-gin-backend"

	minSecretLength = 32
)

var weakSecretPlaceholders = map[string]struct{}{
	"your-secret-key-change-in-production": {},
	"your-jwt-secret-key-change-me":        {},
}

var (
	secretMu      sync.RWMutex
	configuredKey string
)

// Claims JWT 声明（Payload）
type Claims struct {
	UserID   string `json:"user_id"` // 使用 string 存储 UUID
	Username string `json:"username"`
	Role     string `json:"role"`
	jwtv5.RegisteredClaims
}

// TokenResponse Token 响应结构
type TokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int64  `json:"expires_in"`
}

// GenerateToken 生成 JWT Token
func GenerateToken(userID string, username string, role string, secret string, duration time.Duration) (string, error) {
	resolvedSecret, err := resolveSecret(secret)
	if err != nil {
		return "", err
	}

	if duration == 0 {
		duration = defaultExpDuration
	}

	now := time.Now().UTC()
	claims := Claims{
		UserID:   userID,
		Username: username,
		Role:     role,
		RegisteredClaims: jwtv5.RegisteredClaims{
			Issuer:    Issuer,
			IssuedAt:  jwtv5.NewNumericDate(now),
			NotBefore: jwtv5.NewNumericDate(now.Add(-1 * time.Second)),
			ExpiresAt: jwtv5.NewNumericDate(now.Add(duration)),
		},
	}

	token := jwtv5.NewWithClaims(jwtv5.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(resolvedSecret))
	if err != nil {
		return "", fmt.Errorf("生成 JWT 失败: %w", err)
	}

	logger.Debugf("[JWT] 生成 Token: user_id=%s, username=%s", userID, username)
	return signed, nil
}

// GenerateTokenResponse 生成完整的 Token 响应
func GenerateTokenResponse(userID string, username string, role string, secret string, duration time.Duration) (*TokenResponse, error) {
	token, err := GenerateToken(userID, username, role, secret, duration)
	if err != nil {
		return nil, err
	}

	var expiresIn int64
	if duration == 0 {
		expiresIn = int64(defaultExpDuration / time.Second)
	} else {
		expiresIn = int64(duration / time.Second)
	}

	return &TokenResponse{
		AccessToken: token,
		TokenType:   "Bearer",
		ExpiresIn:   expiresIn,
	}, nil
}

// ValidateToken 验证 JWT Token
func ValidateToken(token string, secret string) (*Claims, error) {
	resolvedSecret, err := resolveSecret(secret)
	if err != nil {
		return nil, err
	}

	claims := &Claims{}
	parsedToken, err := jwtv5.ParseWithClaims(token, claims, func(t *jwtv5.Token) (any, error) {
		return []byte(resolvedSecret), nil
	}, jwtv5.WithIssuer(Issuer), jwtv5.WithValidMethods([]string{jwtv5.SigningMethodHS256.Alg()}))
	if err != nil {
		logger.Warnf("[JWT] 令牌验证失败: %v", err)
		return nil, errors.New("无效的认证令牌")
	}
	if !parsedToken.Valid {
		return nil, errors.New("无效的认证令牌")
	}
	if claims.UserID == "" {
		return nil, errors.New("无效的认证令牌")
	}

	logger.Debugf("[JWT] Token 验证成功: user_id=%s, username=%s", claims.UserID, claims.Username)
	return claims, nil
}

// SetDefaultSecret 设置默认 JWT 密钥。
func SetDefaultSecret(secret string) error {
	secret = strings.TrimSpace(secret)
	if err := ValidateSecret(secret); err != nil {
		return err
	}

	secretMu.Lock()
	configuredKey = secret
	secretMu.Unlock()
	return nil
}

// ValidateSecret 校验 JWT 密钥强度。
func ValidateSecret(secret string) error {
	secret = strings.TrimSpace(secret)
	if secret == "" {
		return errors.New("JWT_SECRET 不能为空")
	}
	if _, isWeakPlaceholder := weakSecretPlaceholders[secret]; isWeakPlaceholder {
		return errors.New("JWT_SECRET 不能使用默认占位值")
	}
	if len(secret) < minSecretLength {
		return fmt.Errorf("JWT_SECRET 长度不能小于 %d", minSecretLength)
	}
	return nil
}

func resolveSecret(secret string) (string, error) {
	secret = strings.TrimSpace(secret)
	if secret != "" {
		if err := ValidateSecret(secret); err != nil {
			return "", err
		}
		return secret, nil
	}

	secretMu.RLock()
	configured := configuredKey
	secretMu.RUnlock()
	if err := ValidateSecret(configured); err != nil {
		return "", err
	}
	return configured, nil
}

// ExtractToken 从请求中提取 Token
func ExtractToken(c *gin.Context) (string, error) {
	authHeader := c.GetHeader(TokenHeader)
	if authHeader == "" {
		return "", errors.New("未提供认证令牌")
	}

	if !strings.HasPrefix(authHeader, BearerPrefix) {
		return "", errors.New("无效的认证令牌格式")
	}

	token := strings.TrimPrefix(authHeader, BearerPrefix)
	if token == "" {
		return "", errors.New("认证令牌不能为空")
	}

	return token, nil
}

// GetUserID 从请求中获取用户 ID
func GetUserID(c *gin.Context) (string, error) {
	if userID, exists := c.Get("user_id"); exists {
		if uid, ok := userID.(string); ok {
			return uid, nil
		}
	}

	token, err := ExtractToken(c)
	if err != nil {
		return "", err
	}

	claims, err := ValidateToken(token, "")
	if err != nil {
		return "", err
	}

	c.Set("user_id", claims.UserID)
	c.Set("username", claims.Username)
	c.Set("role", claims.Role)

	return claims.UserID, nil
}

// GetClaims 从请求中获取完整的声明信息
func GetClaims(c *gin.Context) (*Claims, error) {
	token, err := ExtractToken(c)
	if err != nil {
		return nil, err
	}

	claims, err := ValidateToken(token, "")
	if err != nil {
		return nil, err
	}

	c.Set("user_id", claims.UserID)
	c.Set("username", claims.Username)
	c.Set("role", claims.Role)

	return claims, nil
}

// SetTokenCookie 将 Token 设置到 Cookie
func SetTokenCookie(c *gin.Context, token string, maxAge int) {
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie(
		"access_token",
		token,
		maxAge,
		"/",
		"",
		true,  // HttpOnly
		false, // Secure（生产环境应为 true）
	)
}

// ClearTokenCookie 清除 Token Cookie
func ClearTokenCookie(c *gin.Context) {
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie(
		"access_token",
		"",
		-1,
		"/",
		"",
		true,
		false,
	)
}
