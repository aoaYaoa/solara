import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/search_state.dart';
import '../../domain/state/settings_state.dart';
import '../../domain/state/discover_state.dart';
import '../../domain/models/discover.dart';
import '../../services/player_controller.dart';
import '../../services/app_config.dart';
import '../../services/image_headers.dart' show proxyImageUrl;
import '../../data/providers.dart';
import '../../domain/state/favorites_state.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/history_state.dart';
import '../../domain/models/song.dart';
import '../discover/leaderboard_detail_screen.dart';

class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final source = ref.read(settingsStateProvider).searchSource;
      ref.read(searchStateProvider.notifier).setSource(source);
      ref.read(discoverStateProvider.notifier).ensureLoaded(source: source);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(searchStateProvider.notifier).loadMore();
    }
  }

  void _showSourceSheet(BuildContext context, String current, ColorScheme colorScheme,
      ValueChanged<String> onSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('选择音源',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface)),
              ),
            ),
            ...AppConfig.sources.map((s) {
              final isSelected = s == current;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(_sourceLabel(s),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                    )),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: colorScheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(s);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'netease': return '网易';
      case 'tencent': return 'QQ';
      case 'kugou':   return '酷狗';
      case 'kuwo':    return '酷我';
      case 'youtube': return 'YouTube';
      case 'bilibili': return 'B站';
      case 'jamendo': return 'Jamendo';
      default: return source;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SettingsState>(settingsStateProvider, (prev, next) {
      if (prev != null && prev.searchSource != next.searchSource) {
        ref.read(searchStateProvider.notifier).setSource(next.searchSource);
        ref.read(discoverStateProvider.notifier).loadAll(source: next.searchSource);
      }
    });

    final searchState = ref.watch(searchStateProvider);
    final notifier = ref.read(searchStateProvider.notifier);
    final player = ref.read(playerControllerProvider.notifier);
    final playerState = ref.watch(playerControllerProvider);
    final settings = ref.watch(settingsStateProvider);
    final settingsNotifier = ref.read(settingsStateProvider.notifier);
    final favorites = ref.read(favoritesStateProvider.notifier);
    final queue = ref.read(queueStateProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            // ── 搜索框 ──
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '搜索歌曲、艺术家',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            notifier.search(value.trim());
                            _focusNode.unfocus();
                          }
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (searchState.loading)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          notifier.clearResults();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(Icons.close, size: 18, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ── 音源选择 ──
            GestureDetector(
              onTap: () => _showSourceSheet(
                context, searchState.source, colorScheme,
                (value) {
                  notifier.setSource(value);
                  settingsNotifier.setSearchSource(value);
                  settingsNotifier.setDiscoverSource(value);
                },
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_sourceLabel(searchState.source),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface)),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                        color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          _buildHomeContent(context, colorScheme, notifier),
          if (searchState.results.isNotEmpty || searchState.error != null || searchState.loading)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  notifier.clearResults();
                  _focusNode.unfocus();
                },
              ),
            ),
          if (searchState.results.isNotEmpty || searchState.error != null || searchState.loading)
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surface,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searchState.error != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Text(searchState.error!,
                                style: TextStyle(color: colorScheme.error, fontSize: 13)),
                          ),
                        if (searchState.loading && searchState.results.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          Flexible(
                            child: ListView.builder(
                              controller: _scrollController,
                              shrinkWrap: true,
                              itemCount: searchState.results.length + (searchState.hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= searchState.results.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: SizedBox(width: 24, height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2))),
                                  );
                                }
                                final song = searchState.results[index];
                                final isFavorite = favorites.isFavorite(song);
                                final isPlaying = playerState.isPlaying &&
                                    playerState.currentSong?.id == song.id;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  onTap: () {
                                    queue.replaceQueue(searchState.results, song);
                                    player.playSong(song, quality: settings.playbackQuality);
                                  },
                                  leading: _SongCover(picId: song.picId, source: song.source, picUrl: song.picUrl),
                                  title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: isPlaying ? TextStyle(color: colorScheme.primary,
                                          fontWeight: FontWeight.w600) : null),
                                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                                            size: 20, color: isFavorite ? Colors.redAccent : null),
                                        onPressed: () => favorites.toggleFavorite(song),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      IconButton(
                                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                                            size: 20, color: isPlaying ? colorScheme.primary : null),
                                        onPressed: () {
                                          if (isPlaying) {
                                            player.toggle();
                                          } else {
                                            queue.replaceQueue(searchState.results, song);
                                            player.playSong(song, quality: settings.playbackQuality);
                                          }
                                        },
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(
    BuildContext context,
    ColorScheme colorScheme,
    dynamic notifier,
  ) {
    final discoverState = ref.watch(discoverStateProvider);
    final searchHistory = ref.watch(searchStateProvider).history;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 搜索历史 ──────────────────────────────────
          if (searchHistory.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('搜索历史', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => ref.read(searchStateProvider.notifier).clearHistory(),
                    child: Icon(Icons.delete_outline, size: 18, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: searchHistory.map((h) {
                  return InputChip(
                    label: Text(h, style: const TextStyle(fontSize: 13)),
                    onPressed: () {
                      _controller.text = h;
                      notifier.search(h);
                    },
                    deleteIcon: Icon(Icons.close, size: 14, color: colorScheme.onSurfaceVariant),
                    onDeleted: () => ref.read(searchStateProvider.notifier).removeHistory(h),
                  );
                }).toList(),
              ),
            ),
          ],
          // ── 最近播放 ──────────────────────────────────
          _RecentlyPlayed(onTap: (song) {
            ref.read(playerControllerProvider.notifier).playSong(
              song, quality: ref.read(settingsStateProvider).playbackQuality);
          }),

          // ── 排行榜 ──────────────────────────────────
          _SectionTitle(title: '音乐馆', icon: Icons.bar_chart_rounded),
          if (discoverState.loading && discoverState.leaderboards.isEmpty)
            const SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (discoverState.leaderboards.isEmpty)
            const SizedBox(
              height: 140,
              child: Center(child: Text('暂无排行榜数据')),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.7,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: discoverState.leaderboards.length,
                itemBuilder: (context, index) {
                  final item = discoverState.leaderboards[index];
                  return _LeaderboardCard(
                    item: item,
                    source: ref.read(settingsStateProvider).searchSource,
                  );
                },
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── 排行榜卡片 ───────────────────────────────────────
class _LeaderboardCard extends StatelessWidget {
  final LeaderboardItem item;
  final String source;

  const _LeaderboardCard({required this.item, required this.source});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                LeaderboardDetailScreen(item: item, source: source),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _placeholder(colorScheme),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.bar_chart,
        size: 40,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ── 搜索结果封面懒加载（带内存缓存）────────────────────
class _SongCover extends StatefulWidget {
  final String picId;
  final String source;
  final String? picUrl;
  final double size;

  const _SongCover({required this.picId, required this.source, this.picUrl, this.size = 44});

  @override
  State<_SongCover> createState() => _SongCoverState();
}

class _SongCoverState extends State<_SongCover> {
  static final Map<String, String> _cache = {};
  Future<String?>? _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (widget.picUrl != null) return;
    final key = '${widget.source}:${widget.picId}';
    if (_cache.containsKey(key)) return;
    if (widget.picId.isNotEmpty) {
      _future = ProviderScope.containerOf(context)
          .read(solaraRepositoryProvider)
          .fetchPicUrl(picId: widget.picId, source: widget.source, size: 100)
          .then((url) {
            _cache[key] = url;
            return url;
          })
          .catchError((_) => '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final s = widget.size;
    final placeholder = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.music_note, size: s * 0.5, color: colorScheme.onSurfaceVariant),
    );

    String? resolvedUrl = widget.picUrl;
    if (resolvedUrl == null) {
      final key = '${widget.source}:${widget.picId}';
      resolvedUrl = _cache[key];
    }

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          proxyImageUrl(resolvedUrl),
          width: s,
          height: s,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }

    if (_future == null) return placeholder;

    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData && snap.data != null && snap.data!.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              proxyImageUrl(snap.data!),
              width: s,
              height: s,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
          );
        }
        return placeholder;
      },
    );
  }
}

// ── 分区标题 ──────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecentlyPlayed extends ConsumerWidget {
  final void Function(Song song) onTap;
  const _RecentlyPlayed({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyStateProvider).entries;
    if (history.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final playerState = ref.watch(playerControllerProvider);
    final currentId = playerState.currentSong?.id;
    final currentSource = playerState.currentSong?.source;
    final isPlaying = playerState.isPlaying;
    // 去重，保留最近播放的唯一歌曲，最多6首
    final seen = <String>{};
    final songs = <Song>[];
    for (final e in history) {
      final key = '${e.song.source}:${e.song.id}';
      if (seen.add(key)) songs.add(e.song);
      if (songs.length >= 6) break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('最近播放',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;
              const itemHeight = 48.0;
              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: songs.map((song) {
                  final isCurrent = song.id == currentId && song.source == currentSource;
                  return GestureDetector(
                    onTap: () => onTap(song),
                    child: Container(
                      width: itemWidth,
                      height: itemHeight,
                      decoration: BoxDecoration(
                        color: isCurrent && isPlaying
                            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            child: _SongCover(
                                picId: song.picId, source: song.source, picUrl: song.picUrl,
                                size: itemHeight),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(song.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isCurrent && isPlaying ? colorScheme.primary : null,
                                )),
                          ),
                          if (isCurrent && isPlaying)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.volume_up_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            )
                          else
                            const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
