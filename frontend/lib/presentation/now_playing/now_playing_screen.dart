import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/queue_state.dart';
import '../../domain/state/settings_state.dart';
import '../../services/image_headers.dart' show proxyImageUrl;
import '../../domain/state/favorites_state.dart';
import '../../domain/models/lyric_line.dart';
import '../../services/player_controller.dart';
import '../queue/queue_panel.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  final ScrollController _lyricsScrollController = ScrollController();
  late PageController _pageController;
  int _currentPage = 0;
  int _lastLyricIndex = -1;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _lyricsScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _syncPlayState(bool isPlaying) {
    if (isPlaying) {
      _rotationController.repeat();
      _scaleController.forward();
    } else {
      _rotationController.stop();
      _scaleController.reverse();
    }
  }

  void _scrollToLyric(int index, int total) {
    if (!_lyricsScrollController.hasClients || index < 0) return;
    const itemHeight = 44.0;
    final viewportHeight = _lyricsScrollController.position.viewportDimension;
    final targetOffset =
        (index * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
    _lyricsScrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _lyricsScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showQualityPicker(
    BuildContext context,
    String current,
    SettingsStateNotifier settingsNotifier,
  ) {
    final items = ['128', '192', '320', 'FLAC'];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '音质选择',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...items.map(
              (q) => ListTile(
                title: Text(_qualityLabel(q)),
                trailing: current == q
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  settingsNotifier.setPlaybackQuality(q);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _qualityLabel(String q) {
    switch (q) {
      case '128':
        return '标准 128K';
      case '192':
        return '较高 192K';
      case '320':
        return '极高 320K';
      case 'FLAC':
        return '无损 FLAC';
      default:
        return q;
    }
  }

  void _showVolumeSlider(
    BuildContext context,
    SettingsState settings,
    SettingsStateNotifier settingsNotifier,
  ) {
    final player = ref.read(playerControllerProvider.notifier);
    var vol = settings.volume;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '音量',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.volume_down,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      Expanded(
                        child: Slider(
                          value: vol,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(vol * 100).round()}%',
                          onChanged: (v) {
                            setModalState(() => vol = v);
                            settingsNotifier.setVolume(v);
                            player.setVolume(v);
                          },
                        ),
                      ),
                      Icon(Icons.volume_up,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '播放队列',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const Expanded(child: QueuePanel()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final queueState = ref.watch(queueStateProvider);
    final queueNotifier = ref.read(queueStateProvider.notifier);
    final settings = ref.watch(settingsStateProvider);
    final favoritesState = ref.watch(favoritesStateProvider);
    final favorites = ref.read(favoritesStateProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final song = playerState.currentSong;
    final position = playerState.position;
    final duration = playerState.duration ?? Duration.zero;
    final lyrics = playerState.lyrics;
    final lyricIndex = playerState.currentLyricIndex;
    final isPlaying = playerState.isPlaying;
    final playMode = queueState.playMode;
    final isFav =
        song != null && favoritesState.favorites.any((s) => s.id == song.id);

    _syncPlayState(isPlaying);

    // 歌词自动滚动 — 仅在歌词页时触发
    if (_currentPage == 1 && lyricIndex != _lastLyricIndex && lyricIndex >= 0) {
      _lastLyricIndex = lyricIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLyric(lyricIndex, lyrics.length);
      });
    }

    final primaryColor = colorScheme.primary;
    final bgColor = Color.alphaBlend(
      primaryColor.withValues(alpha: 0.85),
      Colors.black,
    );
    final bgColorDark = Color.alphaBlend(
      primaryColor.withValues(alpha: 0.95),
      Colors.black,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgColor, bgColorDark, Colors.black],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(song, context),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        children: [
                          _buildVinylDiscPage(
                            playerState,
                            primaryColor,
                          ),
                          _buildLyricsPage(lyrics, lyricIndex, controller),
                        ],
                      ),
                    ),
                    _buildPageIndicator(),
                  ],
                ),
              ),
              _buildActionRow(isFav, song, favorites, primaryColor, settings, ref.read(settingsStateProvider.notifier)),
              _buildProgressBar(position, duration, controller),
              _buildMainControls(
                isPlaying: isPlaying,
                controller: controller,
                queueState: queueState,
                queueNotifier: queueNotifier,
                playMode: playMode,
                settings: settings,
                primaryColor: primaryColor,
                bgColorDark: bgColorDark,
                context: context,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 顶栏 ───────────────────────────────────────────
  Widget _buildTopBar(dynamic song, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  song?.name ?? '未在播放',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (song != null)
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ── 唱片页 ──────────────────────────────────────────
  Widget _buildVinylDiscPage(
    dynamic playerState,
    Color primaryColor,
  ) {
    final discSize = math.min(280.0, MediaQuery.of(context).size.width * 0.65);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: child,
                );
              },
              child: Container(
                width: discSize,
                height: discSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: playerState.artworkUrl != null
                      ? Image.network(
                          proxyImageUrl(playerState.artworkUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _defaultCover(primaryColor),
                        )
                      : _defaultCover(primaryColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── 歌词页 ──────────────────────────────────────────
  Widget _buildLyricsPage(
    List<dynamic> lyrics,
    int lyricIndex,
    dynamic controller,
  ) {
    if (lyrics.isEmpty) {
      return Center(
        child: Text(
          '暂无歌词',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
      );
    }
    return ListView.builder(
      controller: _lyricsScrollController,
      itemCount: lyrics.length,
      itemExtent: 44,
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height * 0.1,
      ),
      itemBuilder: (context, index) {
        final line = lyrics[index] as LyricLine;
        final isCurrent = index == lyricIndex;
        final isNear = (index - lyricIndex).abs() <= 1;
        return GestureDetector(
          onTap: () => controller.seekTo(line.time),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isCurrent
                    ? Colors.white
                    : isNear
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.25),
                fontSize: isCurrent ? 17 : 14,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(
                line.text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 页面指示器 ──────────────────────────────────────
  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(2, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: _currentPage == index
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
            ),
          );
        }),
      ),
    );
  }

  // ── 辅助操作栏（收藏 + 音质 + 音量） ──────────────
  Widget _buildActionRow(
    bool isFav,
    dynamic song,
    dynamic favorites,
    Color primaryColor,
    SettingsState settings,
    SettingsStateNotifier settingsNotifier,
  ) {
    final quality = settings.playbackQuality;
    final volume = settings.volume;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(isFav),
                color: isFav
                    ? Colors.redAccent
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            onPressed:
                song != null ? () => favorites.toggleFavorite(song) : null,
          ),
          GestureDetector(
            onTap: () => _showQualityPicker(context, quality, settingsNotifier),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.7),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                quality == 'flac' ? 'FLAC' : '${quality}K',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              volume <= 0
                  ? Icons.volume_off
                  : volume < 0.5
                      ? Icons.volume_down
                      : Icons.volume_up,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            onPressed: () => _showVolumeSlider(context, settings, settingsNotifier),
          ),
        ],
      ),
    );
  }

  // ── 进度条 ──────────────────────────────────────────
  Widget _buildProgressBar(
    Duration position,
    Duration duration,
    dynamic controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _isDragging
                  ? _dragValue
                  : (duration.inMilliseconds > 0
                      ? (position.inMilliseconds / duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0),
              onChangeStart: (v) {
                setState(() {
                  _isDragging = true;
                  _dragValue = v;
                });
              },
              onChanged: duration.inMilliseconds > 0
                  ? (v) {
                      setState(() => _dragValue = v);
                    }
                  : null,
              onChangeEnd: duration.inMilliseconds > 0
                  ? (v) {
                      controller.seekTo(
                        Duration(
                          milliseconds:
                              (v * duration.inMilliseconds).round(),
                        ),
                      );
                      setState(() => _isDragging = false);
                    }
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 主控制栏（5 按钮） ─────────────────────────────
  Widget _buildMainControls({
    required bool isPlaying,
    required dynamic controller,
    required dynamic queueState,
    required dynamic queueNotifier,
    required PlayMode playMode,
    required dynamic settings,
    required Color primaryColor,
    required Color bgColorDark,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 播放模式
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _playModeIcon(playMode),
                key: ValueKey(playMode),
                color: playMode != PlayMode.list
                    ? primaryColor
                    : Colors.white.withValues(alpha: 0.7),
                size: 22,
              ),
            ),
            onPressed: () => queueNotifier.cyclePlayMode(),
          ),
          // 上一曲
          IconButton(
            icon: Icon(
              Icons.skip_previous,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            iconSize: 36,
            onPressed: queueState.songs.isEmpty
                ? null
                : () => controller.skipPrevious(
                      queue: queueState.songs,
                      currentIndex: queueState.currentIndex,
                      playMode: playMode,
                      quality: settings.playbackQuality,
                    ),
          ),
          // 播放/暂停
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: primaryColor.withValues(alpha: 0.4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => controller.toggle(),
              child: SizedBox(
                width: 64,
                height: 64,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    key: ValueKey(isPlaying),
                    color: bgColorDark,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          // 下一曲
          IconButton(
            icon: Icon(
              Icons.skip_next,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            iconSize: 36,
            onPressed: queueState.songs.isEmpty
                ? null
                : () => controller.skipNext(
                      queue: queueState.songs,
                      currentIndex: queueState.currentIndex,
                      playMode: playMode,
                      quality: settings.playbackQuality,
                    ),
          ),
          // 队列
          IconButton(
            icon: Icon(
              Icons.queue_music,
              color: Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
            onPressed: () => _showQueueBottomSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover(Color primaryColor) {
    return Container(
      color: primaryColor.withValues(alpha: 0.3),
      child: const Icon(Icons.music_note, color: Colors.white54, size: 80),
    );
  }

  IconData _playModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.list:
        return Icons.repeat;
      case PlayMode.single:
        return Icons.repeat_one;
      case PlayMode.random:
        return Icons.shuffle;
    }
  }
}
