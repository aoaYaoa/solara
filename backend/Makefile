.PHONY: run build test lint clean docker-build swag

# 变量定义
APP_NAME=backend
MAIN_FILE=cmd/server/main.go
BUILD_DIR=bin

# 开发运行 (优先尝试 air)
dev:
	@if command -v air > /dev/null; then \
		air; \
	else \
		echo "Air not found, using 'go run'..."; \
		go run $(MAIN_FILE); \
	fi

# 普通运行
run:
	go run $(MAIN_FILE)

# 编译
build:
	mkdir -p $(BUILD_DIR)
	go build -o $(BUILD_DIR)/$(APP_NAME) $(MAIN_FILE)

# 测试
test:
	go test ./...

# 代码检查
lint:
	golangci-lint run

# 清理
clean:
	rm -rf $(BUILD_DIR)

# Docker 相关命令
docker-build:
	docker build -t $(APP_NAME) .

docker-run:
	docker run -p 8080:8080 $(APP_NAME)

docker-up:
	cd .. && docker-compose up -d

docker-down:
	cd .. && docker-compose down

# 生成 Swagger 文档
swag:
	swag init -g $(MAIN_FILE) -o docs --parseDependency --parseInternal

# 帮助
help:
	@echo "make run    - 运行服务"
	@echo "make build  - 编译服务"
	@echo "make test   - 运行测试"
	@echo "make clean  - 清理构建文件"
	@echo "make swag   - 生成 Swagger 文档"
