# solara_flutter

Solara Flutter 客户端（不含 Web）。

## Cloudflare 配置要点

- 基地址：`https://solara.uonoe.com`
- Cookie/CORS 必需响应头：
  - `Access-Control-Allow-Origin: https://solara.uonoe.com`
  - `Access-Control-Allow-Credentials: true`
  - `Set-Cookie: Secure; SameSite=None; Domain=solara.uonoe.com; Path=/; HttpOnly`
- 云端存储：`/api/storage` 使用 key `solara_state`
