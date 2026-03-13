package database

import (
	"fmt"
	"log"

	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// DatabaseType 数据库类型
type DatabaseType string

const (
	// MySQL 数据库类型
	MySQL DatabaseType = "mysql"
	// Mgdb 数据库类型 (MongoDB)
	Mgdb DatabaseType = "mgdb"
	// PostgreSQL 数据库类型 (Supabase)
	PostgreSQL DatabaseType = "postgres"
)

// Database 数据库接口
type Database interface {
	// Connect 连接数据库
	Connect() (*gorm.DB, error)
	// Close 关闭数据库连接
	Close() error
	// GetDB 获取数据库实例
	GetDB() *gorm.DB
	// Migrate 执行数据库迁移
	Migrate(models ...any) error
	// GetDBType 获取数据库类型
	GetDBType() DatabaseType
}

// DatabaseConfig 数据库配置
type DatabaseConfig struct {
	Type     DatabaseType // 数据库类型
	Host     string       // 数据库主机
	Port     int          // 数据库端口
	Database string       // 数据库名
	Username string       // 用户名
	Password string       // 密码
	SSLMode  string       // PostgreSQL SSL 模式
}

// NewDatabase 根据配置创建数据库连接
// 支持MySQL、MongoDB和PostgreSQL三种数据库类型
func NewDatabase(config *DatabaseConfig) (Database, error) {
	switch config.Type {
	case MySQL:
		return NewMySQLDatabase(config)
	case Mgdb:
		return NewMgdbDatabase(config)
	case PostgreSQL:
		return NewPostgreSQLDatabase(config)
	default:
		return nil, fmt.Errorf("不支持的数据库类型: %s", config.Type)
	}
}

// GormConfig 获取GORM配置
// 配置日志级别和慢查询阈值
func GormConfig() *gorm.Config {
	return &gorm.Config{
		Logger:      logger.Default.LogMode(logger.Info),
		PrepareStmt: false,
	}
}

// DefaultGormConfig 获取默认GORM配置（生产环境使用）
// 生产环境禁用详细日志，只记录错误
func DefaultGormConfig() *gorm.Config {
	return &gorm.Config{
		Logger: logger.Default.LogMode(logger.Error),
	}
}

// Ping 测试数据库连接是否正常
func Ping(db *gorm.DB) error {
	// 如果db为nil（如MongoDB），跳过测试
	if db == nil {
		log.Println("数据库为nil（如MongoDB），跳过连接测试")
		return nil
	}

	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("获取数据库连接失败: %w", err)
	}

	if err := sqlDB.Ping(); err != nil {
		return fmt.Errorf("数据库连接测试失败: %w", err)
	}

	log.Println("数据库连接测试成功")
	return nil
}
