import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/settings_state.dart';
import '../../presentation/debug/debug_console.dart';
import '../../services/player_controller.dart';
import '../player/player_bar.dart';
import '../search/search_panel.dart';
import '../discover/discover_screen.dart';
import '../my/my_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void reassemble() {
    super.reassemble();
    // 热重载时停止音乐，保持状态一致
    ref.read(playerControllerProvider.notifier).pause();
  }

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '首页'),
    _TabItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: '发现',
    ),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: '我的'),
    _TabItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final debugMode = settings.debugMode;

    final pages = [
      const SearchPanel(),
      const DiscoverScreen(),
      const MyScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: _currentIndex, children: pages)),
          const PlayerBar(),
          if (debugMode) const DebugConsole(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations:
            _tabs
                .map(
                  (tab) => NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.activeIcon),
                    label: tab.label,
                  ),
                )
                .toList(),
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
