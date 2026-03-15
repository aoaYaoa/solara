import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/state/queue_state.dart';
import '../domain/state/settings_state.dart';
import '../presentation/home/home_screen.dart';
import '../presentation/login/login_screen.dart';
import '../services/auth_service.dart';
import '../services/eq_service.dart';
import '../services/player_controller.dart';
import '../services/theme_controller.dart';
import '../services/providers.dart';
import '../data/providers.dart';

class SolaraApp extends ConsumerStatefulWidget {
  const SolaraApp({super.key});

  @override
  ConsumerState<SolaraApp> createState() => _SolaraAppState();
}

class _SolaraAppState extends ConsumerState<SolaraApp> {
  bool _syncInitialized = false;
  bool _sessionRestored = false;
  bool _cookieChecked = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authStateProvider.notifier).restoreSession();
      // 等待队列从持久化加载完成，再恢复上次播放的歌曲
      await ref.read(queueStateProvider.notifier).loaded;
      final queue = ref.read(queueStateProvider);
      if (queue.songs.isNotEmpty) {
        final song = queue.songs[queue.currentIndex.clamp(0, queue.songs.length - 1)];
        await ref.read(playerControllerProvider.notifier).restoreLastSong(song);
      }
      // 恢复 EQ 预设
      final eqPreset = ref.read(settingsStateProvider).eqPreset;
      await EqService.applyPreset(eqPreset);
      // 恢复播放速度
      final speed = ref.read(settingsStateProvider).playbackSpeed;
      if (speed != 1.0) {
        await ref.read(playerControllerProvider.notifier).setSpeed(speed);
      }
      if (mounted) setState(() => _sessionRestored = true);
    });
  }

  Future<void> _checkCookieExpiry() async {
    if (!mounted) return;
    try {
      final svc = ref.read(cookieServiceProvider);
      final status = await svc.fetchStatus();
      if (!mounted) return;
      final warnings = <String>[];
      for (final entry in status.entries) {
        final s = entry.value;
        if (!s.exists) continue;
        final days = s.daysUntilExpiry;
        if (s.isExpired) {
          warnings.add('${entry.key == 'youtube' ? 'YouTube' : 'B站'} Cookie 已过期，请重新上传');
        } else if (days != null && days <= 1) {
          warnings.add('${entry.key == 'youtube' ? 'YouTube' : 'B站'} Cookie 将在 1 天内过期，请及时更新');
        }
      }
      if (warnings.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cookie 即将过期'),
            content: Text(warnings.join('\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  static ThemeMode _resolveThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final themeState = ref.watch(themeControllerProvider);
    final settings = ref.watch(settingsStateProvider);

    if (auth.isAuthed && !_syncInitialized) {
      _syncInitialized = true;
      Future.microtask(() => ref.read(syncControllerProvider).initialize());
    }
    if (auth.isAuthed && _sessionRestored && !_cookieChecked) {
      _cookieChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkCookieExpiry());
    }

    Widget home;
    if (!_sessionRestored) {
      home = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (auth.isAuthed) {
      home = const HomeScreen();
    } else {
      home = const LoginScreen();
    }

    return MaterialApp(
      title: 'Solara',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: themeState.seedColor,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: themeState.seedColor,
        brightness: Brightness.dark,
      ),
      themeMode: _resolveThemeMode(settings.themeMode),
      home: home,
    );
  }
}
