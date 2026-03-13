# Discover Page + NowPlaying Full-Screen Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Solara 添加发现页（实时排行榜+歌单）和全屏 NowPlaying 页，并将顶部 TabBar 改为底部导航栏。

**Architecture:**
- 后端新增 `/api/discover/*` 接口，代理 `music-api.gdstudio.xyz` 的排行榜和歌单数据
- Flutter 前端新增 `DiscoverState`（Riverpod）管理发现页数据，新增 `NowPlayingScreen` 全屏页
- `HomeScreen` 改为 `BottomNavigationBar`（4个Tab：发现/搜索/队列/收藏），Lyrics 移入 NowPlaying 全屏页
- PlayerBar 包裹 `GestureDetector`，点击触发全屏页

**Tech Stack:** Flutter 3.x, Riverpod 2.x, Dio, Go/Gin, gorm, music-api.gdstudio.xyz

---

## Task 1: 后端 — 新增 Discover Handler

**Files:**
- Modify: `solara/backend/internal/handlers/solara_handler.go`
- Modify: `solara/backend/internal/routes/routes.go`

### Step 1: 在 `solara_handler.go` 末尾添加排行榜接口

在 `SolaraHandler` 上添加以下方法（在文件末尾追加）：

```go
// DiscoverLeaderboardList 获取排行榜列表（各音乐源支持的榜单）
// GET /api/discover/leaderboard?source=kw
func (h *SolaraHandler) DiscoverLeaderboardList(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	source := c.DefaultQuery("source", "kw")
	targetURL := fmt.Sprintf("%s?types=leaderboard&source=%s", musicAPIBase, url.QueryEscape(source))
	h.proxyRequest(c, targetURL, nil)
}

// DiscoverLeaderboardDetail 获取排行榜详情
// GET /api/discover/leaderboard/:id?source=kw&page=1&limit=30
func (h *SolaraHandler) DiscoverLeaderboardDetail(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	id := c.Param("id")
	source := c.DefaultQuery("source", "kw")
	page := c.DefaultQuery("page", "1")
	limit := c.DefaultQuery("limit", "30")
	targetURL := fmt.Sprintf("%s?types=leaderboard&source=%s&id=%s&pages=%s&count=%s",
		musicAPIBase, url.QueryEscape(source), url.QueryEscape(id), page, limit)
	h.proxyRequest(c, targetURL, nil)
}

// DiscoverSongList 获取歌单列表
// GET /api/discover/songlist?source=kw&sort=hot&tag=&page=1&limit=20
func (h *SolaraHandler) DiscoverSongList(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	source := c.DefaultQuery("source", "kw")
	sort := c.DefaultQuery("sort", "hot")
	tag := c.DefaultQuery("tag", "")
	page := c.DefaultQuery("page", "1")
	limit := c.DefaultQuery("limit", "20")
	targetURL := fmt.Sprintf("%s?types=songlist&source=%s&sort=%s&tag=%s&pages=%s&count=%s",
		musicAPIBase, url.QueryEscape(source), url.QueryEscape(sort), url.QueryEscape(tag), page, limit)
	h.proxyRequest(c, targetURL, nil)
}

// DiscoverSongListDetail 获取歌单详情（含歌曲列表）
// GET /api/discover/songlist/:id?source=kw&page=1&limit=30
func (h *SolaraHandler) DiscoverSongListDetail(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	id := c.Param("id")
	source := c.DefaultQuery("source", "kw")
	page := c.DefaultQuery("page", "1")
	limit := c.DefaultQuery("limit", "30")
	targetURL := fmt.Sprintf("%s?types=songlist&source=%s&id=%s&pages=%s&count=%s",
		musicAPIBase, url.QueryEscape(source), url.QueryEscape(id), page, limit)
	h.proxyRequest(c, targetURL, nil)
}
```

### Step 2: 在 `routes.go` 注册路由

在 `engine.GET("/proxy", ...)` 同级位置，添加：

```go
// Discover APIs (需要认证)
discover := engine.Group("/api/discover")
{
    discover.Use(/* 无需额外中间件，handler 内部校验 isAuthed */)
    discover.GET("/leaderboard", r.handlers.Solara.DiscoverLeaderboardList)
    discover.GET("/leaderboard/:id", r.handlers.Solara.DiscoverLeaderboardDetail)
    discover.GET("/songlist", r.handlers.Solara.DiscoverSongList)
    discover.GET("/songlist/:id", r.handlers.Solara.DiscoverSongListDetail)
}
```

### Step 3: 验证后端编译

```bash
cd solara/backend && go build ./...
```

期望：无编译错误。

### Step 4: 手动测试（启动后端后）

```bash
cd solara/backend && go run cmd/server/main.go &
curl -H "Authorization: Bearer <token>" 'http://localhost:8080/api/discover/leaderboard?source=kw'
```

期望：返回 music API 的 JSON 数据。

---

## Task 2: Flutter — Discover 数据模型和 Provider

**Files:**
- Create: `solara/frontend/lib/domain/models/discover.dart`
- Create: `solara/frontend/lib/domain/state/discover_state.dart`
- Modify: `solara/frontend/lib/data/api/solara_api.dart`
- Modify: `solara/frontend/lib/data/solara_repository.dart`
- Modify: `solara/frontend/lib/data/providers.dart`

### Step 1: 创建数据模型 `lib/domain/models/discover.dart`

```dart
class LeaderboardItem {
  final String id;
  final String name;
  final String? coverUrl;
  final String source;

  const LeaderboardItem({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.source,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      coverUrl: json['cover'] ?? json['coverUrl'],
      source: json['source'] ?? 'kw',
    );
  }
}

class SongListItem {
  final String id;
  final String name;
  final String author;
  final String? coverUrl;
  final String? playCount;
  final String source;

  const SongListItem({
    required this.id,
    required this.name,
    required this.author,
    this.coverUrl,
    this.playCount,
    required this.source,
  });

  factory SongListItem.fromJson(Map<String, dynamic> json, String source) {
    return SongListItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      author: json['author'] ?? json['creator'] ?? '',
      coverUrl: json['cover'] ?? json['coverUrl'] ?? json['pic_url'],
      playCount: json['playCount']?.toString() ?? json['play_count']?.toString(),
      source: source,
    );
  }
}
```

### Step 2: 创建 `lib/domain/state/discover_state.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discover.dart';
import '../models/song.dart';
import '../../data/providers.dart';

class DiscoverState {
  final List<LeaderboardItem> leaderboards;
  final List<SongListItem> songLists;
  final bool loadingLeaderboards;
  final bool loadingSongLists;
  final String? error;

  const DiscoverState({
    this.leaderboards = const [],
    this.songLists = const [],
    this.loadingLeaderboards = false,
    this.loadingSongLists = false,
    this.error,
  });

  DiscoverState copyWith({
    List<LeaderboardItem>? leaderboards,
    List<SongListItem>? songLists,
    bool? loadingLeaderboards,
    bool? loadingSongLists,
    String? error,
  }) {
    return DiscoverState(
      leaderboards: leaderboards ?? this.leaderboards,
      songLists: songLists ?? this.songLists,
      loadingLeaderboards: loadingLeaderboards ?? this.loadingLeaderboards,
      loadingSongLists: loadingSongLists ?? this.loadingSongLists,
      error: error,
    );
  }
}

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  final Ref _ref;

  DiscoverNotifier(this._ref) : super(const DiscoverState());

  Future<void> loadAll({String source = 'kw'}) async {
    await Future.wait([
      loadLeaderboards(source: source),
      loadSongLists(source: source),
    ]);
  }

  Future<void> loadLeaderboards({String source = 'kw'}) async {
    state = state.copyWith(loadingLeaderboards: true, error: null);
    try {
      final repo = _ref.read(solaraRepositoryProvider);
      final items = await repo.fetchLeaderboards(source: source);
      state = state.copyWith(leaderboards: items, loadingLeaderboards: false);
    } catch (e) {
      state = state.copyWith(loadingLeaderboards: false, error: e.toString());
    }
  }

  Future<void> loadSongLists({String source = 'kw'}) async {
    state = state.copyWith(loadingSongLists: true, error: null);
    try {
      final repo = _ref.read(solaraRepositoryProvider);
      final items = await repo.fetchSongLists(source: source);
      state = state.copyWith(songLists: items, loadingSongLists: false);
    } catch (e) {
      state = state.copyWith(loadingSongLists: false, error: e.toString());
    }
  }

  Future<List<Song>> fetchLeaderboardDetail(String id, {String source = 'kw'}) async {
    final repo = _ref.read(solaraRepositoryProvider);
    return repo.fetchLeaderboardDetail(id, source: source);
  }

  Future<List<Song>> fetchSongListDetail(String id, {String source = 'kw'}) async {
    final repo = _ref.read(solaraRepositoryProvider);
    return repo.fetchSongListDetail(id, source: source);
  }
}

final discoverStateProvider = StateNotifierProvider<DiscoverNotifier, DiscoverState>(
  (ref) => DiscoverNotifier(ref),
);
```

### Step 3: 在 `lib/data/api/solara_api.dart` 添加 Discover API 方法

在 `SolaraApi` 类末尾追加：

```dart
Future<dynamic> getLeaderboards({String source = 'kw'}) async {
  final resp = await _client.dio.get(
    '/api/discover/leaderboard',
    queryParameters: {'source': source},
  );
  return resp.data;
}

Future<dynamic> getLeaderboardDetail(String id, {String source = 'kw', int page = 1}) async {
  final resp = await _client.dio.get(
    '/api/discover/leaderboard/$id',
    queryParameters: {'source': source, 'page': page, 'limit': 30},
  );
  return resp.data;
}

Future<dynamic> getSongLists({String source = 'kw', String sort = 'hot', String tag = '', int page = 1}) async {
  final resp = await _client.dio.get(
    '/api/discover/songlist',
    queryParameters: {'source': source, 'sort': sort, 'tag': tag, 'page': page, 'limit': 20},
  );
  return resp.data;
}

Future<dynamic> getSongListDetail(String id, {String source = 'kw', int page = 1}) async {
  final resp = await _client.dio.get(
    '/api/discover/songlist/$id',
    queryParameters: {'source': source, 'page': page, 'limit': 30},
  );
  return resp.data;
}
```

### Step 4: 在 `lib/data/solara_repository.dart` 添加 Discover 方法

在 `SolaraRepository` 类末尾追加（需要先了解 Song.fromJson 格式）：

```dart
Future<List<LeaderboardItem>> fetchLeaderboards({String source = 'kw'}) async {
  final data = await _api.getLeaderboards(source: source);
  final list = data is List ? data : (data['list'] ?? data['data'] ?? []);
  return (list as List)
      .map((e) => LeaderboardItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<Song>> fetchLeaderboardDetail(String id, {String source = 'kw'}) async {
  final data = await _api.getLeaderboardDetail(id, source: source);
  final list = data is List ? data : (data['list'] ?? data['data'] ?? []);
  return (list as List)
      .map((e) => Song.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<SongListItem>> fetchSongLists({String source = 'kw'}) async {
  final data = await _api.getSongLists(source: source);
  final list = data is List ? data : (data['list'] ?? data['data'] ?? []);
  return (list as List)
      .map((e) => SongListItem.fromJson(e as Map<String, dynamic>, source))
      .toList();
}

Future<List<Song>> fetchSongListDetail(String id, {String source = 'kw'}) async {
  final data = await _api.getSongListDetail(id, source: source);
  final list = data is List ? data : (data['list'] ?? data['data'] ?? []);
  return (list as List)
      .map((e) => Song.fromJson(e as Map<String, dynamic>))
      .toList();
}
```

**注意：** 需要在文件顶部 import `discover.dart`。

### Step 5: 验证 Flutter 编译

```bash
cd solara/frontend && flutter analyze lib/domain/ lib/data/
```

期望：无错误。

---

## Task 3: Flutter — Discover 发现页 UI

**Files:**
- Create: `solara/frontend/lib/presentation/discover/discover_screen.dart`
- Create: `solara/frontend/lib/presentation/discover/song_list_detail_screen.dart`

### Step 1: 创建 `lib/presentation/discover/discover_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/discover_state.dart';
import '../../domain/state/settings_state.dart';
import '../../domain/models/discover.dart';
import '../../services/player_controller.dart';
import '../../domain/state/queue_state.dart';
import 'song_list_detail_screen.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _source = 'kw';
  final _sources = ['kw', 'wy', 'tx', 'kg', 'mg'];
  final _sourceNames = {'kw': '酷我', 'wy': '网易', 'tx': 'QQ', 'kg': '酷狗', 'mg': '咪咕'};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(discoverStateProvider.notifier).loadAll(source: _source));
  }

  void _changeSource(String source) {
    setState(()downloadService = DownloadService(repository: repository, dio: dio);
    final importExportService = ImportExportService();

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          const PlayerBar(),
          if (debugMode)
            DebugConsole(
              downloadService: downloadService,
              importExportService: importExportService,
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '搜索'),
          BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: '队列'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '收藏'),
        ],
      ),
    );
  }
}
```

### Step 2: 验证
```bash
cd solara/frontend && flutter analyze lib/presentation/home/
```

---

## Task 4: Flutter — NowPlaying 全屏页

**Files:**
- Create: `solara/frontend/lib/presentation/now_playing/now_playing_screen.dart`
- Modify: `solara/frontend/lib/presentation/player/player_bar.dart`

### Step 1: 创建 `lib/presentation/now_playing/now_playing_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/player_controller.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/settings_state.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  final _lyricsController = ScrollController();

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final queueState = ref.watch(queueStateProvider);
    final queueNotifier = ref.read(queueStateProvider.notifier);
    final settings = ref.watch(settingsStateProvider);

    ref.listen(playerControllerProvider, (prev, next) {
      if (next.currentLyricIndex != prev?.currentLyricIndex &&
          next.currentLyricIndex >= 0) {
        final target = next.currentLyricIndex * 36.0;
        _lyricsController.animateTo(
          target.clamp(0, _lyricsController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final song = state.currentSong;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text('正在播放', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              song?.album ?? '',
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 封面
          Expanded(
            flex: 4,
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: state.artworkUrl != null
                      ? Image.network(state.artworkUrl!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
                        ),
                ),
              ),
            ),
          ),
          // 歌曲信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song?.name ?? 'No song playing',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song?.artist ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 歌词
          Expanded(
            flex: 3,
            child: state.lyrics.isEmpty
                ? const Center(child: Text('暂无歌词', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: _lyricsController,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    itemCount: state.lyrics.length,
                    itemBuilder: (context, index) {
                      final line = state.lyrics[index];
                      final active = index == state.currentLyricIndex;
                      return AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: active ? 16 : 14,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          height: 2.2,
                        ),
                        child: Text(line.text, textAlign: TextAlign.center),
                      );
                    },
                  ),
          ),
          // 进度条
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Slider(
                  value: state.duration.inMilliseconds > 0
                      ? state.position.inMilliseconds / state.duration.inMilliseconds
                      : 0.0,
                  onChanged: (v) => controller.seekTo(
                    Duration(milliseconds: (v * state.duration.inMilliseconds).round()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(state.position), style: const TextStyle(fontSize: 12)),
                      Text(_formatDuration(state.duration), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 控制按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 40, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_playModeIcon(queueState.playMode)),
                  onPressed: () => queueNotifier.setPlayMode(
                    PlayMode.values[(queueState.playMode.index + 1) % PlayMode.values.length],
                  ),
                ),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: () {
                    final songs = queueState.songs;
                    final idx = queueState.currentIndex;
                    if (songs.isNotEmpty && idx > 0) {
                      final prev = songs[idx - 1];
                      controller.playSong(prev, quality: settings.playbackQuality);
                      ref.read(queueStateProvider.notifier).state =
                          queueState.copyWith(currentIndex: idx - 1);
                    }
                  },
                ),
                IconButton(
                  iconSize: 64,
                  icon: Icon(
                    state.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: controller.toggle,
                ),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: () {
                    final songs = queueState.songs;
                    final idx = queueState.currentIndex;
                    if (songs.isNotEmpty && idx < songs.length - 1) {
                      final next = songs[idx + 1];
                      controller.playSong(next, quality: settings.playbackQuality);
                      ref.read(queueStateProvider.notifier).state =
                          queueState.copyWith(currentIndex: idx + 1);
                    }
                  },
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _playModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.list: return Icons.repeat;
      case PlayMode.single: return Icons.repeat_one;
      case PlayMode.random: return Icons.shuffle;
    }
  }
}
```

### Step 2: 修改 `player_bar.dart` — 点击触发全屏页

在 `PlayerBar` 的 `build` 方法中，将最外层 `Container` 包裹在 `GestureDetector` 中：

将：
```dart
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
```

改为：
```dart
return GestureDetector(
  onTap: () {
    if (state.currentSong != null) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const NowPlayingScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            );
          },
        ),
      );
    }
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
```

并在末尾闭合多一个括号 `)`。同时在文件顶部加 import：
```dart
import '../now_playing/now_playing_screen.dart';
```

### Step 3: 验证
```bash
cd solara/frontend && flutter analyze lib/presentation/now_playing/ lib/presentation/player/
```

---

## Task 5: Flutter — 底部导航栏替换 TabBar

**Files:**
- Modify: `solara/frontend/lib/presentation/home/home_screen.dart`

### Step 1: 重写 `home_screen.dart`

将现有 `DefaultTabController` + `TabBar` 结构替换为 `BottomNavigationBar`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/favorites_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';
import '../../services/download_service.dart';
import '../../services/import_export_service.dart';
import '../../presentation/debug/debug_console.dart';
import '../../data/providers.dart';
import '../player/player_bar.dart';
import '../search/search_panel.dart';
import '../queue/queue_panel.dart';
import '../favorites/favorites_panel.dart';
import '../discover/discover_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(queueStateProvider);
    final favoritesState = ref.watch(favoritesStateProvider);
    final settings = ref.watch(settingsStateProvider);
    final playerState = ref.watch(playerControllerProvider);
    final repository = ref.watch(solaraRepositoryProvider);
    final dio = ref.watch(apiClientProvider).dio;
    final debugMode = ref.watch(settingsStateProvider).debugMode;

    final downloadService = DownloadService(repository: repository, dio: dio);
    final importExportService = ImportExportService();

    final pages = [
      const DiscoverScreen(),
      const SearchPanel(),
      const QueuePanel(),
      const FavoritesPanel(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solara'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _showSettings(context, ref, downloadService, importExportService),
            icon: const Icon(Icons.settings),
          ),
          if (debugMode)
            IconButton(
              tooltip: 'Toggle debug console',
              onPressed: () {
                final current = ref.read(settingsStateProvider).debugMode;
                ref.read(settingsStateProvider.notifier).setDebugMode(!current);
              },
              icon: const Icon(Icons.bug_report),
            ),
        ],
      ),
      body: Column(
        children: [
          if (debugMode) const DebugConsole(),
          Expanded(child: pages[_currentIndex]),
          const PlayerBar(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '搜索'),
          BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: '队列'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '收藏'),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref,
      DownloadService downloadService, ImportExportService importExportService) {
    // 从原 home_screen.dart 复制 settings dialog 内容
    // 保持原有逻辑不变
    final settings = ref.read(settingsStateProvider);
    final settingsNotifier = ref.read(settingsStateProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: settings.playbackQuality,
              decoration: const InputDecoration(labelText: 'Playback Quality'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'standard', child: Text('Standard')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'super', child: Text('Super')),
                DropdownMenuItem(value: 'flac', child: Text('FLAC')),
              ],
              onChanged: (v) { if (v != null) settingsNotifier.setPlaybackQuality(v); },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}
```

### Step 2: 验证
```bash
cd solara/frontend && flutter analyze lib/presentation/home/
```

---

## Task 6: 端到端测试

### Step 1: 启动后端
```bash
cd solara/backend && go run cmd/server/main.go
```

### Step 2: 启动 Flutter（Chrome）
```bash
cd solara/frontend && flutter run -d chrome
```

### Step 3: 验证清单
- [ ] 登录后进入主页，底部显示4个导航 Tab
- [ ] 点击「发现」Tab，排行榜卡片和歌单列表加载出来
- [ ] 点击排行榜卡片，进入歌曲列表页，点击歌曲可播放
- [ ] 点击歌单，进入歌曲列表页，「播放全部」按钮可用
- [ ] 播放一首歌后，底部 PlayerBar 显示歌曲信息
- [ ] 点击 PlayerBar，全屏 NowPlaying 页弹出
- [ ] NowPlaying 页：封面、歌词滚动、进度条拖动、上下曲均正常
- [ ] 向下滑动或点击左上角箭头关闭 NowPlaying
- [ ] 切换音乐源（酷我/网易/QQ等），数据重新加载

---

## 注意事项

1. **QueueState.setCurrentIndex**: 如果 `QueueState` 没有 `setCurrentIndex` 方法，在 Task 4 Step 1 中需先在 `queue_state.dart` 添加：
```dart
void setCurrentIndex(int index) {
  state = state.copyWith(currentIndex: index);
}
```

2. **musicAPIBase 常量**: `solara_handler.go` 中应已有 `musicAPIBase = "https://music-api.gdstudio.xyz/api.php"`，如无则在文件顶部添加：
```go
const musicAPIBase = "https://music-api.gdstudio.xyz/api.php"
```

3. **排行榜 API 格式**: `music-api.gdstudio.xyz` 可能不支持 `types=leaderboard`，需测试后调整。若不支持，改为在后端返回 mock 榜单列表（名称+id），详情页再实时拉取歌曲。

4. **歌单 API**: `types=songlist` 参数需确认，参考 `types=search` 的格式。
