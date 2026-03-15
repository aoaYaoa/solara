import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/discover.dart';
import '../../domain/models/song.dart';
import '../../domain/state/discover_state.dart';
import '../../services/image_headers.dart' show proxyImageUrl;
import '../../domain/state/settings_state.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/favorites_state.dart';
import '../../services/player_controller.dart';

class SongListDetailScreen extends ConsumerStatefulWidget {
  final SongListItem item;
  final String source;

  const SongListDetailScreen({
    super.key,
    required this.item,
    required this.source,
  });

  @override
  ConsumerState<SongListDetailScreen> createState() =>
      _SongListDetailScreenState();
}

class _SongListDetailScreenState extends ConsumerState<SongListDetailScreen> {
  final _scrollController = ScrollController();
  List<Song> _songs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  void _scrollToCurrentSong(int currentIndex, int total) {
    if (!_scrollController.hasClients || currentIndex < 0) return;
    const itemHeight = 60.0;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (currentIndex * itemHeight) - (viewportHeight / 2) - (itemHeight / 2);
    _scrollController.jumpTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final songs = await ref
          .read(discoverStateProvider.notifier)
          .fetchSongListDetail(id: widget.item.id, source: widget.source, page: 1);
      if (mounted) {
        setState(() {
          _songs = songs;
          _hasMore = songs.length >= 30;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final songs = await ref
          .read(discoverStateProvider.notifier)
          .fetchSongListDetail(id: widget.item.id, source: widget.source, page: nextPage);
      if (mounted) {
        setState(() {
          _songs = [..._songs, ...songs];
          _page = nextPage;
          _hasMore = songs.length >= 30;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final player = ref.read(playerControllerProvider.notifier);
    final playerState = ref.watch(playerControllerProvider);
    final queue = ref.read(queueStateProvider.notifier);
    final favorites = ref.read(favoritesStateProvider.notifier);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: 200,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.item.name,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                background:
                    widget.item.coverUrl != null
                        ? Image.network(
                          proxyImageUrl(widget.item.coverUrl!),
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          errorBuilder:
                              (_, __, ___) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.queue_music,
                                  size: 60,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                        )
                        : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.queue_music,
                            size: 60,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
              ),
              actions: [
                if (_songs.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    tooltip: '全部播放',
                    onPressed: () {
                      queue.replaceQueue(_songs, _songs.first);
                      player.playSong(
                        _songs.first,
                        quality: settings.playbackQuality,
                      );
                    },
                  ),
              ],
            ),
            if (widget.item.description != null &&
                widget.item.description!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    widget.item.description!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                ),
              )
            else ...[
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (!_didInitialScroll && !_loading && _songs.isNotEmpty) {
                    _didInitialScroll = true;
                    final currentIndex = _songs.indexWhere(
                      (s) => s.id == playerState.currentSong?.id &&
                          s.source == playerState.currentSong?.source,
                    );
                    if (currentIndex >= 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToCurrentSong(currentIndex, _songs.length);
                      });
                    }
                  }
                  final song = _songs[index];
                  final isFav = favorites.isFavorite(song);
                  final isCurrent = playerState.currentSong?.id == song.id &&
                      playerState.currentSong?.source == song.source;
                  final isPlaying = isCurrent && playerState.isPlaying;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                    child: ListTile(
                      leading: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      title: Text(
                        song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: isCurrent
                            ? TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                            ),
                            onPressed: () => favorites.toggleFavorite(song),
                          ),
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            onPressed: () {
                              if (isPlaying) {
                                player.pause();
                              } else {
                                queue.replaceQueue(_songs, song);
                                player.playSong(
                                  song,
                                  quality: settings.playbackQuality,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: _songs.length),
              ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
