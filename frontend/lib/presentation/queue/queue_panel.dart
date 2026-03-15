import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';
import '../widgets/playing_indicator.dart';

class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key});

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel> {
  final ScrollController _scrollController = ScrollController();
  bool _didInitialScroll = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentSong(int currentIndex, int total) {
    if (!_scrollController.hasClients || currentIndex < 0) return;
    const itemHeight = 60.0; // ListTile dense height + margin
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset =
        (currentIndex * itemHeight) - (viewportHeight / 2) - (itemHeight / 2);
    _scrollController.jumpTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(queueStateProvider);
    final queue = ref.read(queueStateProvider.notifier);
    final player = ref.read(playerControllerProvider.notifier);
    final playerState = ref.watch(playerControllerProvider);
    final settings = ref.watch(settingsStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (queueState.songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('播放队列为空', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (!_didInitialScroll) {
      _didInitialScroll = true;
      final currentIndex = queueState.songs.indexWhere(
        (s) => s.id == playerState.currentSong?.id &&
            s.source == playerState.currentSong?.source,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentSong(currentIndex, queueState.songs.length);
      });
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: queueState.songs.length,
      itemBuilder: (context, index) {
        final song = queueState.songs[index];
        final isCurrent = playerState.currentSong?.id == song.id &&
            playerState.currentSong?.source == song.source;
        final isPlaying = isCurrent && playerState.isPlaying;

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
            contentPadding: const EdgeInsets.only(left: 12, right: 4),
            leading: SizedBox(
              width: 32,
              height: 32,
              child: isCurrent
                  ? PlayingIndicator(isPlaying: isPlaying, color: colorScheme.primary)
                  : Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
            title: Text(
              song.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? colorScheme.primary : null,
              ),
            ),
            subtitle: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            onTap: () {
              queue.selectSong(song);
              player.playSong(song, quality: settings.playbackQuality);
            },
            trailing: IconButton(
              icon: Icon(Icons.close, size: 18, color: colorScheme.onSurfaceVariant),
              onPressed: () => queue.removeAt(index),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }
}
