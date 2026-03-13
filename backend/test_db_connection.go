package main

import (
	"fmt"
	"log"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	dsn := "host=db.enacnjsevrxagqohpkox.supabase.co user=postgres password=go_react_789 dbname=postgres port=5432 sslmode=require TimeZone=Asia/Shanghai"
	
	log.Println("正在连接 Supabase PostgreSQL...")
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("❌ 连接失败: %v", err)
	}
	
	sqlDB, err := db.DB()
	if err != nil {
		log.Fatalf("❌ 获取数据库实例失败: %v", err)
	}
	
	if err := sqlDB.Ping(); err != nil {
		log.Fatalf("❌ Ping 失败: %v", err)
	}
	
	fmt.Println("✅ Supabase PostgreSQL 连接成功！")
	
	// 查询数据库版本
	var version string
	db.Raw("SELECT version()").Scan(&version)
	fmt.Printf("📊 数据库版本: %s\n", version[:50])
	
	// 列出所有表
	var tables []string
	db.Raw("SELECT tablename FROM pg_tables WHERE schemaname = 'public'").Scan(&tables)
	fmt.Printf("📋 数据表数量: %d\n", len(tables))
	if len(tables) > 0 {
		fmt.Println("📋 表列表:")
		for _, table := range tables {
			fmt.Printf("   - %s\n", table)
		}
	}
	
	sqlDB.Close()
}
