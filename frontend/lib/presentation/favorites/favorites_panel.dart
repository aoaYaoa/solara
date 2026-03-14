import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/favorites_state.dart';
import '../../domain/state/settings_state.dart';
import '../../domain/state/queue_state.dart';
import '../../services/player_controller.dart';
import '../../services/image_headers.dart' show proxyImageUrl;
import '../../data/providers.dart';

class FavoritesPanel extends ConsumerWidget {
  const FavoritesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesStateProvider);
    final favorites = ref.read(favoritesStateProvider.notifier);
    final player = ref.read(playerControllerProvider.notifier);
    final queue = ref.read(queueStateProvider.notifier);
    final settings = ref.watch(settingsStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final songs = favoritesState.favorites;

    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_outline, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('暂无收藏', style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
              Text('共 ${songs.length} 首', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('全部播放'),
                onPressed: () {
                  queue.replaceQueue(songs, songs.first);
                  player.playSong(songs.first, quality: settings.playbackQuality);
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
                onTap: () {
                  queue.replaceQueue(songs, song);
                  player.playSong(song, quality: settings.playbackQuality);
                },
                leading: _FavCover(song: song),
                title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                  onPressed: () => favorites.toggleFavorite(song),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}

class _FavCover extends ConsumerStatefulWidget {
  final dynamic song;
  const _FavCover({required this.song});

  @override
  ConsumerState<_FavCover> createState() => _FavCoverState();
}

class _FavCoverState extends ConsumerState<_FavCover> {
  static final Map<String, String> _cache = {};
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.song.picUrl != null) return;
    final key = '${widget.song.source}:${widget.song.picId}';
    if (_cache.containsKey(key) || (widget.song.picId as String).isEmpty) return;
    _future = ref.read(solaraRepositoryProvider)
        .fetchPicUrl(picId: widget.song.picId, source: widget.song.source, size: 100)
        .then((url) { _cache[key] = url; return url; })
        .catchError((_) => '');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.music_note, size: 22, color: colorScheme.onSurfaceVariant),
    );

    String? url = widget.song.picUrl as String?;
    if (url == null) {
      final key = '${widget.song.source}:${widget.song.picId}';
      url = _cache[key];
    }

    Widget buildImage(String u) => ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        proxyImageUrl(u),
        width: 44, height: 44, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );

    if (url != null && url.isNotEmpty) return buildImage(url);
    if (_future == null) return placeholder;
    return FutureBuilder<String?>(
      future: _future,
      builder: (_, snap) {
        if (snap.hasData && snap.data != null && snap.data!.isNotEmpty) return buildImage(snap.data!);
        return placeholder;
      },
    );
  }
}
