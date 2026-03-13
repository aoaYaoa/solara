package main

import (
	"backend/pkg/utils/crypto"
	"backend/pkg/utils/logger"
	"fmt"
	"log"
)

func main() {
	logger.Init()

	fmt.Println("========== 加密解密示例 ==========")

	// ==================== AES 加密示例 ====================
	fmt.Println("\n--- AES 加密解密 ---")
	aesKey := "16-byte-key-123" // 16 字节
	plaintext := "Hello, World! 这是需要加密的明文。"

	// 加密
	aesEncrypted, err := crypto.AESEncryptString(aesKey, plaintext)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("明文: %s\n", plaintext)
	fmt.Printf("密文: %s\n", aesEncrypted)

	// 解密
	aesDecrypted, err := crypto.AESDecryptString(aesKey, aesEncrypted)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("解密: %s\n", aesDecrypted)

	// AES-GCM 加密
	fmt.Println("\n--- AES-GCM 加密解密 ---")
	gcmKey, _ := crypto.GenerateAESKey(32)
	gcmEncrypted, err := crypto.AESGCMEncrypt(gcmKey, []byte(plaintext))
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("AES-GCM 密文: %s\n", gcmEncrypted)

	gcmDecrypted, err := crypto.AESGCMDecrypt(gcmKey, gcmEncrypted)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("AES-GCM 解密: %s\n", string(gcmDecrypted))

	// ==================== 哈希示例 ====================
	fmt.Println("\n--- 哈希函数 ---")
	hashText := "Hello, World!"
	fmt.Printf("MD5: %s\n", crypto.MD5(hashText))
	fmt.Printf("SHA256: %s\n", crypto.SHA256(hashText))
	fmt.Printf("SHA512: %s\n", crypto.SHA512(hashText))

	// HMAC 签名
	secret := "my-secret-key"
	data := "important-data-to-sign"
	fmt.Printf("HMAC-SHA256: %s\n", crypto.HMACSHA256(secret, data))
	fmt.Printf("HMAC-SHA512: %s\n", crypto.HMACSHA512(secret, data))

	// Base64
	fmt.Printf("Base64 编码: %s\n", crypto.Base64Encode(hashText))
	decoded, _ := crypto.Base64Decode(crypto.Base64Encode(hashText))
	fmt.Printf("Base64 解码: %s\n", decoded)

	// ==================== Bcrypt 密码哈希示例 ====================
	fmt.Println("\n--- Bcrypt 密码哈希 ---")
	password := "mySecurePassword123"
	hashedPassword, err := crypto.BcryptHash(password, 10)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("原始密码: %s\n", password)
	fmt.Printf("哈希密码: %s\n", hashedPassword)

	// 验证密码
	isValid := crypto.BcryptVerify(hashedPassword, password)
	fmt.Printf("密码验证（正确密码）: %v\n", isValid)

	isValidWrong := crypto.BcryptVerify(hashedPassword, "wrongPassword")
	fmt.Printf("密码验证（错误密码）: %v\n", isValidWrong)

	// ==================== RSA 示例 ====================
	fmt.Println("\n--- RSA 加密解密 ---")

	// 生成密钥对
	privateKey, publicKey, err := crypto.RSAGenerateKeyPair(2048)
	if err != nil {
		log.Fatal(err)
	}

	// 转换为 PEM 格式
	_ = crypto.RSAPrivateKeyToPEM(privateKey)
	publicKeyPEM := crypto.RSAPublicKeyToPEM(publicKey)

	fmt.Printf("公钥: %s\n", string(publicKeyPEM))

	// 使用公钥加密
	rsaPlaintext := "这是使用 RSA 加密的敏感数据"
	rsaEncrypted, err := crypto.RSAEncrypt(publicKey, []byte(rsaPlaintext))
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("RSA 明文: %s\n", rsaPlaintext)
	fmt.Printf("RSA 密文: %s\n", rsaEncrypted)

	// 使用私钥解密
	rsaDecrypted, err := crypto.RSADecrypt(privateKey, rsaEncrypted)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("RSA 解密: %s\n", string(rsaDecrypted))

	// RSA 签名
	fmt.Println("\n--- RSA 签名验证 ---")
	message := "这是一条需要签名的消息"
	signature, err := crypto.RSASign(privateKey, []byte(message))
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("消息: %s\n", message)
	fmt.Printf("签名: %s\n", signature)

	// 验证签名
	valid := crypto.RSAVerify(publicKey, []byte(message), []byte(signature))
	fmt.Printf("签名验证: %v\n", valid)

	// ==================== 生成密钥示例 ====================
	fmt.Println("\n--- 密钥生成 ---")

	// 生成 AES 密钥
	aesKey16, _ := crypto.GenerateAESKey(16)
	aesKey24, _ := crypto.GenerateAESKey(24)
	aesKey32, _ := crypto.GenerateAESKey(32)

	fmt.Printf("AES-128 密钥 (16 字节): %x\n", aesKey16)
	fmt.Printf("AES-192 密钥 (24 字节): %x\n", aesKey24)
	fmt.Printf("AES-256 密钥 (32 字节): %x\n", aesKey32)

	// ==================== 综合示例 ====================
	fmt.Println("\n--- 综合使用示例 ---")

	// 场景：加密敏感数据并签名
	sensitiveData := "用户信用卡号: 1234-5678-9012-3456"
	encryptKey := []byte("32-byte-encryption-key-12345")

	// 加密
	encryptedData, err := crypto.AESGCMEncrypt(encryptKey, []byte(sensitiveData))
	if err != nil {
		log.Fatal(err)
	}

	// 创建签名
	signData := fmt.Sprintf("%s|%s", string(encryptedData), "timestamp-123456")
	dataSignature := crypto.HMACSHA256("sign-secret", signData)

	fmt.Printf("原始数据: %s\n", sensitiveData)
	fmt.Printf("加密数据: %s\n", encryptedData)
	fmt.Printf("签名数据: %s\n", signData)
	fmt.Printf("数据签名: %s\n", dataSignature)

	// 验证和解析
	expectedSignature := crypto.HMACSHA256("sign-secret", signData)
	if dataSignature == expectedSignature {
		fmt.Println("✓ 签名验证成功")
		decryptedData, _ := crypto.AESGCMDecrypt(encryptKey, encryptedData)
		fmt.Printf("解密数据: %s\n", string(decryptedData))
	} else {
		fmt.Println("✗ 签名验证失败")
	}

	fmt.Println("\n========== 示例完成 ==========")
}
