package crypto

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"errors"
)

// RSAGenerateKeyPair 生成 RSA 密钥对
// bits: 密钥位数（推荐 2048 或 4096）
func RSAGenerateKeyPair(bits int) (*rsa.PrivateKey, *rsa.PublicKey, error) {
	privateKey, err := rsa.GenerateKey(rand.Reader, bits)
	if err != nil {
		return nil, nil, err
	}
	return privateKey, &privateKey.PublicKey, nil
}

// RSAPrivateKeyToPEM 将私钥转换为 PEM 格式
func RSAPrivateKeyToPEM(privateKey *rsa.PrivateKey) []byte {
	privateKeyBytes := x509.MarshalPKCS1PrivateKey(privateKey)
	privateKeyPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: privateKeyBytes,
	})
	return privateKeyPEM
}

// RSAPublicKeyToPEM 将公钥转换为 PEM 格式
func RSAPublicKeyToPEM(publicKey *rsa.PublicKey) []byte {
	publicKeyBytes, err := x509.MarshalPKIXPublicKey(publicKey)
	if err != nil {
		return nil
	}
	publicKeyPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "PUBLIC KEY",
		Bytes: publicKeyBytes,
	})
	return publicKeyPEM
}

// RSAParsePrivateKeyFromPEM 从 PEM 字符串解析私钥
func RSAParsePrivateKeyFromPEM(pemStr string) (*rsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		return nil, errors.New("failed to parse PEM block containing the key")
	}

	privateKey, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}

	return privateKey, nil
}

// RSAParsePublicKeyFromPEM 从 PEM 字符串解析公钥
func RSAParsePublicKeyFromPEM(pemStr string) (*rsa.PublicKey, error) {
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		return nil, errors.New("failed to parse PEM block containing the key")
	}

	publicKey, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, err
	}

	rsaPublicKey, ok := publicKey.(*rsa.PublicKey)
	if !ok {
		return nil, errors.New("not an RSA public key")
	}

	return rsaPublicKey, nil
}

// RSAEncrypt RSA 公钥加密
func RSAEncrypt(publicKey *rsa.PublicKey, plaintext []byte) (string, error) {
	ciphertext, err := rsa.EncryptOAEP(
		sha256.New(),
		rand.Reader,
		publicKey,
		plaintext,
		nil,
	)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// RSADecrypt RSA 私钥解密
func RSADecrypt(privateKey *rsa.PrivateKey, ciphertext string) ([]byte, error) {
	ciphertextBytes, err := base64.StdEncoding.DecodeString(ciphertext)
	if err != nil {
		return nil, err
	}

	plaintext, err := rsa.DecryptOAEP(
		sha256.New(),
		rand.Reader,
		privateKey,
		ciphertextBytes,
		nil,
	)
	if err != nil {
		return nil, err
	}
	return plaintext, nil
}

// RSAEncryptString RSA 加密字符串
func RSAEncryptString(publicKeyPEM string, plaintext string) (string, error) {
	publicKey, err := RSAParsePublicKeyFromPEM(publicKeyPEM)
	if err != nil {
		return "", err
	}

	ciphertext, err := RSAEncrypt(publicKey, []byte(plaintext))
	if err != nil {
		return "", err
	}

	return ciphertext, nil
}

// RSADecryptString RSA 解密字符串
func RSADecryptString(privateKeyPEM string, ciphertext string) (string, error) {
	privateKey, err := RSAParsePrivateKeyFromPEM(privateKeyPEM)
	if err != nil {
		return "", err
	}

	plaintext, err := RSADecrypt(privateKey, ciphertext)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}

// RSASign 使用私钥签名
func RSASign(privateKey *rsa.PrivateKey, message []byte) (string, error) {
	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, cryptoHash, message)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(signature), nil
}

// RSAVerify 使用公钥验证签名
func RSAVerify(publicKey *rsa.PublicKey, message, signature []byte) bool {
	err := rsa.VerifyPKCS1v15(publicKey, cryptoHash, message, signature)
	return err == nil
}

// RSASignString 对字符串签名
func RSASignString(privateKey *rsa.PrivateKey, message string) (string, error) {
	return RSASign(privateKey, []byte(message))
}

// RSAVerifyString 验证字符串签名
func RSAVerifyString(publicKey *rsa.PublicKey, message, signature string) bool {
	sigBytes, err := base64.StdEncoding.DecodeString(signature)
	if err != nil {
		return false
	}
	return RSAVerify(publicKey, []byte(message), sigBytes)
}

// RSAGenerateKeyPairPEM 生成 RSA 密钥对并返回 PEM 格式
func RSAGenerateKeyPairPEM(bits int) (privateKeyPEM, publicKeyPEM []byte, err error) {
	privateKey, publicKey, err := RSAGenerateKeyPair(bits)
	if err != nil {
		return nil, nil, err
	}

	privateKeyPEM = RSAPrivateKeyToPEM(privateKey)
	publicKeyPEM = RSAPublicKeyToPEM(publicKey)

	return privateKeyPEM, publicKeyPEM, nil
}

// cryptoHash 用于 RSA 签名的哈希算法
// 使用SHA256作为哈希算法
var cryptoHash crypto.Hash = crypto.SHA256

