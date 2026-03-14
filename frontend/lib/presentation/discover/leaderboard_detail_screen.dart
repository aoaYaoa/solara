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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
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
                    final isCurrent = playerState.currentSong?.id == song.id;
                    final isTop3 = index < 3;
                    final colorScheme = Theme.of(context).colorScheme;
                    return ListTile(
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
                                    color: colorScheme.onSurfaceVariant,
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
                          playerState.isPlaying && isCurrent
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_outline,
                          color: isCurrent ? colorScheme.primary : null,
                        ),
                        onPressed: () {
                          if (playerState.isPlaying && isCurrent) {
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
                    );
                  },
                ),
              ),
    );
  }
}
