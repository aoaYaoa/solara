# Solara CF 存储同步与本地请求修复设计

日期：2026-03-12  
目标位置：/Users/aay/自有项目/solara_flutter

## 1. 目标与范围
- 目标：在 Flutter 端实现“本地优先 + 后台同步”的 Cloudflare 存储方案，并修复本地到 CF 的请求问题。
- 影响范围：收藏、队列、设置三类数据；API 基址切换到 `https://solara.uonoe.com`。
- 非目标：Web 端 UI（暂不启用），后端业务逻辑大改。

## 2. 架构与组件
- `RemoteStorageService`：封装 `/api/storage` 的 GET/POST/DELETE。
- `SyncController`：负责启动拉取、合并、监听本地变更并推送云端。
- `PersistentStateService`：保持本地读写职责，增加“本地变更 → SyncController”触发。
- `ApiClient`：保留 CookieJar；为 Web 预留 `withCredentials` 选项。

## 3. 云端存储结构
推荐统一存储一个 `solara_state` 文档：
```json
{
  "version": 1,
  "updatedAt": "2026-03-12T10:00:00Z",
  "queue": {"updatedAt": "...", "songs": [/* Song */]},
  "favorites": {"updatedAt": "...", "songs": [/* Song */]},
  "settings": {"updatedAt": "...", "data": {/* settings */}}
}
```
- 合并规则：同 key 以最新 `updatedAt` 为准。
- 兼容：若云端缺 key，以本地为准并回写。

## 4. 本地到 CF 请求修复
- 基地址改为：`https://solara.uonoe.com`
- Cookie 与跨域要求（后端需满足）：
  - `Access-Control-Allow-Origin: https://solara.uonoe.com`
  - `Access-Control-Allow-Credentials: true`
  - `Set-Cookie: Secure; SameSite=None; Domain=solara.uonoe.com; Path=/; HttpOnly`
- Flutter 侧：非 Web 通过 CookieJar；Web 预留 `withCredentials=true`。

## 5. 数据流
- 启动：云端拉取 → 与本地合并 → 写回本地 → 后台推送最新云端。
- 变更：本地先写 → 同步队列 → 后台 POST 云端。
- 失败：保留本地，后台重试（指数退避），不影响播放。

## 6. 测试策略
- 单测：合并逻辑（本地/云端冲突）、payload 序列化。
- 集成：模拟“离线写入 → 上线同步 → 云端更新”。

