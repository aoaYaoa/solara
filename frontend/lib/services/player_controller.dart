import 'dart:async';
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
    const quality = '320';
    if (queue.isEmpty) {
      // 队列为空：单曲循环
      if (state.currentSong != null) {
        playSong(state.currentSong!, quality: quality);
      }
      return;
    }
    if (playMode == PlayMode.single) {
      // 单曲循环：重播当前歌曲
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
    // 立即更新歌曲信息，让 UI 马上响应
    state = state.copyWith(
      error: null,
      currentSong: song,
      position: Duration.zero,
      lyrics: const [],
      currentLyricIndex: -1,
    );

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

      state = state.copyWith(isPlaying: true);

      // 后台加载歌词和封面
      try {
        final lyricRaw = await repository.fetchLyric(
          songId: song.lyricId.isNotEmpty ? song.lyricId : song.id,
          source: song.source,
        );
        final lyrics = LyricParser.parse(lyricRaw);
        state = state.copyWith(lyrics: lyrics);
      } catch (e) {
        print('[PlayerController] fetchLyric error: $e');
      }

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
      } catch (e) {
        print('[PlayerController] fetchArtwork error: $e');
      }

      onSongPlayed?.call(song);
    } catch (e, st) {
      print('[PlayerController] playSong error: $e\n$st');
      if (e is AuthRequiredException) {
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
    await engine.seek(position);
    final index = _resolveLyricIndex(state.lyrics, position);
    state = state.copyWith(position: position, currentLyricIndex: index);
  }

  Future<void> skipNext({
    required List<Song> queue,
    required int currentIndex,
    required PlayMode playMode,
    required String quality,
  }) async {
    if (queue.isEmpty) return;
    int nextIndex;
    if (playMode == PlayMode.random) {
      nextIndex =
          (currentIndex + 1 + (queue.length * 0.5).round()) % queue.length;
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
      prevIndex = (currentIndex - 1 + queue.length) % queue.length;
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
        );

        // Handle lock screen skip controls
        audioHandler.customEvent.listen((event) {});
        audioHandler.playbackState.listen((state) {});

        // 应用持久化的音量
        final volume = ref.read(settingsStateProvider).volume;
        controller.setVolume(volume);
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
