# Solara Functions API Notes (from /tmp/Solara)

Base: same-origin (Pages). Client uses relative paths.

## 1) Proxy API (music data)
Endpoint: `GET /proxy`

Query params:
- `types`: `search` | `url` | `lyric` | `pic` | `playlist`
- `source`: music source, default `netease`
- `name`: search keyword (for `types=search`)
- `count`: search page size
- `pages`: search page index (1-based)
- `id`: song/playlist id (for `url`, `lyric`, `pic`, `playlist`)
- `br`: bitrate/quality (for `url`, e.g. 128/192/320/FLAC)
- `size`: image size (for `pic`, e.g. 300)
- `s`: random signature (client generated)

Response:
- `types=search`: JSON array of songs
  - item fields: `id`, `name`, `artist`, `album`, `pic_id`, `url_id`, `lyric_id`, `source`
- `types=playlist`: JSON object with `playlist.tracks[]`
  - track fields: `id`, `name`, `ar[]`, `al.pic_str|pic|picUrl`
- `types=url`: JSON with `url` (stream/download URL) and metadata
- `types=lyric`: JSON with lyric data
- `types=pic`: JSON with `url` or image info

Notes:
- Client uses `API.baseUrl = "/proxy"`.
- For Kuwo audio direct proxy: `GET /proxy?target=<full-kuwo-url>` (host must match `*.kuwo.cn`).

## 2) Palette API (cover color analysis)
Endpoint: `GET /palette`

Query params:
- `image` (preferred) or `url`: full image URL

Response:
```json
{
  "source": "...",
  "baseColor": "#RRGGBB",
  "averageColor": "#RRGGBB",
  "accentColor": "#RRGGBB",
  "contrastColor": "#RRGGBB",
  "gradients": { "light": ["#..", "#.."], "dark": ["#..", "#.."] },
  "tokens": { ... }
}
```

## 3) Storage API (D1)
Endpoint: `/api/storage`

Availability:
- `GET /api/storage?status=1` -> `{ d1Available: true|false }`

Fetch keys:
- `GET /api/storage?keys=k1,k2,...` -> `{ d1Available: true|false, data: { [key]: value|null } }`

Write:
- `POST /api/storage` body: `{ "data": { "key": "value", ... } }`
-> `{ d1Available: true|false, updated: <n> }`

Delete:
- `DELETE /api/storage` body: `{ "keys": ["k1", "k2"] }`
-> `{ d1Available: true|false, deleted: <n> }`

## 4) Login API (password gate)
Endpoint: `POST /api/login`

Body:
```json
{ "password": "..." }
```

Response:
- Success: `{ "success": true }` and Set-Cookie `auth=<base64(PASSWORD)>` (HttpOnly)
- Failure: `{ "success": false }` with 401

Middleware:
- If `PASSWORD` set, non-public routes require cookie `auth == btoa(PASSWORD)` else redirect `/login`.
