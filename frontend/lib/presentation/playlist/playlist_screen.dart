import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user_playlist.dart';
import '../../domain/models/song.dart';
import '../../domain/state/playlist_state.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playlistStateProvider);

    return state.playlists.isEmpty
        ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_music_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text('暂无歌单', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('创建歌单'),
                onPressed: () => _showCreateDialog(context, ref),
              ),
            ],
          ),
        )
        : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.playlists.length} 个歌单',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建'),
                    onPressed: () => _showCreateDialog(context, ref),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: state.playlists.length,
                itemBuilder: (context, index) {
                  final playlist = state.playlists[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${playlist.songs.length}'),
                    ),
                    title: Text(playlist.name),
                    subtitle:
                        playlist.description != null
                            ? Text(
                              playlist.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                            : Text('${playlist.songs.length} 首'),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed:
                          () => _showPlaylistMenu(context, ref, playlist),
                    ),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => PlaylistDetailScreen(playlist: playlist),
                          ),
                        ),
                  );
                },
              ),
            ),
          ],
        );
  }

  void _showCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    UserPlaylist? editing,
  }) {
    final nameController = TextEditingController(text: editing?.name);
    final descController = TextEditingController(text: editing?.description);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(editing == null ? '新建歌单' : '编辑歌单'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '歌单名称',
                    hintText: '我的歌单',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '描述（可选）'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  if (editing == null) {
                    ref
                        .read(playlistStateProvider.notifier)
                        .createPlaylist(
                          name: name,
                          description:
                              descController.text.trim().isEmpty
                                  ? null
                                  : descController.text.trim(),
                        );
                  } else {
                    ref
                        .read(playlistStateProvider.notifier)
                        .renamePlaylist(editing.id, name);
                  }
                  Navigator.pop(ctx);
                },
                child: Text(editing == null ? '创建' : '保存'),
              ),
            ],
          ),
    );
  }

  void _showPlaylistMenu(
    BuildContext context,
    WidgetRef ref,
    UserPlaylist playlist,
  ) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('编辑信息'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreateDialog(context, ref, editing: playlist);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: Theme.of(ctx).colorScheme.error),
                  title: Text(
                    '删除歌单',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(playlistStateProvider.notifier)
                        .deletePlaylist(playlist.id);
                  },
                ),
              ],
            ),
          ),
    );
  }
}

// 歌单详情页
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final UserPlaylist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
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
    // 从 provider 获取最新数据
    final state = ref.watch(playlistStateProvider);
    final current = state.playlists.firstWhere(
      (p) => p.id == widget.playlist.id,
      orElse: () => widget.playlist,
    );
    final player = ref.read(playerControllerProvider.notifier);
    final queueNotifier = ref.read(queueStateProvider.notifier);
    final settings = ref.watch(settingsStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          if (current.songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: '全部播放',
              onPressed: () {
                queueNotifier.replaceQueue(current.songs, current.songs.first);
                player.playSong(
                  current.songs.first,
                  quality: settings.playbackQuality,
                );
              },
            ),
        ],
      ),
      body:
          current.songs.isEmpty
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_off_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '歌单为空，从搜索结果添加歌曲吧',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                controller: _scrollController,
                itemCount: current.songs.length,
                itemBuilder: (context, index) {
                  if (!_didInitialScroll && current.songs.isNotEmpty) {
                    _didInitialScroll = true;
                    final playerState = ref.watch(playerControllerProvider);
                    final currentIndex = current.songs.indexWhere(
                      (s) => s.id == playerState.currentSong?.id &&
                          s.source == playerState.currentSong?.source,
                    );
                    if (currentIndex >= 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToCurrentSong(currentIndex, current.songs.length);
                      });
                    }
                  }
                  final song = current.songs[index];
                  final playerState = ref.watch(playerControllerProvider);
                  final isCurrent = playerState.currentSong?.id == song.id &&
                      playerState.currentSong?.source == song.source;
                  final isPlaying = isCurrent && playerState.isPlaying;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                    child: ListTile(
                      title: Text(
                        song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: isCurrent
                            ? TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        '${song.artist} · ${song.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            onPressed: () {
                              if (isPlaying) {
                                player.pause();
                              } else {
                                queueNotifier.replaceQueue(current.songs, song);
                                player.playSong(
                                  song,
                                  quality: settings.playbackQuality,
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed:
                                () => ref
                                    .read(playlistStateProvider.notifier)
                                    .removeSongFromPlaylist(current.id, song),
                          ),
                        ],
                      ),
                      onTap: () {
                        queueNotifier.replaceQueue(current.songs, song);
                        player.playSong(
                          song,
                          quality: settings.playbackQuality,
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }
}

// 添加到歌单的弹窗（供搜索/队列等页面调用）
class AddToPlaylistSheet extends ConsumerWidget {
  final Song song;
  const AddToPlaylistSheet({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playlistStateProvider);
    final notifier = ref.read(playlistStateProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '添加到歌单',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (state.playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无歌单，请先创建歌单'),
            )
          else
            ...state.playlists.map(
              (p) => ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(p.name),
                subtitle: Text('${p.songs.length} 首'),
                onTap: () {
                  notifier.addSongToPlaylist(p.id, song);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('已添加到 ${p.name}')));
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
