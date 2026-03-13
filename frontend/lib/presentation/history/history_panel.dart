import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/history_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';

class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyStateProvider);
    final player = ref.read(playerControllerProvider.notifier);
    final settings = ref.watch(settingsStateProvider);

    if (historyState.entries.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('暂无播放历史', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 顶部操作栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '共 ${historyState.entries.length} 首',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('清空'),
                onPressed:
                    () => showDialog(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text('清空历史'),
                            content: const Text('确定要清空所有播放历史吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(historyStateProvider.notifier)
                                      .clear();
                                  Navigator.pop(ctx);
                                },
                                child: Text(
                                  '清空',
                                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                                ),
                              ),
                            ],
                          ),
                    ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: historyState.entries.length,
            itemBuilder: (context, index) {
              final entry = historyState.entries[index];
              final song = entry.song;
              final timeAgo = _formatTimeAgo(entry.playedAt);
              return ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(
                  song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${song.artist} · $timeAgo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed:
                      () => ref
                          .read(historyStateProvider.notifier)
                          .removeEntry(entry),
                ),
                onTap:
                    () => player.playSong(
                      song,
                      quality: settings.playbackQuality,
                    ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}
