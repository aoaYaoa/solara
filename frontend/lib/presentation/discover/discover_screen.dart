import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/discover.dart';
import '../../domain/state/settings_state.dart';
import '../../services/app_config.dart';
import '../../services/image_headers.dart' show proxyImageUrl;
import '../../data/providers.dart';
import 'song_list_detail_screen.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scrollController = ScrollController();
  String _currentSource = '';
  List<SongListItem> _songLists = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final source = ref.read(settingsStateProvider).discoverSource;
    if (source != _currentSource) {
      _loadSource(source);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSource(String source) async {
    if (!mounted) return;
    setState(() {
      _currentSource = source;
      _songLists = [];
      _page = 1;
      _hasMore = true;
      _error = null;
      _loading = true;
      _loadingMore = false;
    });
    try {
      final repo = ref.read(solaraRepositoryProvider);
      final items = await repo.fetchSongList(source: source, page: 1);
      if (!mounted || _currentSource != source) return;
      setState(() {
        _songLists = items;
        _loading = false;
        _hasMore = items.length >= 30;
      });
    } catch (e) {
      if (!mounted || _currentSource != source) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    final source = _currentSource;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(solaraRepositoryProvider);
      final nextPage = _page + 1;
      final items = await repo.fetchSongList(source: source, page: nextPage);
      if (!mounted || _currentSource != source) return;
      setState(() {
        _songLists = [..._songLists, ...items];
        _page = nextPage;
        _loadingMore = false;
        _hasMore = items.length >= 30;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'netease':  return '网易';
      case 'tencent':  return 'QQ';
      case 'kugou':    return '酷狗';
      case 'kuwo':     return '酷我';
      case 'youtube':  return 'YouTube';
      case 'bilibili': return 'B站';
      case 'jamendo':  return 'Jamendo';
      default: return source;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听 source 变化，触发重新加载
    ref.listen<SettingsState>(settingsStateProvider, (prev, next) {
      if (prev?.discoverSource != next.discoverSource) {
        _loadSource(next.discoverSource);
      }
    });

    final settings = ref.watch(settingsStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final source = settings.discoverSource;

    return RefreshIndicator(
      onRefresh: () => _loadSource(source),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('发现'),
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    ref.read(settingsStateProvider.notifier).setDiscoverSource(value);
                  },
                  offset: const Offset(0, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => AppConfig.sources.map((s) {
                    final isSelected = s == source;
                    return PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Text(
                            _sourceLabel(s),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? colorScheme.primary : null,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(Icons.check_rounded, size: 18, color: colorScheme.primary),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sourceLabel(source),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.unfold_more, size: 14, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: colorScheme.error)),
              ),
            ),
          SliverToBoxAdapter(
            child: _SectionTitle(title: '精选歌单', icon: Icons.queue_music_rounded),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_songLists.isEmpty)
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
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _SongListTile(item: _songLists[index], source: source),
                  childCount: _songLists.length,
                ),
              ),
            ),
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.coverUrl != null
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
