import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/local_songs_state.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';

class LocalSongsPanel extends ConsumerWidget {
  const LocalSongsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.music_note, color: colorScheme.onPrimaryContainer, size: 20),
                ),
                title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              );
            },
          ),
        ),
      ],
    );
  }
}
