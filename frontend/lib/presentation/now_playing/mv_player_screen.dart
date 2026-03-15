import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../data/providers.dart';

class MvPlayerScreen extends ConsumerStatefulWidget {
  final String mvId;
  final String source;
  final String songName;
  final String artist;

  const MvPlayerScreen({
    super.key,
    required this.mvId,
    required this.source,
    required this.songName,
    required this.artist,
  });

  @override
  ConsumerState<MvPlayerScreen> createState() => _MvPlayerScreenState();
}

class _MvPlayerScreenState extends ConsumerState<MvPlayerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // Force landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadMv();
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Restore orientation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadMv() async {
    try {
      final repo = ref.read(solaraRepositoryProvider);
      final url = await repo.fetchMvUrl(mvId: widget.mvId, source: widget.source);
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      ctrl.addListener(() => setState(() {}));
      if (mounted) {
        setState(() {
          _controller = ctrl;
          _loading = false;
        });
        ctrl.play();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final isPlaying = ctrl?.value.isPlaying ?? false;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ?? Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // ── Video ──
            Center(
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'MV 加载失败\n$_error',
                            style: const TextStyle(color: Colors.white60),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : AspectRatio(
                          aspectRatio: ctrl!.value.aspectRatio,
                          child: VideoPlayer(ctrl),
                        ),
            ),

            // ── Controls overlay ──
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  children: [
                    // top bar
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: SafeArea(
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.songName,
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(widget.artist,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // bottom controls
                    if (ctrl != null)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                          child: SafeArea(
                            child: Column(
                              children: [
                                // progress
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white30,
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white24,
                                  ),
                                  child: Slider(
                                    value: duration.inMilliseconds > 0
                                        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                                        : 0.0,
                                    onChanged: duration.inMilliseconds > 0
                                        ? (v) => ctrl.seekTo(Duration(milliseconds: (v * duration.inMilliseconds).round()))
                                        : null,
                                  ),
                                ),
                                // time + play button
                                Row(
                                  children: [
                                    Text(_formatDuration(position),
                                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                                          color: Colors.white, size: 28),
                                      onPressed: () {
                                        isPlaying ? ctrl.pause() : ctrl.play();
                                      },
                                    ),
                                    const Spacer(),
                                    Text(_formatDuration(duration),
                                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
