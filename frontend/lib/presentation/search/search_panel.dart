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
      final source = ref.read(settingsStateProvider).searchSource;
      ref.read(discoverStateProvider.notifier).ensureLoaded(source: source);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(searchStateProvider.notifier).loadMore();
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'netease':
        return '网易';
      case 'tencent':
        return 'QQ';
      case 'kugou':
        return '酷狗';
      case 'kuwo':
        return '酷我';
      default:
        return source;
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
            PopupMenuButton<String>(
              onSelected: (value) {
                notifier.setSource(value);
                settingsNotifier.setSearchSource(value);
              },
              offset: const Offset(0, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => AppConfig.sources.map((s) {
                final isSelected = s == searchState.source;
                return PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Text(
                        _sourceLabel(s),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? colorScheme.primary : null,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_rounded, size: 18, color: colorScheme.primary),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sourceLabel(searchState.source),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.unfold_more, size: 14, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body:
          searchState.results.isEmpty && searchState.error == null
              ? _buildHomeContent(context, colorScheme, notifier)
              : Column(
                children: [
                  if (searchState.error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        searchState.error!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: searchState.results.length + (searchState.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= searchState.results.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final song = searchState.results[index];
                        final isFavorite = favorites.isFavorite(song);
                        final isPlaying =
                            playerState.isPlaying &&
                            playerState.currentSong?.id == song.id;
                        return ListTile(
                          onTap: () {
                            queue.replaceQueue(searchState.results, song);
                            player.playSong(song, quality: settings.playbackQuality);
                          },
                          title: Text(
                            song.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                isPlaying
                                    ? TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    )
                                    : null,
                          ),
                          subtitle: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: _SongCover(picId: song.picId, source: song.source, picUrl: song.picUrl),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite ? Colors.redAccent : null,
                                ),
                                onPressed: () => favorites.toggleFavorite(song),
                              ),
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: isPlaying ? colorScheme.primary : null,
                                ),
                                onPressed: () {
                                  if (isPlaying) {
                                    player.toggle();
                                  } else {
                                    queue.replaceQueue(searchState.results, song);
                                    player.playSong(song, quality: settings.playbackQuality);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
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
          // ── 猜你喜欢（快捷搜索） ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  AppConfig.genres.take(8).map((genre) {
                    return ActionChip(
                      label: Text(genre, style: const TextStyle(fontSize: 13)),
                      onPressed: () {
                        _controller.text = genre;
                        notifier.search(genre);
                      },
                    );
                  }).toList(),
            ),
          ),

          // ── 排行榜 ──────────────────────────────────
          _SectionTitle(title: '排行榜', icon: Icons.bar_chart_rounded),
          if (discoverState.loading)
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
                  crossAxisCount: 3,
                  childAspectRatio: 1.0,
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
            item.coverUrl != null
                ? Image.network(
                    proxyImageUrl(item.coverUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(colorScheme),
                  )
                : _placeholder(colorScheme),
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

  const _SongCover({required this.picId, required this.source, this.picUrl});

  @override
  State<_SongCover> createState() => _SongCoverState();
}

class _SongCoverState extends State<_SongCover> {
  static final Map<String, String> _cache = {};
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
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
    final placeholder = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.music_note, size: 22, color: colorScheme.onSurfaceVariant),
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
          width: 44,
          height: 44,
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
              width: 44,
              height: 44,
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
