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

  void _showSourceSheet(BuildContext context, String current, ColorScheme colorScheme,
      ValueChanged<String> onSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('选择音源',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface)),
              ),
            ),
            ...AppConfig.sources.map((s) {
              final isSelected = s == current;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(_sourceLabel(s),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                    )),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: colorScheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(s);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
    ref.listen<SettingsState>(settingsStateProvider, (prev, next) {
      if (prev?.discoverSource != next.discoverSource) {
        _loadSource(next.discoverSource);
      }
    });

    final settings = ref.watch(settingsStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = settings.discoverSource;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () => _loadSource(source),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: false,
              toolbarHeight: 56,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              title: const Text('发现', style: TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _showSourceSheet(
                      context, source, colorScheme,
                      (value) => ref.read(settingsStateProvider.notifier).setDiscoverSource(value),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_sourceLabel(source), style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface)),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                              color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: _SectionTitle(title: '精选歌单', icon: Icons.queue_music_rounded),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13)),
                ),
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
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _SongListCard(
                      item: _songLists[index],
                      source: source,
                      index: index,
                    ),
                    childCount: _songLists.length,
                  ),
                ),
              ),
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
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
            width: 4, height: 18,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SongListCard extends StatelessWidget {
  final SongListItem item;
  final String source;
  final int index;
  const _SongListCard({required this.item, required this.source, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SongListDetailScreen(item: item, source: source)),
      ),
      child: Card(
        elevation: 2,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景：网易用封面图，其他用渐变
            source == 'netease' && item.coverUrl != null
                ? Image.network(
                    proxyImageUrl(item.coverUrl!),
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => _gradient(context),
                  )
                : _gradient(context),
            // 底部文字遮罩
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xA6000000)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    if (item.author.isNotEmpty)
                      Text(
                        item.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradient(BuildContext context) {
    final style = _cardStyles[index % _cardStyles.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: style.gradientBegin,
          end: style.gradientEnd,
          colors: style.colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -16, top: -16,
              child: Container(width: 80, height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10)))),
          Positioned(left: -10, bottom: 24,
              child: Container(width: 50, height: 50,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07)))),
          Center(child: Icon(style.icon, size: 40,
              color: Colors.white.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}

class _CardStyle {
  final List<Color> colors;
  final AlignmentGeometry gradientBegin;
  final AlignmentGeometry gradientEnd;
  final IconData icon;
  const _CardStyle({required this.colors, required this.gradientBegin,
      required this.gradientEnd, required this.icon});
}

const _cardStyles = [
  _CardStyle(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)], gradientBegin: Alignment.topLeft, gradientEnd: Alignment.bottomRight, icon: Icons.whatshot_rounded),
  _CardStyle(colors: [Color(0xFF4776E6), Color(0xFF8E54E9)], gradientBegin: Alignment.topRight, gradientEnd: Alignment.bottomLeft, icon: Icons.star_rounded),
  _CardStyle(colors: [Color(0xFF11998E), Color(0xFF38EF7D)], gradientBegin: Alignment.topLeft, gradientEnd: Alignment.bottomRight, icon: Icons.music_note_rounded),
  _CardStyle(colors: [Color(0xFFFC5C7D), Color(0xFF6A3093)], gradientBegin: Alignment.topCenter, gradientEnd: Alignment.bottomCenter, icon: Icons.favorite_rounded),
  _CardStyle(colors: [Color(0xFFF7971E), Color(0xFFFFD200)], gradientBegin: Alignment.topLeft, gradientEnd: Alignment.bottomRight, icon: Icons.emoji_events_rounded),
  _CardStyle(colors: [Color(0xFF1FA2FF), Color(0xFF12D8FA)], gradientBegin: Alignment.topRight, gradientEnd: Alignment.bottomLeft, icon: Icons.headphones_rounded),
  _CardStyle(colors: [Color(0xFF834D9B), Color(0xFFD04ED6)], gradientBegin: Alignment.topLeft, gradientEnd: Alignment.bottomRight, icon: Icons.queue_music_rounded),
  _CardStyle(colors: [Color(0xFF56AB2F), Color(0xFFA8E063)], gradientBegin: Alignment.topCenter, gradientEnd: Alignment.bottomCenter, icon: Icons.album_rounded),
  _CardStyle(colors: [Color(0xFFFF512F), Color(0xFFDD2476)], gradientBegin: Alignment.topLeft, gradientEnd: Alignment.bottomRight, icon: Icons.bar_chart_rounded),
  _CardStyle(colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)], gradientBegin: Alignment.topRight, gradientEnd: Alignment.bottomLeft, icon: Icons.trending_up_rounded),
];
