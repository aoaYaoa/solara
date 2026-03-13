package database

import (
	"context"
	"fmt"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"gorm.io/gorm"
)

// MgdbDatabase MongoDB数据库实现
type MgdbDatabase struct {
	config *DatabaseConfig
	client *mongo.Client
	db     *mongo.Database
}

// NewMgdbDatabase 创建MongoDB数据库连接
func NewMgdbDatabase(config *DatabaseConfig) (*MgdbDatabase, error) {
	// 验证配置
	if config.Host == "" {
		return nil, fmt.Errorf("MongoDB主机地址不能为空")
	}
	if config.Port == 0 {
		config.Port = 27017 // 默认端口
	}
	if config.Database == "" {
		return nil, fmt.Errorf("数据库名不能为空")
	}

	db := &MgdbDatabase{
		config: config,
	}

	// 连接数据库
	if _, err := db.Connect(); err != nil {
		return nil, fmt.Errorf("连接MongoDB失败: %w", err)
	}

	return db, nil
}

// Connect 连接MongoDB数据库
func (d *MgdbDatabase) Connect() (*gorm.DB, error) {
	// 构建连接URI
	// 格式: mongodb://host:port/database 或 mongodb://username:password@host:port/database
	var uri string
	if d.config.Username != "" && d.config.Password != "" {
		uri = fmt.Sprintf("mongodb://%s:%s@%s:%d/%s",
			d.config.Username,
			d.config.Password,
			d.config.Host,
			d.config.Port,
			d.config.Database,
		)
	} else {
		uri = fmt.Sprintf("mongodb://%s:%d/%s",
			d.config.Host,
			d.config.Port,
			d.config.Database,
		)
	}

	// 设置客户端选项
	clientOptions := options.Client().
		ApplyURI(uri).
		SetMaxPoolSize(100).
		SetMinPoolSize(10).
		SetMaxConnIdleTime(time.Hour)

	// 连接到MongoDB
	client, err := mongo.Connect(context.Background(), clientOptions)
	if err != nil {
		return nil, fmt.Errorf("打开MongoDB连接失败: %w", err)
	}

	// 测试连接
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx, nil); err != nil {
		return nil, fmt.Errorf("MongoDB连接测试失败: %w", err)
	}

	d.client = client
	d.db = client.Database(d.config.Database)

	log.Printf("MongoDB数据库连接成功: %s:%d/%s", d.config.Host, d.config.Port, d.config.Database)

	// 返回nil表示MongoDB不使用GORM
	return nil, nil
}

// Close 关闭数据库连接
func (d *MgdbDatabase) Close() error {
	if d.client != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := d.client.Disconnect(ctx); err != nil {
			return fmt.Errorf("关闭MongoDB连接失败: %w", err)
		}
		log.Println("MongoDB连接已关闭")
	}
	return nil
}

// GetDB 获取数据库实例
// MongoDB返回nil，因为不使用GORM
func (d *MgdbDatabase) GetDB() *gorm.DB {
	return nil
}

// GetClient 获取MongoDB客户端实例（MongoDB专用方法）
func (d *MgdbDatabase) GetClient() *mongo.Client {
	return d.client
}

// GetDatabase 获取MongoDB数据库实例（MongoDB专用方法）
func (d *MgdbDatabase) GetDatabase() *mongo.Database {
	return d.db
}

// Migrate 执行数据库迁移
// MongoDB不需要显式的迁移，索引会在首次访问时自动创建
func (d *MgdbDatabase) Migrate(models ...any) error {
	log.Println("MongoDB数据库迁移检查...")

	// 为users集合创建索引
	if d.db != nil {
		usersCollection := d.db.Collection("users")

		// 创建用户名唯一索引
		_, err := usersCollection.Indexes().CreateOne(
			context.Background(),
			mongo.IndexModel{
				Keys:    bson.M{"username": 1},
				Options: options.Index().SetUnique(true),
			},
		)
		if err != nil {
			log.Printf("创建username索引失败: %v", err)
		}

		// 创建邮箱唯一索引
		_, err = usersCollection.Indexes().CreateOne(
			context.Background(),
			mongo.IndexModel{
				Keys:    bson.M{"email": 1},
				Options: options.Index().SetUnique(true),
			},
		)
		if err != nil {
			log.Printf("创建email索引失败: %v", err)
		}

		// 为tasks集合创建索引
		tasksCollection := d.db.Collection("tasks")
		_, err = tasksCollection.Indexes().CreateOne(
			context.Background(),
			mongo.IndexModel{
				Keys: bson.M{"user_id": 1},
			},
		)
		if err != nil {
			log.Printf("创建tasks索引失败: %v", err)
		}
	}

	log.Println("MongoDB数据库迁移完成")
	return nil
}

// GetDBType 获取数据库类型
func (d *MgdbDatabase) GetDBType() DatabaseType {
	return "mgdb"
}
