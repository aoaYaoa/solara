import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/settings_state.dart';
import '../../services/player_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStateProvider);
    final notifier = ref.read(settingsStateProvider.notifier);
    final timerState = ref.watch(sleepTimerWithPlayerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── 外观 ────────────────────────────────────────
          _SectionLabel(title: '外观'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题模式'),
                subtitle: Text(_themeModeLabel(settings.themeMode)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showThemeModeDialog(context, settings.themeMode, notifier),
              ),
            ],
          ),

          // ── 播放设置 ────────────────────────────────────
          _SectionLabel(title: '播放'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.high_quality_outlined),
                title: const Text('播放音质'),
                subtitle: Text(_qualityLabel(settings.playbackQuality)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showQualityDialog(context, settings.playbackQuality, notifier),
              ),
            ],
          ),

          // ── 均衡器 / 音效 ──────────────────────────────
          _SectionLabel(title: '均衡器 / 音效'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.equalizer_outlined),
                title: const Text('均衡器'),
                subtitle: const Text('即将推出'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                enabled: false,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.surround_sound_outlined),
                title: const Text('空间音效'),
                subtitle: const Text('即将推出'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                enabled: false,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.speed_outlined),
                title: const Text('播放速度'),
                subtitle: const Text('即将推出'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                enabled: false,
              ),
            ],
          ),

          // ── 睡眠定时器 ──────────────────────────────────
          _SectionLabel(title: '睡眠定时器'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: Icon(
                  Icons.bedtime_outlined,
                  color: timerState.active ? colorScheme.primary : null,
                ),
                title: const Text('定时关闭'),
                subtitle: timerState.active && timerState.remaining != null
                    ? Text(_formatRemaining(timerState.remaining!))
                    : const Text('未启用'),
                trailing: timerState.active
                    ? TextButton(
                        onPressed: () => ref.read(sleepTimerWithPlayerProvider.notifier).cancel(),
                        child: const Text('取消'),
                      )
                    : const Icon(Icons.chevron_right, size: 20),
                onTap: timerState.active ? null : () => _showSleepTimerDialog(context, ref),
              ),
            ],
          ),

          // ── 搜索 ───────────────────────────────────────
          _SectionLabel(title: '搜索'),
          _SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.search_outlined),
                title: const Text('搜索来源'),
                subtitle: Text(_sourceLabel(settings.searchSource)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showSourceDialog(context, settings.searchSource, notifier),
              ),
            ],
          ),

          // ── 开发者 ─────────────────────────────────────
          _SectionLabel(title: '开发者'),
          _SettingsGroup(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.bug_report_outlined),
                title: const Text('调试模式'),
                value: settings.debugMode,
                onChanged: (v) => notifier.setDebugMode(v),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _themeModeLabel(String mode) {
    switch (mode) {
      case 'light':
        return '浅色';
      case 'dark':
        return '深色';
      default:
        return '跟随系统';
    }
  }

  String _qualityLabel(String q) {
    switch (q) {
      case '128':
        return '标准 (128kbps)';
      case '192':
        return '高品质 (192kbps)';
      case '320':
        return '无损 (320kbps)';
      default:
        return q;
    }
  }

  String _sourceLabel(String s) {
    switch (s) {
      case 'netease':
        return '网易云音乐';
      case 'qq':
        return 'QQ 音乐';
      default:
        return s;
    }
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '剩余 $m分${s.toString().padLeft(2, '0')}秒';
    return '剩余 $s秒';
  }

  void _showThemeModeDialog(
    BuildContext context,
    String current,
    SettingsStateNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择主题模式'),
        children: [
          for (final entry in {'system': '跟随系统', 'light': '浅色', 'dark': '深色'}.entries)
            SimpleDialogOption(
              onPressed: () {
                notifier.setThemeMode(entry.key);
                Navigator.pop(ctx);
              },
              child: Row(
                children: [
                  if (current == entry.key)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(entry.value),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showQualityDialog(
    BuildContext context,
    String current,
    SettingsStateNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择音质'),
        children: [
          for (final q in ['128', '192', '320'])
            SimpleDialogOption(
              onPressed: () {
                notifier.setPlaybackQuality(q);
                Navigator.pop(ctx);
              },
              child: Row(
                children: [
                  if (current == q)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(_qualityLabel(q)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showSourceDialog(
    BuildContext context,
    String current,
    SettingsStateNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择搜索来源'),
        children: [
          for (final s in ['netease', 'qq'])
            SimpleDialogOption(
              onPressed: () {
                notifier.setSearchSource(s);
                Navigator.pop(ctx);
              },
              child: Row(
                children: [
                  if (current == s)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(_sourceLabel(s)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('设置睡眠定时器'),
        children: [
          for (final entry in {
            '15 分钟': const Duration(minutes: 15),
            '30 分钟': const Duration(minutes: 30),
            '45 分钟': const Duration(minutes: 45),
            '1 小时': const Duration(hours: 1),
            '1.5 小时': const Duration(minutes: 90),
            '2 小时': const Duration(hours: 2),
          }.entries)
            SimpleDialogOption(
              onPressed: () {
                ref.read(sleepTimerWithPlayerProvider.notifier).start(entry.value);
                Navigator.pop(ctx);
              },
              child: Text(entry.key),
            ),
        ],
      ),
    );
  }
}

/// iOS-style section label above a group card.
class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

/// iOS-style grouped card container for settings items.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
