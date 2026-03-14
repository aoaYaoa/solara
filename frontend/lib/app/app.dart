import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/state/queue_state.dart';
import '../domain/state/settings_state.dart';
import '../presentation/home/home_screen.dart';
import '../presentation/login/login_screen.dart';
import '../services/auth_service.dart';
import '../services/player_controller.dart';
import '../services/theme_controller.dart';
import '../services/providers.dart';

class SolaraApp extends ConsumerStatefulWidget {
  const SolaraApp({super.key});

  @override
  ConsumerState<SolaraApp> createState() => _SolaraAppState();
}

class _SolaraAppState extends ConsumerState<SolaraApp> {
  bool _syncInitialized = false;
  bool _sessionRestored = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authStateProvider.notifier).restoreSession();
      // 恢复上次播放的歌曲（仅显示，不自动播放）
      final queue = ref.read(queueStateProvider);
      if (queue.songs.isNotEmpty) {
        final song = queue.songs[queue.currentIndex.clamp(0, queue.songs.length - 1)];
        ref.read(playerControllerProvider.notifier).restoreLastSong(song);
      }
      if (mounted) setState(() => _sessionRestored = true);
    });
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
