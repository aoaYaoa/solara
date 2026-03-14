import 'dart:async';
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
import '../services/persistent_state_service.dart';
import '../main.dart' show audioHandler, sharedPlayer;

class PlayerController extends StateNotifier<PlayerState> {
  final SolaraRepository repository;
  final AudioEngine engine;
  final ThemeController themeController;
  final AuthStateNotifier auth;
  final PersistentStateService persistence;
  final void Function(Song)? onSongPlayed;
  Timer? _timer;
  StreamSubscription<void>? _completeSub;
  List<Song> Function()? getQueue;
  PlayMode Function()? getPlayMode;
  int Function()? getCurrentQueueIndex;
  void Function(int)? setCurrentQueueIndex;
  String Function()? getQuality;
  bool _isLoading = false;
  bool _isSwitching = false;
  Duration? _restoredPosition;
  int _tickCount = 0;

  PlayerController({
    required this.repository,
    required this.engine,
    required this.themeController,
    required this.auth,
    required this.persistence,
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
    // 防止 seek(Duration.zero) 触发二次 complete 事件导致重复切歌
    if (_isSwitching) return;
    _isSwitching = true;
    // 立即 seek 回起点，让 just_audio 脱离 completed 状态
    // 避免 iOS 系统因 completed 状态关闭 Now Playing 会话（灵动岛/锁屏）
    engine.seek(Duration.zero).ignore();
    audioHandler.beginSwitching();
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
    // 引擎未加载（duration为null且未播放）时不更新，保留启动恢复的 position/duration
    if (engine.duration == null && !engine.isPlaying) return;
    final position = engine.position;
    final duration = engine.duration ?? state.duration;
    if (position != state.position || duration != state.duration) {
      final currentIndex = _resolveLyricIndex(state.lyrics, position);
      state = state.copyWith(
        position: position,
        duration: duration,
        currentLyricIndex: currentIndex,
      );
    }
    // 每10次tick（约5秒）自动保存播放进度，应对划掉app没暂停的情况
    _tickCount++;
    if (_tickCount >= 10 && state.isPlaying && state.currentSong != null) {
      _tickCount = 0;
      persistence.savePlaybackPosition(
        position: state.position,
        duration: state.duration,
      ).ignore();
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

  Future<void> playSong(Song song, {required String quality, Duration? seekTo}) async {
    _isLoading = true;
    // 保留旧封面，切歌过渡期间用于锁屏/灵动岛显示
    final previousArtworkUrl = state.artworkUrl;

    // 是否是同一首歌（恢复播放）：保留 position/duration；切换新歌才清零
    final isSameSong = state.currentSong?.id == song.id && state.currentSong?.source == song.source;
    // 完整重置状态：直接构造新 PlayerState，避免 copyWith 的 nullable 遗留问题
    state = PlayerState(
      currentSong: song,
      isPlaying: state.isPlaying,
      position: isSameSong ? state.position : Duration.zero,
      duration: isSameSong ? state.duration : null,
      lyrics: const [],
      currentLyricIndex: -1,
      artworkUrl: previousArtworkUrl, // 保留旧封面直到新封面加载完
      error: null,
    );

    // 自动同步队列索引
    final queue = getQueue?.call() ?? [];
    final songIndex = queue.indexWhere((s) => s.id == song.id);
    if (songIndex >= 0) {
      setCurrentQueueIndex?.call(songIndex);
    }

    // 立即计算封面 URL（无需网络请求）
    String? immediateArtworkUrl;
    if (song.picUrl != null && song.picUrl!.isNotEmpty) {
      final encoded = Uri.encodeComponent(song.picUrl!);
      immediateArtworkUrl = '${AppConfig.baseUrl}/imgproxy?url=$encoded';
    } else if (song.picId.isNotEmpty) {
      // 直接构建代理 URL，与 fetchPicUrl 返回结果一致，避免网络请求延迟
      final proxyUri = repository.buildPicProxyUrl(picId: song.picId, source: song.source);
      immediateArtworkUrl = proxyUri;
    }
    immediateArtworkUrl ??= previousArtworkUrl;

    // 更新锁屏/通知栏信息
    audioHandler.setNowPlaying(
      title: song.name,
      artist: song.artist,
      artworkUrl: immediateArtworkUrl,
    );

    try {
      final String url;
      if (song.source == 'local') {
        // 本地文件直接用 file:// URI
        url = song.urlId.startsWith('file://') ? song.urlId : 'file://${song.urlId}';
      } else {
        url = await repository.fetchSongUrl(
          songId: song.id,
          source: song.source,
          quality: quality,
        );
      }
      await engine.setSource(url);
      engine.play().catchError((e) {
        print('[PlayerController] play() error (ignored): $e');
      });

      // 如果有指定起始位置，在解除 loading 锁之前 seek，避免 _tick() 用0覆盖
      if (seekTo != null && seekTo > Duration.zero) {
        await engine.seek(seekTo);
      }
      // 引擎就绪，解除 loading 锁，让 _tick() 开始同步
      _isLoading = false;
      _isSwitching = false;
      audioHandler.endSwitching();
      state = state.copyWith(isPlaying: true, position: seekTo ?? state.position);

      // 立即更新锁屏/灵动岛，使用已知封面和 duration
      audioHandler.setNowPlaying(
        title: song.name,
        artist: song.artist,
        artworkUrl: immediateArtworkUrl,
        duration: engine.duration,
      );
      // 后台等待 duration 可用后再次更新（just_audio 异步加载）
      _updateDurationWhenReady(song, immediateArtworkUrl);

      // 后台加载歌词
      try {
        final lyricRaw = await repository.fetchLyric(
          songId: song.lyricId.isNotEmpty ? song.lyricId : song.id,
          source: song.source,
        );
        final lyrics = LyricParser.parse(lyricRaw);
        state = state.copyWith(lyrics: lyrics);
      } catch (_) {}

      // 后台获取真实封面图 URL（fetchPicUrl 返回实际图片地址，而非代理JSON接口）
      try {
        String? realArtworkUrl;
        if (song.picUrl != null && song.picUrl!.isNotEmpty) {
          final encoded = Uri.encodeComponent(song.picUrl!);
          realArtworkUrl = '${AppConfig.baseUrl}/imgproxy?url=$encoded';
        } else if (song.picId.isNotEmpty) {
          final fetched = await repository.fetchPicUrl(picId: song.picId, source: song.source);
          if (fetched.isNotEmpty) {
            if (fetched.startsWith('http') && (fetched.contains('.126.net') || fetched.contains('.163.com') || fetched.contains('.qq.com'))) {
              realArtworkUrl = '${AppConfig.baseUrl}/imgproxy?url=${Uri.encodeComponent(fetched)}';
            } else {
              realArtworkUrl = fetched;
            }
          }
        }
        final artworkUrl = realArtworkUrl ?? immediateArtworkUrl ?? '';
        if (artworkUrl.isNotEmpty) {
          await themeController.updateFromArtwork(artworkUrl);
          state = state.copyWith(artworkUrl: artworkUrl);
          audioHandler.setNowPlaying(
            title: song.name,
            artist: song.artist,
            artworkUrl: artworkUrl,
            duration: engine.duration,
          );
        }
      } catch (_) {}

      onSongPlayed?.call(song);
    } catch (e, st) {
      _isLoading = false;
      _isSwitching = false;
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

  void _updateDurationWhenReady(Song song, String? artworkUrl) {
    // 轮询等待 duration 可用，最多等 5 秒
    var attempts = 0;
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final dur = engine.duration;
      attempts++;
      if (dur != null || attempts >= 25) {
        timer.cancel();
        if (dur != null) {
          audioHandler.setNowPlaying(
            title: song.name,
            artist: song.artist,
            artworkUrl: state.artworkUrl ?? artworkUrl,
            duration: dur,
          );
          state = state.copyWith(duration: dur);
        }
      }
    });
  }

  /// 启动时恢复上次播放的歌曲状态（仅显示，不自动播放）
  Future<void> restoreLastSong(Song song) async {
    String? artworkUrl;
    if (song.picUrl != null && song.picUrl!.isNotEmpty) {
      final encoded = Uri.encodeComponent(song.picUrl!);
      artworkUrl = '${AppConfig.baseUrl}/imgproxy?url=$encoded';
    } else if (song.picId.isNotEmpty) {
      artworkUrl = repository.buildPicProxyUrl(picId: song.picId, source: song.source);
    }
    // 读取上次保存的播放进度
    final saved = await persistence.loadPlaybackPosition();
    _restoredPosition = saved.position > Duration.zero ? saved.position : null;
    state = PlayerState(
      currentSong: song,
      isPlaying: false,
      position: saved.position,
      duration: saved.duration,
      lyrics: const [],
      currentLyricIndex: -1,
      artworkUrl: artworkUrl,
      error: null,
    );
    audioHandler.setNowPlaying(
      title: song.name,
      artist: song.artist,
      artworkUrl: artworkUrl,
    );
  }

  Future<void> toggle() async {
    final wasPlaying = state.isPlaying;
    // 引擎未加载（恢复状态后第一次播放）：加载并跳到保存的进度
    if (!wasPlaying && state.currentSong != null && engine.duration == null) {
      final quality = getQuality?.call() ?? '320';
      final seekTo = _restoredPosition;
      _restoredPosition = null;
      await playSong(state.currentSong!, quality: quality, seekTo: seekTo);
      return;
    }
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
      // 保存当前进度和总时长，供下次启动恢复
      persistence.savePlaybackPosition(position: state.position, duration: state.duration).ignore();
    }
  }

  Future<void> seekTo(Duration position) async {
    // 先更新状态，避免 _tick() 在 seek 完成前用旧 position 覆盖导致回跳
    final index = _resolveLyricIndex(state.lyrics, position);
    state = state.copyWith(position: position, currentLyricIndex: index);
    await engine.seek(position);
  }

  /// 淡出后暂停（用于睡眠定时器到期）
  Future<void> fadeOutAndPause({Duration fadeDuration = const Duration(seconds: 5)}) async {
    if (!state.isPlaying) return;
    final steps = 20;
    final stepDuration = Duration(milliseconds: fadeDuration.inMilliseconds ~/ steps);
    for (int i = steps - 1; i >= 0; i--) {
      if (!state.isPlaying) break;
      await engine.setVolume(i / steps);
      await Future.delayed(stepDuration);
    }
    await pause();
    await engine.setVolume(1.0); // 恢复音量
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

  Future<void> setSpeed(double speed) async {
    await engine.setSpeed(speed);
    state = state.copyWith(speed: speed);
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
          persistence: ref.read(persistentStateProvider),
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

/// 覆盖 sleepTimerProvider，让到期时淡出后暂停播放器
final sleepTimerWithPlayerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>(
      (ref) => SleepTimerNotifier(
        onExpired: () {
          final controller = ref.read(playerControllerProvider.notifier);
          controller.fadeOutAndPause();
        },
      ),
    );
