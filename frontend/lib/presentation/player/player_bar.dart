import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/state/settings_state.dart';
import '../../domain/state/queue_state.dart';
import '../../services/image_headers.dart' show proxyImageUrl;
import '../../services/player_controller.dart';
import '../now_playing/now_playing_screen.dart';

class PlayerBar extends ConsumerStatefulWidget {
  const PlayerBar({super.key});

  @override
  ConsumerState<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends ConsumerState<PlayerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _playPauseController;

  @override
  void initState() {
    super.initState();
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final settings = ref.watch(settingsStateProvider);
    final queueState = ref.watch(queueStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 同步播放/暂停动画
    if (state.isPlaying) {
      _playPauseController.forward();
    } else {
      _playPauseController.reverse();
    }

    final position = state.position;
    final duration = state.duration ?? Duration.zero;
    final progress =
        duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(
              0.0,
              1.0,
            )
            : 0.0;

    return GestureDetector(
      onTap:
          state.currentSong == null
              ? null
              : () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder:
                      (_, animation, __) => FadeTransition(
                        opacity: animation,
                        child: const NowPlayingScreen(),
                      ),
                  fullscreenDialog: true,
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.black.withOpacity(0.6)
                      : Colors.white.withOpacity(0.75),
              border: Border(
                top: BorderSide(
                  color:
                      isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度条（超细线）
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary.withOpacity(0.8),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                  child: Row(
                    children: [
                      // 封面
                      _ArtworkThumbnail(artworkUrl: state.artworkUrl),
                      const SizedBox(width: 10),
                      // 歌曲信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                state.currentSong?.name ?? '未在播放',
                                key: ValueKey(state.currentSong?.id),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (state.currentSong != null)
                              Text(
                                state.currentSong!.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(
                                    0.55,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // 上一曲
                      IconButton(
                        onPressed:
                            queueState.songs.isEmpty
                                ? null
                                : () => controller.skipPrevious(
                                  queue: queueState.songs,
                                  currentIndex: queueState.currentIndex,
                                  playMode: queueState.playMode,
                                  quality: settings.playbackQuality,
                                ),
                        icon: const Icon(Icons.skip_previous_rounded),
                        iconSize: 26,
                        visualDensity: VisualDensity.compact,
                      ),
                      // 播放/暂停
                      _PlayPauseButton(
                        isPlaying: state.isPlaying,
                        enabled: state.currentSong != null,
                        onPressed: controller.toggle,
                      ),
                      // 下一曲
                      IconButton(
                        onPressed:
                            queueState.songs.isEmpty
                                ? null
                                : () => controller.skipNext(
                                  queue: queueState.songs,
                                  currentIndex: queueState.currentIndex,
                                  playMode: queueState.playMode,
                                  quality: settings.playbackQuality,
                                ),
                        icon: const Icon(Icons.skip_next_rounded),
                        iconSize: 26,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkThumbnail extends StatelessWidget {
  final String? artworkUrl;
  const _ArtworkThumbnail({this.artworkUrl});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child:
          artworkUrl != null
              ? ClipRRect(
                key: ValueKey(artworkUrl),
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  proxyImageUrl(artworkUrl!),
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(colorScheme),
                ),
              )
              : _placeholder(colorScheme),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surfaceContainerHighest,
      ),
      child: Icon(Icons.music_note_rounded, size: 22, color: colorScheme.onSurfaceVariant),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool enabled;
  final VoidCallback onPressed;
  const _PlayPauseButton({
    required this.isPlaying,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled
          ? colorScheme.primary
          : colorScheme.onSurface.withOpacity(0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          width: 38,
          height: 38,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(isPlaying),
              color: enabled
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withOpacity(0.3),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
