# Go React 后端

基于 Go (Golang) 和 Gin 框架构建的 Go React 应用后端服务。

## 功能特性

- **依赖注入**: 采用 **手动依赖注入 (Manual DI)**，代码更透明、易调试，无代码生成步骤。
- **错误处理**: 统一的 `AppError` 错误处理机制，支持业务错误码。
- **RESTful API**: 基于 [Gin](https://github.com/gin-gonic/gin) 构建。
- **整洁架构**: 遵循 Go 标准项目布局 (Standard Go Project Layout)。
- **数据库支持**:
  - MySQL
  - PostgreSQL (Supabase)
  - MongoDB
- **ORM**: 使用 [GORM](https://gorm.io/) 处理 SQL 数据库，使用 UUID 作为主键。
- **身份验证**: 基于 JWT 的身份验证。
- **安全**:
  - 请求签名 (HMAC-SHA256)
  - IP 白名单/黑名单
  - CORS, Helmet-like 安全头
- **开发体验**:
  - **Air**: 支持热重载。
  - **Makefile**: 统一的管理命令。
  - **Swagger**: API 文档。
  - **优雅关闭**: 安全的服务终止机制。
  - **日志**: 结构化日志，支持每日轮转和彩色输出。

## 项目结构

```
backend/
├── cmd/                # 应用入口
│   └── server/         # 主服务器应用
├── internal/           # 私有应用代码
│   ├── config/         # 配置加载
│   ├── container/      # 依赖注入容器
│   ├── database/       # 数据库连接和迁移
│   ├── dto/            # 数据传输对象 (DTO)
│   ├── handlers/       # HTTP 处理器 (Controllers)
│   ├── middlewares/    # Gin 中间件
│   ├── models/         # 数据库模型
│   ├── repositories/   # 数据访问层 (DAL)
│   ├── routes/         # 路由定义
│   └── services/       # 业务逻辑层
├── pkg/                # 公共库代码
│   └── utils/          # 工具类 (日志, 加密, 响应)
├── scripts/            # 数据库初始化脚本
└── logs/               # 应用日志 (git 忽略)
```

## 快速开始

### 前置要求

- Go 1.26+
- Make (可选)
- Air (可选，用于热重载)

### 配置

复制 `.env.example` 为 `.env` 并调整设置：

```bash
cp .env.example .env
```

如果使用 Supabase：

- 长期运行的后端在 IPv4 网络下优先使用 `Session pooler`
- `DATABASE_HOST` 只能填写主机名，不要带 `https://`
- `DATABASE_USER` 需要使用 `postgres.<project-ref>` 形式

### 运行

**开发模式 (热重载):**
```bash
make dev
```

**标准运行:**
```bash
make run
```

**编译:**
```bash
make build
```

## API 文档

Swagger UI 访问地址: http://localhost:8080/swagger/index.html

## 开发工具

### 依赖注入

本项目已移除 Google Wire，改为**手动依赖注入**。

依赖组装逻辑位于 `internal/container/container.go`。如需添加新组件，请修改该文件。

详细指南请参考 [WIRE.md](WIRE.md)。
