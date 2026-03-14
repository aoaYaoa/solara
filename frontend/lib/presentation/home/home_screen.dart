import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/settings_state.dart';
import '../../presentation/debug/debug_console.dart';
import '../../domain/state/queue_state.dart';
import '../../services/player_controller.dart';
import '../player/player_bar.dart';
import '../search/search_panel.dart';
import '../discover/discover_screen.dart';
import '../my/my_screen.dart';
import '../settings/settings_screen.dart';
import '../now_playing/now_playing_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const SearchPanel(),
      const DiscoverScreen(),
      const MyScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  void reassemble() {
    super.reassemble();
    ref.read(playerControllerProvider.notifier).pause();
  }

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '首页'),
    _TabItem(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: '发现'),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: '我的'),
    _TabItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final debugMode = settings.debugMode;

    final isMac = Platform.isMacOS;

    if (isMac) {
      return _MacLayout(
        currentIndex: _currentIndex,
        tabs: _tabs,
        pages: _pages,
        debugMode: debugMode,
        onTap: (i) => setState(() => _currentIndex = i),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: _currentIndex, children: _pages)),
          const PlayerBar(),
          if (debugMode) const DebugConsole(),
        ],
      ),
      bottomNavigationBar: _FrostedNavBar(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── macOS 侧边栏布局 ────────────────────────────────────────────────────────

class _MacLayout extends ConsumerWidget {
  final int currentIndex;
  final List<_TabItem> tabs;
  final List<Widget> pages;
  final bool debugMode;
  final ValueChanged<int> onTap;

  const _MacLayout({
    required this.currentIndex,
    required this.tabs,
    required this.pages,
    required this.debugMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // ── 侧边栏 ──
          _MacSidebar(
            currentIndex: currentIndex,
            tabs: tabs,
            isDark: isDark,
            colorScheme: colorScheme,
            onTap: onTap,
          ),
          // ── 内容区 ──
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: IndexedStack(index: currentIndex, children: pages),
                    ),
                  ),
                ),
                if (debugMode) const DebugConsole(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacSidebar extends ConsumerWidget {
  final int currentIndex;
  final List<_TabItem> tabs;
  final bool isDark;
  final ColorScheme colorScheme;
  final ValueChanged<int> onTap;

  const _MacSidebar({
    required this.currentIndex,
    required this.tabs,
    required this.isDark,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.75),
            border: Border(
              right: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部 app 名称
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Solara',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 导航项
              ...List.generate(tabs.length, (i) {
                final tab = tabs[i];
                final selected = i == currentIndex;
                return _SidebarItem(
                  icon: selected ? tab.activeIcon : tab.icon,
                  label: tab.label,
                  selected: selected,
                  colorScheme: colorScheme,
                  onTap: () => onTap(i),
                );
              }),
              const Spacer(),
              // 播放器
              const _SidebarPlayer(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarPlayer extends ConsumerWidget {
  const _SidebarPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final settings = ref.watch(settingsStateProvider);
    final queueState = ref.watch(queueStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 同步播放动画
    final position = state.position;
    final duration = state.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: state.currentSong == null
          ? null
          : () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, animation, __) => FadeTransition(
                    opacity: animation,
                    child: const NowPlayingScreen(),
                  ),
                  fullscreenDialog: true,
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              ),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 歌曲信息
          Text(
            state.currentSong?.name ?? '未在播放',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (state.currentSong != null)
            Text(
              state.currentSong!.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          const SizedBox(height: 8),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: queueState.songs.isEmpty
                    ? null
                    : () => controller.skipPrevious(
                          queue: queueState.songs,
                          currentIndex: queueState.currentIndex,
                          playMode: queueState.playMode,
                          quality: settings.playbackQuality,
                        ),
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 22,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              Material(
                color: state.currentSong != null
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.1),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: state.currentSong != null ? controller.toggle : null,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      state.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: state.currentSong != null
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: queueState.songs.isEmpty
                    ? null
                    : () => controller.skipNext(
                          queue: queueState.songs,
                          currentIndex: queueState.currentIndex,
                          playMode: queueState.playMode,
                          quality: settings.playbackQuality,
                        ),
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 22,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

// ── iOS/通用底部导航 ─────────────────────────────────────────────────────────

class _FrostedNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;

  const _FrostedNavBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.75),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final tab = tabs[i];
                final selected = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              selected ? tab.activeIcon : tab.icon,
                              key: ValueKey(selected),
                              size: 24,
                              color: selected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              color: selected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            width: selected ? 20 : 0,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
