import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/favorites_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';

class FavoritesPanel extends ConsumerWidget {
  const FavoritesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesStateProvider);
    final favorites = ref.read(favoritesStateProvider.notifier);
    final player = ref.read(playerControllerProvider.notifier);
    final settings = ref.watch(settingsStateProvider);

    if (favoritesState.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无收藏',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: favoritesState.favorites.length,
      itemBuilder: (context, index) {
        final song = favoritesState.favorites[index];
        return ListTile(
          title: Text(song.name),
          subtitle: Text(song.artist),
          leading: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => player.playSong(song, quality: settings.playbackQuality),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => favorites.toggleFavorite(song),
          ),
        );
      },
    );
  }
}
