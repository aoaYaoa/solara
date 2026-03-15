import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/discover.dart';
import '../../domain/models/song.dart';
import '../../domain/state/discover_state.dart';
import '../../domain/state/settings_state.dart';
import '../../domain/state/queue_state.dart';
import '../../services/player_controller.dart';

class LeaderboardDetailScreen extends ConsumerStatefulWidget {
  final LeaderboardItem item;
  final String source;

  const LeaderboardDetailScreen({
    super.key,
    required this.item,
    required this.source,
  });

  @override
  ConsumerState<LeaderboardDetailScreen> createState() =>
      _LeaderboardDetailScreenState();
}

class _LeaderboardDetailScreenState
    extends ConsumerState<LeaderboardDetailScreen> {
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
          .fetchLeaderboardDetail(id: widget.item.id, source: widget.source, page: 1);
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
          .fetchLeaderboardDetail(id: widget.item.id, source: widget.source, page: nextPage);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name),
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
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _songs.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
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
                    if (index >= _songs.length) {
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
                    final song = _songs[index];
                    final isCurrent = playerState.currentSong?.id == song.id &&
                        playerState.currentSong?.source == song.source;
                    final isPlaying = isCurrent && playerState.isPlaying;
                    final isTop3 = index < 3;
                    final colorScheme = Theme.of(context).colorScheme;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: isCurrent
                            ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                      child: ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 28,
                          child: Center(
                            child: isTop3
                                ? Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: song.name,
                                style: TextStyle(
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent ? colorScheme.primary : null,
                                ),
                              ),
                              TextSpan(
                                text: ' - ${song.artist}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_outline,
                            color: isCurrent ? colorScheme.primary : null,
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
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
