import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/history_entry.dart';
import '../../domain/state/history_state.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';

class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyStateProvider);
    final player = ref.read(playerControllerProvider.notifier);
    final queue = ref.read(queueStateProvider.notifier);
    final settings = ref.watch(settingsStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (historyState.entries.isEmpty) {
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

    // 按日期分组
    final groups = _groupByDate(historyState.entries);
    // 构建扁平列表项：header 或 entry
    final items = <_ListItem>[];
    for (final group in groups) {
      items.add(_ListItem.header(group.label));
      for (final entry in group.entries) {
        items.add(_ListItem.entry(entry));
      }
    }
    final songs = historyState.entries.map((e) => e.song).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('共 ${historyState.entries.length} 首', style: Theme.of(context).textTheme.bodySmall),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('清空'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清空历史'),
                    content: const Text('确定要清空所有播放历史吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      TextButton(
                        onPressed: () {
                          ref.read(historyStateProvider.notifier).clear();
                          Navigator.pop(ctx);
                        },
                        child: Text('清空', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
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
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isHeader) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    item.label!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              final entry = item.entry!;
              final song = entry.song;
              return ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${song.artist} · ${_formatTime(entry.playedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => ref.read(historyStateProvider.notifier).removeEntry(entry),
                ),
                onTap: () {
                  queue.replaceQueue(songs, song);
                  player.playSong(song, quality: settings.playbackQuality);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<_DateGroup> _groupByDate(List<HistoryEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final groups = <String, List<HistoryEntry>>{};
    for (final e in entries) {
      final d = DateTime(e.playedAt.year, e.playedAt.month, e.playedAt.day);
      final String label;
      if (d == today) label = '今天';
      else if (d == yesterday) label = '昨天';
      else if (now.difference(d).inDays < 7) label = '${now.difference(d).inDays}天前';
      else label = '${e.playedAt.month}月${e.playedAt.day}日';
      groups.putIfAbsent(label, () => []).add(e);
    }
    return groups.entries.map((e) => _DateGroup(label: e.key, entries: e.value)).toList();
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DateGroup {
  final String label;
  final List<HistoryEntry> entries;
  const _DateGroup({required this.label, required this.entries});
}

class _ListItem {
  final bool isHeader;
  final String? label;
  final HistoryEntry? entry;
  const _ListItem._({required this.isHeader, this.label, this.entry});
  factory _ListItem.header(String label) => _ListItem._(isHeader: true, label: label);
  factory _ListItem.entry(HistoryEntry e) => _ListItem._(isHeader: false, entry: e);
}
