import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/song.dart';
import '../domain/state/history_state.dart';
import '../domain/state/player_state.dart';
import '../domain/state/settings_state.dart';
import '../services/providers.dart';
import '../services/sleep_timer_service.dart';
import '../domain/state/queue_state.dart';
import '../data/solara_repository.dart';
import '../data/providers.dart';
import '../platform/audio_engine.dart';
import '../platform/just_audio_engine.dart';
import '../services/lyric_parser.dart';
import '../services/theme_controller.dart';
import '../services/auth_service.dart';
import '../services/app_config.dart';
import '../main.dart' show audioHandler, sharedPlayer;

class PlayerController extends StateNotifier<PlayerState> {
  final SolaraRepository repository;
  final AudioEngine engine;
  final ThemeController themeController;
  final AuthStateNotifier auth;
  final void Function(Song)? onSongPlayed;
  Timer? _timer;
  StreamSubscription<void>? _completeSub;
  List<Song> Function()? getQueue;
  PlayMode Function()? getPlayMode;
  int Function()? getCurrentQueueIndex;
  void Function(int)? setCurrentQueueIndex;
  String Function()? getQuality;
  bool _isLoading = false;

  PlayerController({
    required this.repository,
    required this.engine,
    required this.themeController,
    required this.auth,
    this.onSongPlayed,
    this.getQueue,
    this.getPlayMode,
    this.getCurrentQueueIndex,
    this.setCurrentQueueIndex,
    this.getQuality,
  }) : super(PlayerState.initial()) {
    // 热重载后原生播放器可能还在播放，先停掉保持状态一致
    if (engine.isPlaying) {
      engine.stop();
    }
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _tick();
    });
    _completeSub = engine.onComplete.listen((_) {
      _onSongComplete();
    });
  }

  void _onSongComplete() {
    final queue = getQueue?.call() ?? [];
    final playMode = getPlayMode?.call() ?? PlayMode.list;
    final currentIndex = getCurrentQueueIndex?.call() ?? 0;
    final quality = getQuality?.call() ?? '320';
    if (queue.isEmpty) {
      if (state.currentSong != null) {
        playSong(state.currentSong!, quality: quality);
      }
      return;
    }
    if (playMode == PlayMode.single) {
      if (state.currentSong != null) {
        playSong(state.currentSong!, quality: quality);
      }
      return;
    }
    skipNext(
      queue: queue,
      currentIndex: currentIndex,
      playMode: playMode,
      quality: quality,
    );
  }

  void _tick() {
    // 加载新歌曲期间不更新，避免引擎返回旧歌曲的 position/duration 覆盖新状态
    if (_isLoading) return;
    final position = engine.position;
    final duration = engine.duration;
    if (position != state.position || duration != state.duration) {
      final currentIndex = _resolveLyricIndex(state.lyrics, position);
      state = state.copyWith(
        position: position,
        duration: duration,
        currentLyricIndex: currentIndex,
      );
    }
  }

  int _resolveLyricIndex(List lyrics, Duration position) {
    if (lyrics.isEmpty) return -1;
    for (var i = lyrics.length - 1; i >= 0; i--) {
      final line = lyrics[i];
      if (line.time <= position) {
        return i;
      }
    }
    return -1;
  }

  Future<void> playSong(Song song, {required String quality}) async {
    _isLoading = true;

    // 完整重置状态：直接构造新 PlayerState，避免 copyWith 的 nullable 遗留问题
    state = PlayerState(
      currentSong: song,
      isPlaying: state.isPlaying,
      position: Duration.zero,
      duration: null,
      lyrics: const [],
      currentLyricIndex: -1,
      artworkUrl: null,
      error: null,
    );

    // 自动同步队列索引
    final queue = getQueue?.call() ?? [];
    final songIndex = queue.indexWhere((s) => s.id == song.id);
    if (songIndex >= 0) {
      setCurrentQueueIndex?.call(songIndex);
    }

    // 更新锁屏/通知栏信息
    audioHandler.setNowPlaying(
      title: song.name,
      artist: song.artist,
    );

    try {
      final url = await repository.fetchSongUrl(
        songId: song.id,
        source: song.source,
        quality: quality,
      );
      await engine.setSource(url);
      engine.play().catchError((e) {
        print('[PlayerController] play() error (ignored): $e');
      });

      // 引擎就绪，解除 loading 锁，让 _tick() 开始同步
      _isLoading = false;
      state = state.copyWith(isPlaying: true);

      // 后台加载歌词
      try {
        final lyricRaw = await repository.fetchLyric(
          songId: song.lyricId.isNotEmpty ? song.lyricId : song.id,
          source: song.source,
        );
        final lyrics = LyricParser.parse(lyricRaw);
        state = state.copyWith(lyrics: lyrics);
      } catch (_) {}

      // 后台加载封面
      try {
        String artworkUrl;
        if (song.picUrl != null && song.picUrl!.isNotEmpty) {
          final encoded = Uri.encodeComponent(song.picUrl!);
          artworkUrl = '${AppConfig.baseUrl}/imgproxy?url=$encoded';
        } else {
          artworkUrl = await repository.fetchPicUrl(
            picId: song.picId,
            source: song.source,
          );
        }
        await themeController.updateFromArtwork(artworkUrl);
        state = state.copyWith(artworkUrl: artworkUrl);
        audioHandler.setNowPlaying(
          title: song.name,
          artist: song.artist,
          artworkUrl: artworkUrl,
          duration: engine.duration,
        );
      } catch (_) {}

      onSongPlayed?.call(song);
    } catch (e, st) {
      _isLoading = false;
      print('[PlayerController] playSong error: $e\n$st');
      if (e is AuthRequiredException) {
        final relogined = await auth.autoRelogin();
        if (relogined) {
          // 重新登录成功，重试播放
          return playSong(song, quality: quality);
        }
        auth.logout();
        state = state.copyWith(error: '登录已失效，请重新登录', isPlaying: false);
        return;
      }
      state = state.copyWith(error: e.toString(), isPlaying: false);
    }
  }

  Future<void> toggle() async {
    final wasPlaying = state.isPlaying;
    // 先更新状态让 UI 立即响应
    state = state.copyWith(isPlaying: !wasPlaying);
    try {
      if (wasPlaying) {
        await engine.pause();
      } else {
        await engine.play();
      }
    } catch (e) {
      // 引擎操作失败，回滚状态
      state = state.copyWith(isPlaying: wasPlaying);
    }
  }

  Future<void> pause() async {
    if (state.isPlaying) {
      await engine.pause();
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> seekTo(Duration position) async {
    // 先更新状态，避免 _tick() 在 seek 完成前用旧 position 覆盖导致回跳
    final index = _resolveLyricIndex(state.lyrics, position);
    state = state.copyWith(position: position, currentLyricIndex: index);
    await engine.seek(position);
  }

  static final _random = Random();

  Future<void> skipNext({
    required List<Song> queue,
    required int currentIndex,
    required PlayMode playMode,
    required String quality,
  }) async {
    if (queue.isEmpty) return;
    int nextIndex;
    if (playMode == PlayMode.random) {
      if (queue.length <= 1) {
        nextIndex = 0;
      } else {
        do {
          nextIndex = _random.nextInt(queue.length);
        } while (nextIndex == currentIndex);
      }
    } else {
      nextIndex = (currentIndex + 1) % queue.length;
    }
    setCurrentQueueIndex?.call(nextIndex);
    await playSong(queue[nextIndex], quality: quality);
  }

  Future<void> skipPrevious({
    required List<Song> queue,
    required int currentIndex,
    required PlayMode playMode,
    required String quality,
  }) async {
    if (queue.isEmpty) return;
    int prevIndex;
    if (playMode == PlayMode.random) {
      if (queue.length <= 1) {
        prevIndex = 0;
      } else {
        do {
          prevIndex = _random.nextInt(queue.length);
        } while (prevIndex == currentIndex);
      }
    } else {
      prevIndex = (currentIndex - 1 + queue.length) % queue.length;
    }
    setCurrentQueueIndex?.call(prevIndex);
    await playSong(queue[prevIndex], quality: quality);
  }

  Future<void> setVolume(double volume) async {
    await engine.setVolume(volume);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }
}

final audioEngineProvider = Provider<AudioEngine>((ref) => JustAudioEngine(sharedPlayer));

final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerState>(
      (ref) {
        final controller = PlayerController(
          repository: ref.watch(solaraRepositoryProvider),
          engine: ref.watch(audioEngineProvider),
          themeController: ref.read(themeControllerProvider.notifier),
          auth: ref.read(authStateProvider.notifier),
          onSongPlayed: (song) {
            final historyNotifier = ref.read(historyStateProvider.notifier);
            historyNotifier.addEntry(song);
            ref
                .read(persistentStateProvider)
                .saveHistory(ref.read(historyStateProvider));
          },
          getQueue: () => ref.read(queueStateProvider).songs,
          getPlayMode: () => ref.read(queueStateProvider).playMode,
          getCurrentQueueIndex: () => ref.read(queueStateProvider).currentIndex,
          setCurrentQueueIndex: (index) => ref.read(queueStateProvider.notifier).setCurrentIndex(index),
          getQuality: () => ref.read(settingsStateProvider).playbackQuality,
        );

        // 注入锁屏/灵动岛/控制中心切歌回调
        audioHandler.onSkipNext = () async {
          final q = ref.read(queueStateProvider);
          final settings = ref.read(settingsStateProvider);
          await controller.skipNext(
            queue: q.songs,
            currentIndex: q.currentIndex,
            playMode: q.playMode,
            quality: settings.playbackQuality,
          );
        };
        audioHandler.onSkipPrevious = () async {
          final q = ref.read(queueStateProvider);
          final settings = ref.read(settingsStateProvider);
          await controller.skipPrevious(
            queue: q.songs,
            currentIndex: q.currentIndex,
            playMode: q.playMode,
            quality: settings.playbackQuality,
          );
        };

        // 内部音量始终为1.0，跟随系统音量
        return controller;
      },
    );

/// 覆盖 sleepTimerProvider，让到期时暂停播放器
final sleepTimerWithPlayerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>(
      (ref) => SleepTimerNotifier(
        onExpired: () {
          final controller = ref.read(playerControllerProvider.notifier);
          controller.pause();
        },
      ),
    );
