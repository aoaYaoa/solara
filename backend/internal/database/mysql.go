package database

import (
	"fmt"
	"log"
	"time"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// MySQLDatabase MySQL数据库实现
type MySQLDatabase struct {
	config *DatabaseConfig
	db     *gorm.DB
}

// NewMySQLDatabase 创建MySQL数据库连接
// 使用GORM和MySQL驱动连接数据库
func NewMySQLDatabase(config *DatabaseConfig) (*MySQLDatabase, error) {
	// 验证配置
	if config.Host == "" {
		return nil, fmt.Errorf("MySQL主机地址不能为空")
	}
	if config.Port == 0 {
		config.Port = 3306 // 默认端口
	}
	if config.Database == "" {
		return nil, fmt.Errorf("数据库名不能为空")
	}
	if config.Username == "" {
		return nil, fmt.Errorf("用户名不能为空")
	}

	db := &MySQLDatabase{
		config: config,
	}

	// 连接数据库
	_, err := db.Connect()
	if err != nil {
		return nil, fmt.Errorf("连接MySQL失败: %w", err)
	}

	return db, nil
}

// Connect 连接MySQL数据库
// 构建DSN (Data Source Name) 并建立连接
func (d *MySQLDatabase) Connect() (*gorm.DB, error) {
	// 构建MySQL DSN
	// 格式: username:password@tcp(host:port)/dbname?charset=utf8mb4&parseTime=True&loc=Local
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		d.config.Username,
		d.config.Password,
		d.config.Host,
		d.config.Port,
		d.config.Database,
	)

	// 使用GORM连接MySQL
	db, err := gorm.Open(mysql.Open(dsn), GormConfig())
	if err != nil {
		return nil, fmt.Errorf("打开MySQL连接失败: %w", err)
	}

	// 获取底层的*sql.DB以配置连接池
	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("获取数据库实例失败: %w", err)
	}

	// 配置连接池参数
	// SetMaxIdleConns: 设置空闲连接池中连接的最大数量
	sqlDB.SetMaxIdleConns(10)
	// SetMaxOpenConns: 设置打开数据库连接的最大数量
	sqlDB.SetMaxOpenConns(100)
	// SetConnMaxLifetime: 设置连接可复用的最长时间
	sqlDB.SetConnMaxLifetime(time.Hour)

	// 存储数据库实例
	d.db = db
	log.Printf("MySQL数据库连接成功: %s@%s:%d/%s", d.config.Username, d.config.Host, d.config.Port, d.config.Database)

	return d.db, nil
}

// Close 关闭数据库连接
func (d *MySQLDatabase) Close() error {
	if d.db != nil {
		sqlDB, err := d.db.DB()
		if err != nil {
			return fmt.Errorf("获取数据库实例失败: %w", err)
		}
		return sqlDB.Close()
	}
	return nil
}

// GetDB 获取GORM数据库实例
func (d *MySQLDatabase) GetDB() *gorm.DB {
	return d.db
}

// Migrate 执行数据库迁移
// 自动创建或更新表结构
func (d *MySQLDatabase) Migrate(models ...any) error {
	if d.db == nil {
		return fmt.Errorf("数据库未连接")
	}

	log.Println("开始执行MySQL数据库迁移...")
	if err := d.db.AutoMigrate(models...); err != nil {
		return fmt.Errorf("数据库迁移失败: %w", err)
	}
	log.Println("MySQL数据库迁移完成")
	return nil
}

// GetDBType 获取数据库类型
func (d *MySQLDatabase) GetDBType() DatabaseType {
	return MySQL
}
