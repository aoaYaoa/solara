package main

import (
	"backend/internal/config"
	"backend/internal/database"
	"backend/pkg/utils/crypto"
	"context"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey"`
	Email      string    `gorm:"type:text"`
	Username   string    `gorm:"type:text;uniqueIndex"`
	Password   string    `gorm:"type:text"`
	Role       string    `gorm:"type:text"`
	Status     string    `gorm:"type:text"`
	IsVerified bool      `gorm:"type:boolean"`
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

func (User) TableName() string { return "users" }

func main() {
	config.Init()

	dbConfig := &database.DatabaseConfig{
		Type:     database.PostgreSQL,
		Host:     config.AppConfig.DatabaseHost,
		Port:     config.AppConfig.DatabasePort,
		Database: config.AppConfig.DatabaseName,
		Username: config.AppConfig.DatabaseUser,
		Password: config.AppConfig.DatabasePass,
		SSLMode:  config.AppConfig.DatabaseSSLMode,
	}

	db, err := database.NewDatabase(dbConfig)
	if err != nil {
		log.Fatalf("连接数据库失败: %v", err)
	}

	hash, err := crypto.BcryptHash("admin123", 10)
	if err != nil {
		log.Fatalf("生成密码失败: %v", err)
	}

	gormDB := db.GetDB().WithContext(context.Background())

	result := gormDB.Exec(
		"UPDATE users SET password = ? WHERE username = 'admin'",
		hash,
	)
	if result.Error != nil {
		log.Fatalf("更新失败: %v", result.Error)
	}
	fmt.Printf("更新成功，影响行数: %d\n", result.RowsAffected)
}
