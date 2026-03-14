# Solara

一款基于 Flutter + Go 的全平台音乐播放器，支持 Android、iOS、macOS、Windows、Linux。

## 项目结构

```
solara/
├── frontend/   # Flutter 客户端
└── backend/    # Go + Gin 后端服务
```

## 功能特性

- **多平台**：Android / iOS / macOS / Windows / Linux
- **搜索**：多数据源切换，关键词搜索
- **播放队列**：新增、删除、清空、导入、导出
- **收藏列表**：批量操作，本地持久化
- **播放模式**：顺序 / 单曲循环 / 随机
- **歌词同步**：滚动高亮，手动锁定
- **多码率**：128 / 192 / 320kbps / FLAC
- **主题**：背景取色 + 毛玻璃拟态，亮/暗模式
- **探索雷达**：自动推荐、分类可配置
- **锁屏控制**：移动端系统通知栏 / 锁屏播放
- **系统音量**：iOS/Android 上音量滑块直接控制系统音量
- **云端同步**：通过 Cloudflare 存储同步播放状态
- **调试控制台**：手势触发，实时日志查看
- **JWT 自动续签**：Token 过期后静默重登录，无感刷新

## 快速开始

### 前端（Flutter）

**前置要求**：Flutter SDK ≥ 3.7.2

```bash
cd frontend
flutter pub get
flutter run
```

支持平台：

```bash
flutter run -d ios
flutter run -d android
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

**配置 API 基地址**：修改 `frontend/lib/services/app_config.dart`。

### 后端（Go）

**前置要求**：Go 1.21+、Make（可选）

```bash
cd backend
cp .env.example .env   # 填写数据库、JWT 等配置
make dev               # 热重载开发模式
# 或
make run               # 标准运行
```

API 文档（Swagger）：http://localhost:8080/swagger/index.html

## 技术栈

| 层 | 技术 |
|---|---|
| 客户端 UI | Flutter + Riverpod |
| 音频引擎 | just_audio + audio_service |
| 系统音量 | volume_controller（iOS/Android） |
| HTTP 客户端 | Dio + cookie_jar |
| 本地存储 | shared_preferences |
| 后端框架 | Go + Gin |
| 数据库 | PostgreSQL (Supabase) / MySQL / MongoDB |
| ORM | GORM |
| 认证 | JWT |
| 云存储 | Cloudflare Pages Functions |

## 架构说明

### 前端分层

```
lib/
├── app/            # 应用入口与路由
├── data/           # API 客户端与仓库层
├── domain/         # 业务模型与状态（Riverpod）
├── platform/       # 平台适配（AudioEngine 抽象）
├── presentation/   # 页面与组件
└── services/       # 跨层服务（播放控制、下载、同步等）
```

### 后端分层

```
backend/
├── cmd/            # 应用入口
├── internal/       # 私有业务代码（handlers / services / repositories）
└── pkg/            # 公共工具库
```

## Cloudflare 配置

- 基地址：`https://solara.uonoe.com`
- 必需响应头：
  - `Access-Control-Allow-Origin: https://solara.uonoe.com`
  - `Access-Control-Allow-Credentials: true`
  - `Set-Cookie: Secure; SameSite=None; Domain=solara.uonoe.com; Path=/; HttpOnly`
- 云端状态存储：`/api/storage` key `solara_state`
