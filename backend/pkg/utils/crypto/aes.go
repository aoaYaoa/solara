package crypto

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
)

// AESEncrypt AES 加密
// key: 16, 24, 或 32 字节（AES-128, AES-192, AES-256）
// plaintext: 明文
// 返回: base64 编码的密文
func AESEncrypt(key, plaintext []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	// 创建字节填充
	blockSize := block.BlockSize()
	plaintext = PKCS7Padding(plaintext, blockSize)

	// 使用 CBC 模式
	ciphertext := make([]byte, blockSize+len(plaintext))
	iv := ciphertext[:blockSize]
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		return "", err
	}

	mode := cipher.NewCBCEncrypter(block, iv)
	mode.CryptBlocks(ciphertext[blockSize:], plaintext)

	// 返回 base64 编码
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// AESDecrypt AES 解密
// key: 16, 24, 或 32 字节
// ciphertext: base64 编码的密文
// 返回: 明文
func AESDecrypt(key []byte, ciphertext string) ([]byte, error) {
	// Base64 解码
	ciphertextBytes, err := base64.StdEncoding.DecodeString(ciphertext)
	if err != nil {
		return nil, err
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	if len(ciphertextBytes) < aes.BlockSize {
		return nil, errors.New("ciphertext too short")
	}

	blockSize := block.BlockSize()
	iv := ciphertextBytes[:blockSize]
	ciphertextBytes = ciphertextBytes[blockSize:]

	// CBC 模式
	if len(ciphertextBytes)%blockSize != 0 {
		return nil, errors.New("ciphertext is not a multiple of the block size")
	}

	mode := cipher.NewCBCDecrypter(block, iv)
	mode.CryptBlocks(ciphertextBytes, ciphertextBytes)

	// 移除填充
	plaintext, err := PKCS7UnPadding(ciphertextBytes)
	if err != nil {
		return nil, err
	}

	return plaintext, nil
}

// AESEncryptString 加密字符串
func AESEncryptString(key string, plaintext string) (string, error) {
	keyBytes := []byte(key)
	plaintextBytes := []byte(plaintext)
	return AESEncrypt(keyBytes, plaintextBytes)
}

// AESDecryptString 解密字符串
func AESDecryptString(key string, ciphertext string) (string, error) {
	keyBytes := []byte(key)
	plaintextBytes, err := AESDecrypt(keyBytes, ciphertext)
	if err != nil {
		return "", err
	}
	return string(plaintextBytes), nil
}

// AESGCMEncrypt AES-GCM 加密（更安全）
func AESGCMEncrypt(key, plaintext []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	ciphertext := gcm.Seal(nonce, nonce, plaintext, nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// AESGCMDecrypt AES-GCM 解密
func AESGCMDecrypt(key []byte, ciphertext string) ([]byte, error) {
	ciphertextBytes, err := base64.StdEncoding.DecodeString(ciphertext)
	if err != nil {
		return nil, err
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := gcm.NonceSize()
	if len(ciphertextBytes) < nonceSize {
		return nil, errors.New("ciphertext too short")
	}

	nonce, ciphertextBytes := ciphertextBytes[:nonceSize], ciphertextBytes[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertextBytes, nil)
	if err != nil {
		return nil, err
	}

	return plaintext, nil
}

// PKCS7Padding PKCS7 填充
func PKCS7Padding(ciphertext []byte, blockSize int) []byte {
	padding := blockSize - len(ciphertext)%blockSize
	padtext := bytes.Repeat([]byte{byte(padding)}, padding)
	return append(ciphertext, padtext...)
}

// PKCS7UnPadding 移除 PKCS7 填充
func PKCS7UnPadding(ciphertext []byte) ([]byte, error) {
	length := len(ciphertext)
	if length == 0 {
		return ciphertext, nil
	}

	unpadding := int(ciphertext[length-1])
	if unpadding > length {
		return nil, errors.New("invalid padding")
	}

	return ciphertext[:(length - unpadding)], nil
}

// GenerateAESKey 生成 AES 密钥
func GenerateAESKey(keySize int) ([]byte, error) {
	if keySize != 16 && keySize != 24 && keySize != 32 {
		return nil, fmt.Errorf("invalid key size: %d (must be 16, 24, or 32)", keySize)
	}

	key := make([]byte, keySize)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return nil, err
	}
	return key, nil
}
