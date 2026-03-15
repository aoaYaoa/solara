import 'dart:async';
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

class _MvPlayerScreenState extends ConsumerState<MvPlayerScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  bool _loading = true;
  String? _error;
  bool _showControls = true;
  Timer? _hideTimer;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _fadeAnim = _fadeCtrl;
    _loadMv();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _fadeCtrl.dispose();
    _ctrl?.dispose();
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
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() {
          _ctrl = ctrl;
          _loading = false;
        });
        ctrl.play();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
        _fadeCtrl.reverse();
      }
    });
  }

  void _toggleControls() {
    if (_showControls) {
      setState(() => _showControls = false);
      _fadeCtrl.reverse();
      _hideTimer?.cancel();
    } else {
      setState(() => _showControls = true);
      _fadeCtrl.forward();
      _scheduleHide();
    }
  }

  void _onTapControls() {
    _scheduleHide();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final isPlaying = ctrl?.value.isPlaying ?? false;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 视频层 ──────────────────────────────────────
            if (_loading)
              const Center(child: CircularProgressIndicator(color: Colors.white))
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                      const SizedBox(height: 12),
                      Text('MV 加载失败', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () { setState(() { _loading = true; _error = null; }); _loadMv(); },
                        child: const Text('重试', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              )
            else if (ctrl != null)
              Center(
                child: AspectRatio(
                  aspectRatio: ctrl.value.aspectRatio,
                  child: VideoPlayer(ctrl),
                ),
              ),

            // ── 控制层（淡入淡出）────────────────────────────
            if (!_loading && _error == null)
              FadeTransition(
                opacity: _fadeAnim,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 顶部渐变 + 标题
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(4, 0, 16, 24),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xCC000000), Colors.transparent],
                            ),
                          ),
                          child: SafeArea(
                            bottom: false,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.songName,
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        widget.artist,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 中间播放/暂停大按钮
                      Center(
                        child: GestureDetector(
                          onTap: _onTapControls,
                          child: AnimatedOpacity(
                            opacity: _showControls ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                                onPressed: () {
                                  if (ctrl != null) {
                                    isPlaying ? ctrl.pause() : ctrl.play();
                                    _scheduleHide();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 底部渐变 + 进度控制
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xCC000000), Colors.transparent],
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 进度条
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 2.5,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white30,
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white24,
                                  ),
                                  child: Slider(
                                    value: progress,
                                    onChanged: ctrl != null && duration.inMilliseconds > 0
                                        ? (v) {
                                            ctrl.seekTo(Duration(milliseconds: (v * duration.inMilliseconds).round()));
                                            _scheduleHide();
                                          }
                                        : null,
                                  ),
                                ),
                                // 时间行
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                                  child: Row(
                                    children: [
                                      Text(_fmt(position),
                                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                      const Spacer(),
                                      Text(_fmt(duration),
                                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    ],
                                  ),
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
