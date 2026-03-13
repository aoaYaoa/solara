import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';

class QueuePanel extends ConsumerWidget {
  const QueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return ListView.builder(
      itemCount: queueState.songs.length,
      itemBuilder: (context, index) {
        final song = queueState.songs[index];
        final isCurrent = playerState.currentSong?.id == song.id;
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
                  ? _PlayingIndicator(isPlaying: isPlaying, color: colorScheme.primary)
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

/// Animated equalizer bars indicating playback status.
class _PlayingIndicator extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const _PlayingIndicator({required this.isPlaying, required this.color});

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  static const _barCount = 4;
  // Each bar has a different duration for a natural look
  static const _durations = [450, 550, 400, 500];
  static const _minHeight = 0.15;
  static const _maxHeights = [0.9, 0.7, 1.0, 0.65];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_barCount, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _durations[i]),
      );
    });
    _animations = List.generate(_barCount, (i) {
      return Tween<double>(begin: _minHeight, end: _maxHeights[i]).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
      );
    });
    if (widget.isPlaying) _startAnimations();
  }

  @override
  void didUpdateWidget(covariant _PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _startAnimations();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _stopAnimations();
    }
  }

  void _startAnimations() {
    for (final c in _controllers) {
      c.repeat(reverse: true);
    }
  }

  void _stopAnimations() {
    for (final c in _controllers) {
      c.stop();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(_controllers),
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_barCount, (i) {
            final height = widget.isPlaying
                ? _animations[i].value
                : (_minHeight + 0.15 * (i % 2 == 0 ? 1 : 0.5));
            return Container(
              width: 3,
              height: 18 * height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
