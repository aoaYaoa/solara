import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/discover_state.dart';
import '../../domain/models/discover.dart';
import '../../services/image_headers.dart' show proxyImageUrl;
import '../../domain/state/settings_state.dart';
import 'song_list_detail_screen.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final source = ref.read(settingsStateProvider).searchSource;
      ref.read(discoverStateProvider.notifier).loadAll(source: source);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverStateProvider);
    final settings = ref.watch(settingsStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<SettingsState>(settingsStateProvider, (prev, next) {
      if (prev?.searchSource != next.searchSource) {
        ref.read(discoverStateProvider.notifier).loadAll(source: next.searchSource);
      }
    });

    return RefreshIndicator(
      onRefresh:
          () =>
              ref.read(discoverStateProvider.notifier).loadAll(source: settings.searchSource),
      child: CustomScrollView(
        slivers: [
          if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  state.error!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          // ── 精选歌单 ────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionTitle(title: '精选歌单', icon: Icons.queue_music_rounded),
          ),
          if (state.loadingSongLists)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (state.songLists.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('暂无歌单数据')),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = state.songLists[index];
                  return _SongListTile(item: item, source: settings.searchSource);
                }, childCount: state.songLists.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

/// Section title with a decorative icon.
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _SongListTile extends StatelessWidget {
  final SongListItem item;
  final String source;

  const _SongListTile({required this.item, required this.source});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0.5,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              item.coverUrl != null
                  ? Image.network(
                    proxyImageUrl(item.coverUrl!),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(colorScheme),
                  )
                  : _placeholder(colorScheme),
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.author.isNotEmpty ? item.author : (item.playCount ?? ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SongListDetailScreen(item: item, source: source),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      width: 50,
      height: 50,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.queue_music, color: colorScheme.onSurfaceVariant),
    );
  }
}
