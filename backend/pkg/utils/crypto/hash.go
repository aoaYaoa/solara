package crypto

import (
	"crypto/hmac"
	"crypto/md5"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"hash"
)

// MD5 计算字符串的 MD5 哈希
func MD5(text string) string {
	h := md5.New()
	h.Write([]byte(text))
	return hex.EncodeToString(h.Sum(nil))
}

// SHA256 计算字符串的 SHA256 哈希
func SHA256(text string) string {
	h := sha256.New()
	h.Write([]byte(text))
	return hex.EncodeToString(h.Sum(nil))
}

// SHA512 计算字符串的 SHA512 哈希
func SHA512(text string) string {
	h := sha512.New()
	h.Write([]byte(text))
	return hex.EncodeToString(h.Sum(nil))
}

// SHA256Bytes 计算 SHA256 哈希，返回字节
func SHA256Bytes(data []byte) []byte {
	h := sha256.New()
	h.Write(data)
	return h.Sum(nil)
}

// MD5Bytes 计算 MD5 哈希，返回字节
func MD5Bytes(data []byte) []byte {
	h := md5.New()
	h.Write(data)
	return h.Sum(nil)
}

// HMACSHA256 HMAC-SHA256 签名
func HMACSHA256(key, data string) string {
	h := hmac.New(sha256.New, []byte(key))
	h.Write([]byte(data))
	return hex.EncodeToString(h.Sum(nil))
}

// HMACSHA512 HMAC-SHA512 签名
func HMACSHA512(key, data string) string {
	h := hmac.New(sha512.New, []byte(key))
	h.Write([]byte(data))
	return hex.EncodeToString(h.Sum(nil))
}

// HMACSHA256Bytes HMAC-SHA256 签名，返回字节
func HMACSHA256Bytes(key, data []byte) []byte {
	h := hmac.New(sha256.New, key)
	h.Write(data)
	return h.Sum(nil)
}

// HashType 哈希类型
type HashType string

const (
	HashMD5    HashType = "md5"
	HashSHA256 HashType = "sha256"
	HashSHA512 HashType = "sha512"
)

// Hash 计算指定类型的哈希
func Hash(hashType HashType, text string) (string, error) {
	switch hashType {
	case HashMD5:
		return MD5(text), nil
	case HashSHA256:
		return SHA256(text), nil
	case HashSHA512:
		return SHA512(text), nil
	default:
		return "", fmt.Errorf("unsupported hash type: %s", hashType)
	}
}

// HashBytes 计算指定类型的哈希（字节输入）
func HashBytes(hashType HashType, data []byte) ([]byte, error) {
	switch hashType {
	case HashMD5:
		return MD5Bytes(data), nil
	case HashSHA256:
		return SHA256Bytes(data), nil
	case HashSHA512:
		return sha512.New().Sum(data), nil
	default:
		return nil, fmt.Errorf("unsupported hash type: %s", hashType)
	}
}

// GetHasher 获取哈希器
func GetHasher(hashType HashType) hash.Hash {
	switch hashType {
	case HashMD5:
		return md5.New()
	case HashSHA256:
		return sha256.New()
	case HashSHA512:
		return sha512.New()
	default:
		return sha256.New() // 默认使用 SHA256
	}
}

// Base64Encode Base64 编码
func Base64Encode(text string) string {
	return base64.StdEncoding.EncodeToString([]byte(text))
}

// Base64Decode Base64 解码
func Base64Decode(text string) (string, error) {
	decoded, err := base64.StdEncoding.DecodeString(text)
	if err != nil {
		return "", err
	}
	return string(decoded), nil
}

// Base64URLEncode Base64 URL 编码
func Base64URLEncode(text string) string {
	return base64.URLEncoding.EncodeToString([]byte(text))
}

// Base64URLDecode Base64 URL 解码
func Base64URLDecode(text string) (string, error) {
	decoded, err := base64.URLEncoding.DecodeString(text)
	if err != nil {
		return "", err
	}
	return string(decoded), nil
}
