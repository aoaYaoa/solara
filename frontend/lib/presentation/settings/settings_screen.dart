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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('设置'),
            centerTitle: false,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── App Header ─────────────────────────────
                  _AppHeader(colorScheme: colorScheme, isDark: isDark),
                  const SizedBox(height: 24),

                  // ── 外观 ────────────────────────────────────
                  _SectionLabel(title: '外观'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.palette_outlined,
                        iconColor: Colors.purple,
                        title: '主题模式',
                        trailing: _ThemeModeSegment(
                          current: settings.themeMode,
                          onChanged: notifier.setThemeMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── 播放 ────────────────────────────────────
                  _SectionLabel(title: '播放'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.high_quality_outlined,
                        iconColor: Colors.blue,
                        title: '播放音质',
                        value: _qualityLabel(settings.playbackQuality),
                        onTap: () => _showQualitySheet(context, settings.playbackQuality, notifier),
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.search_outlined,
                        iconColor: Colors.orange,
                        title: '音乐来源',
                        value: _sourceLabel(settings.searchSource),
                        onTap: () => _showSourceSheet(context, settings.searchSource, notifier),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── 睡眠定时器 ──────────────────────────────
                  _SectionLabel(title: '睡眠定时器'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.bedtime_outlined,
                        iconColor: timerState.active ? colorScheme.primary : Colors.indigo,
                        title: '定时关闭',
                        value: timerState.active && timerState.remaining != null
                            ? _formatRemaining(timerState.remaining!)
                            : '未启用',
                        valueColor: timerState.active ? colorScheme.primary : null,
                        trailing: timerState.active
                            ? _CancelChip(
                                onTap: () => ref
                                    .read(sleepTimerWithPlayerProvider.notifier)
                                    .cancel(),
                              )
                            : null,
                        onTap: timerState.active
                            ? null
                            : () => _showSleepTimerSheet(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── 开发者 ──────────────────────────────────
                  _SectionLabel(title: '开发者'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.bug_report_outlined,
                        iconColor: Colors.red,
                        title: '调试模式',
                        trailing: Switch(
                          value: settings.debugMode,
                          onChanged: notifier.setDebugMode,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _qualityLabel(String q) {
    switch (q) {
      case '128': return '标准 (128kbps)';
      case '192': return '高品质 (192kbps)';
      case '320': return '无损 (320kbps)';
      default: return q;
    }
  }

  static String _sourceLabel(String s) {
    switch (s) {
      case 'netease': return '网易云音乐';
      case 'tencent': return 'QQ 音乐';
      case 'kugou': return '酷狗音乐';
      case 'kuwo': return '酷我音乐';
      default: return s;
    }
  }

  static String _formatRemaining(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '剩余 $m分${s.toString().padLeft(2, '0')}秒';
    return '剩余 $s秒';
  }

  void _showQualitySheet(
    BuildContext context,
    String current,
    SettingsStateNotifier notifier,
  ) {
    _showPickerSheet(
      context: context,
      title: '播放音质',
      items: {
        '128': '标准 (128kbps)',
        '192': '高品质 (192kbps)',
        '320': '无损 (320kbps)',
      },
      current: current,
      onSelect: notifier.setPlaybackQuality,
    );
  }

  void _showSourceSheet(
    BuildContext context,
    String current,
    SettingsStateNotifier notifier,
  ) {
    _showPickerSheet(
      context: context,
      title: '音乐来源',
      items: {
        'netease': '网易云音乐',
        'tencent': 'QQ 音乐',
        'kugou': '酷狗音乐',
        'kuwo': '酷我音乐',
      },
      current: current,
      onSelect: notifier.setSearchSource,
    );
  }

  void _showSleepTimerSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('睡眠定时器',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in {
                  '15 分钟': const Duration(minutes: 15),
                  '30 分钟': const Duration(minutes: 30),
                  '45 分钟': const Duration(minutes: 45),
                  '1 小时': const Duration(hours: 1),
                  '1.5 小时': const Duration(minutes: 90),
                  '2 小时': const Duration(hours: 2),
                }.entries)
                  ActionChip(
                    label: Text(entry.key),
                    onPressed: () {
                      ref
                          .read(sleepTimerWithPlayerProvider.notifier)
                          .start(entry.value);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerSheet({
    required BuildContext context,
    required String title,
    required Map<String, String> items,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              for (final entry in items.entries)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(entry.value),
                  trailing: current == entry.key
                      ? Icon(Icons.check_rounded, color: colorScheme.primary)
                      : null,
                  selected: current == entry.key,
                  selectedColor: colorScheme.primary,
                  onTap: () {
                    onSelect(entry.key);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── App Header ────────────────────────────────────────────
class _AppHeader extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isDark;
  const _AppHeader({required this.colorScheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
            colorScheme.secondary.withValues(alpha: isDark ? 0.15 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.music_note_rounded, color: colorScheme.onPrimary, size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solara',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '音乐，随心所至',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Theme Mode Segmented Control ─────────────────────────
class _ThemeModeSegment extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _ThemeModeSegment({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = [
      ('system', Icons.brightness_auto_outlined),
      ('light', Icons.light_mode_outlined),
      ('dark', Icons.dark_mode_outlined),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final selected = current == opt.$1;
        return GestureDetector(
          onTap: () => onChanged(opt.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              opt.$2,
              size: 18,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Cancel chip for sleep timer ──────────────────────────
class _CancelChip extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '取消',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
    );
  }
}

// ── Settings Card ─────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ── Divider ───────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabledColor = colorScheme.onSurface.withValues(alpha: 0.38);

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Colored icon container
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: enabled
                    ? iconColor.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: enabled ? iconColor : disabledColor,
              ),
            ),
            const SizedBox(width: 12),
            // Title + value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: enabled ? null : disabledColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: enabled
                                ? (valueColor ?? colorScheme.onSurfaceVariant)
                                : disabledColor,
                          ),
                    ),
                ],
              ),
            ),
            // Trailing widget or chevron
            if (trailing != null)
              trailing!
            else if (onTap != null && enabled)
              Icon(Icons.chevron_right, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}