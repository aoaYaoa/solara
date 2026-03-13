import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/favorites_state.dart';
import '../../domain/state/history_state.dart';
import '../../domain/state/queue_state.dart';
import '../favorites/favorites_panel.dart';
import '../history/history_panel.dart';
import '../queue/queue_panel.dart';
import '../playlist/playlist_screen.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  void _showPanel(BuildContext context, String title, Widget panel) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            builder:
                (_, scrollController) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: panel),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favCount = ref.watch(favoritesStateProvider).favorites.length;
    final histCount = ref.watch(historyStateProvider).entries.length;
    final queueCount = ref.watch(queueStateProvider).songs.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('我的音乐'),
            centerTitle: false,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _QuickEntry(
                    icon: Icons.favorite,
                    label: '收藏',
                    count: favCount,
                    color: Colors.red.shade400,
                    onTap:
                        () =>
                            _showPanel(context, '我的收藏', const FavoritesPanel()),
                  ),
                  const SizedBox(width: 12),
                  _QuickEntry(
                    icon: Icons.history,
                    label: '历史',
                    count: histCount,
                    color: Colors.blue.shade400,
                    onTap:
                        () => _showPanel(context, '播放历史', const HistoryPanel()),
                  ),
                  const SizedBox(width: 12),
                  _QuickEntry(
                    icon: Icons.queue_music,
                    label: '队列',
                    count: queueCount,
                    color: Colors.green.shade400,
                    onTap:
                        () => _showPanel(context, '播放队列', const QueuePanel()),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                '我的歌单',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverFillRemaining(child: PlaylistScreen()),
        ],
      ),
    );
  }
}

class _QuickEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _QuickEntry({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 1,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
