package crypto

import (
	"backend/pkg/utils/logger"

	"golang.org/x/crypto/bcrypt"
)

// BcryptHash 使用 bcrypt 哈希密码
// cost: 加密成本（4-31，默认 10）
func BcryptHash(password string, cost int) (string, error) {
	if cost == 0 {
		cost = 10 // 默认值
	}

	bytes, err := bcrypt.GenerateFromPassword([]byte(password), cost)
	if err != nil {
		logger.Errorf("Bcrypt hash failed: %v", err)
		return "", err
	}

	return string(bytes), nil
}

// BcryptVerify 验证密码
func BcryptVerify(hashedPassword, password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
	return err == nil
}

// BcryptHashDefault 使用默认成本哈希密码
func BcryptHashDefault(password string) (string, error) {
	return BcryptHash(password, 10)
}
