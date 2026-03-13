import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/song.dart';
import '../../domain/state/favorites_state.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';
import '../../data/providers.dart';
import '../../services/download_service.dart';
import '../playlist/playlist_screen.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;
  final bool showFavorite;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.showFavorite = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.read(favoritesStateProvider.notifier);
    final isFavorite = ref
        .watch(favoritesStateProvider)
        .favorites
        .any((s) => s.id == song.id && s.source == song.source);
    final queue = ref.read(queueStateProvider.notifier);
    final player = ref.read(playerControllerProvider.notifier);
    final settings = ref.watch(settingsStateProvider);
    final repository = ref.watch(solaraRepositoryProvider);
    final dio = ref.watch(apiClientProvider).dio;

    return ListTile(
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${song.artist} · ${song.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading:
          showFavorite
              ? IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.redAccent : null,
                ),
                onPressed: () => favorites.toggleFavorite(song),
              )
              : null,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          switch (value) {
            case 'play':
              queue.addSong(song);
              player.playSong(song, quality: settings.playbackQuality);
            case 'queue':
              queue.addSong(song);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已加入队列：${song.name}')));
            case 'playlist':
              showModalBottomSheet(
                context: context,
                builder: (_) => AddToPlaylistSheet(song: song),
              );
            case 'download':
              final ds = DownloadService(repository: repository, dio: dio);
              try {
                final path = await ds.downloadSong(
                  song: song,
                  quality: settings.playbackQuality,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(path != null ? '已保存：$path' : '下载取消'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('下载失败：$e')));
                }
              }
          }
        },
        itemBuilder:
            (_) => const [
              PopupMenuItem(
                value: 'play',
                child: ListTile(
                  leading: Icon(Icons.play_arrow),
                  title: Text('播放'),
                ),
              ),
              PopupMenuItem(
                value: 'queue',
                child: ListTile(
                  leading: Icon(Icons.queue_music),
                  title: Text('加入队列'),
                ),
              ),
              PopupMenuItem(
                value: 'playlist',
                child: ListTile(
                  leading: Icon(Icons.library_add),
                  title: Text('加入歌单'),
                ),
              ),
              PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('下载'),
                ),
              ),
            ],
      ),
      onTap:
          onTap ??
          () {
            queue.addSong(song);
            player.playSong(song, quality: settings.playbackQuality);
          },
    );
  }
}
