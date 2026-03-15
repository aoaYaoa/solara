import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/local_songs_state.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';

class LocalSongsPanel extends ConsumerStatefulWidget {
  const LocalSongsPanel({super.key});

  @override
  ConsumerState<LocalSongsPanel> createState() => _LocalSongsPanelState();
}

class _LocalSongsPanelState extends ConsumerState<LocalSongsPanel> {
  final _scrollController = ScrollController();
  bool _didInitialScroll = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final songs = ref.watch(localSongsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('暂无本地歌曲', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('点击"本地"按钮导入音频文件', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('${songs.length} 首', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('全部播放'),
                onPressed: () {
                  final queue = ref.read(queueStateProvider.notifier);
                  final player = ref.read(playerControllerProvider.notifier);
                  final settings = ref.read(settingsStateProvider);
                  queue.replaceQueue(songs, songs.first);
                  player.playSong(songs.first, quality: settings.playbackQuality);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: songs.length,
            itemBuilder: (context, index) {
              if (!_didInitialScroll && songs.isNotEmpty) {
                _didInitialScroll = true;
                final playerState = ref.watch(playerControllerProvider);
                final currentIndex = songs.indexWhere(
                  (s) => s.id == playerState.currentSong?.id &&
                      s.source == playerState.currentSong?.source,
                );
                if (currentIndex >= 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToCurrentSong(currentIndex, songs.length);
                  });
                }
              }
              final song = songs[index];
              final playerState = ref.watch(playerControllerProvider);
              final isCurrent = playerState.currentSong?.id == song.id &&
                  playerState.currentSong?.source == song.source;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isCurrent
                      ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
                child: ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.music_note, color: colorScheme.onPrimaryContainer, size: 20),
                  ),
                  title: Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isCurrent
                        ? TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          )
                        : null,
                  ),
                  subtitle: song.artist.isNotEmpty
                      ? Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => ref.read(localSongsProvider.notifier).removeSong(song.id),
                  ),
                  onTap: () {
                    final queue = ref.read(queueStateProvider.notifier);
                    final player = ref.read(playerControllerProvider.notifier);
                    final settings = ref.read(settingsStateProvider);
                    queue.replaceQueue(songs, song);
                    player.playSong(song, quality: settings.playbackQuality);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
