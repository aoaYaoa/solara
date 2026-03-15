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
import 'playing_indicator.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final List<Song>? songList;
  final VoidCallback? onTap;
  final bool showFavorite;

  const SongTile({
    super.key,
    required this.song,
    this.songList,
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
    final playerState = ref.watch(playerControllerProvider);
    final settings = ref.watch(settingsStateProvider);
    final repository = ref.watch(solaraRepositoryProvider);
    final dio = ref.watch(apiClientProvider).dio;
    final colorScheme = Theme.of(context).colorScheme;

    // 判断是否为当前播放歌曲（需要同时比较 id 和 source）
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
        title: Text(
          song.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? colorScheme.primary : null,
          ),
        ),
        subtitle: Text(
          '${song.artist} · ${song.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading:
            showFavorite
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.redAccent : null,
                        ),
                        onPressed: () => favorites.toggleFavorite(song),
                      ),
                      if (isCurrent)
                        Positioned(
                          bottom: 0,
                          child: SizedBox(
                            width: 32,
                            height: 16,
                            child: PlayingIndicator(
                              isPlaying: isPlaying,
                              color: colorScheme.primary,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  )
                : (isCurrent
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: PlayingIndicator(
                          isPlaying: isPlaying,
                          color: colorScheme.primary,
                        ),
                      )
                    : null),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            switch (value) {
              case 'play':
                if (songList != null) {
                  queue.replaceQueue(songList!, song);
                } else {
                  queue.addSong(song);
                }
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
              if (songList != null) {
                queue.replaceQueue(songList!, song);
              } else {
                queue.addSong(song);
              }
              player.playSong(song, quality: settings.playbackQuality);
            },
      ),
    );
  }
}
