import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../data/providers.dart';
import '../../services/app_config.dart';
import '../../services/player_controller.dart';

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
  VoidCallback? _ctrlListener;
  bool _loading = true;
  String? _error;
  bool _showControls = true;
  Timer? _hideTimer;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // 音乐播放器
  bool _wasPlaying = false;
  PlayerController? _playerCtrl;

  // 手势状态
  _GestureType? _activeGesture;
  double _gestureCurrent = 0; // 亮度或音量当前值
  double _seekStartSec = 0;
  double _seekDeltaSec = 0;
  bool _showGestureHint = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playerCtrl != null) return;
    _playerCtrl = ref.read(playerControllerProvider.notifier);
    _wasPlaying = ref.read(playerControllerProvider).isPlaying;
    if (_wasPlaying) _playerCtrl?.pause();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _fadeCtrl.dispose();
    if (_ctrlListener != null) {
      _ctrl?.removeListener(_ctrlListener!);
    }
    _ctrl?.pause();
    _ctrl?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ScreenBrightness().resetApplicationScreenBrightness();
    if (_wasPlaying && _playerCtrl != null) {
      _playerCtrl!.toggle();
    }
    super.dispose();
  }

  Future<void> _loadMv() async {
    try {
      final repo = ref.read(solaraRepositoryProvider);
      var url = await repo.fetchMvUrl(mvId: widget.mvId, source: widget.source);
      // B站和YouTube视频需要通过后端代理（需要特殊请求头）
      if (url.contains('googlevideo.com') || 
          url.contains('bilivideo') || 
          url.contains('bilibili.com') ||
          url.contains('akamaized.net') ||
          url.contains('mcdn.bilivideo')) {
        url = '${AppConfig.baseUrl}/proxy?url=${Uri.encodeComponent(url)}';
      }
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      _ctrlListener = () {
        if (mounted) setState(() {});
      };
      ctrl.addListener(_ctrlListener!);
      if (mounted) {
        setState(() {
          _ctrl = ctrl;
          _loading = false;
          _showControls = true;
        });
        _fadeCtrl.value = 1.0;
        ctrl.play();
        _scheduleHide();
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

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── 手势处理 ──────────────────────────────────────────
  void _onGestureStart(DragStartDetails d, Size size) {
    _hideTimer?.cancel();
    final x = d.localPosition.dx;
    final isLeft = x < size.width / 2;
    if (isLeft) {
      _activeGesture = _GestureType.brightness;
      ScreenBrightness().application.then((v) {
        _gestureCurrent = v;
      });
    } else {
      _activeGesture = _GestureType.volume;
      VolumeController().getVolume().then((v) {
        _gestureCurrent = v;
      });
    }
    setState(() => _showGestureHint = true);
  }

  void _onGestureUpdate(DragUpdateDetails d, Size size) {
    if (_activeGesture == null) return;
    final delta = -d.delta.dy / size.height;
    if (_activeGesture == _GestureType.brightness) {
      final newVal = (_gestureCurrent + delta).clamp(0.0, 1.0);
      _gestureCurrent = newVal;
      ScreenBrightness().setApplicationScreenBrightness(newVal);
    } else {
      final newVal = (_gestureCurrent + delta).clamp(0.0, 1.0);
      _gestureCurrent = newVal;
      VolumeController().setVolume(newVal);
    }
    setState(() {});
  }

  void _onGestureEnd(DragEndDetails d) {
    _activeGesture = null;
    setState(() => _showGestureHint = false);
    _scheduleHide();
  }

  void _onHorizontalStart(DragStartDetails d) {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    _hideTimer?.cancel();
    _activeGesture = _GestureType.seek;
    _seekStartSec = ctrl.value.position.inMilliseconds / 1000.0;
    _seekDeltaSec = 0;
    setState(() => _showGestureHint = true);
  }

  void _onHorizontalUpdate(DragUpdateDetails d, Size size) {
    if (_activeGesture != _GestureType.seek) return;
    // 整屏宽度对应 ±120 秒
    final delta = d.delta.dx / size.width * 120.0;
    _seekDeltaSec += delta;
    setState(() {});
  }

  void _onHorizontalEnd(DragEndDetails d) {
    final ctrl = _ctrl;
    if (ctrl != null && _activeGesture == _GestureType.seek) {
      final targetSec = (_seekStartSec + _seekDeltaSec)
          .clamp(0.0, ctrl.value.duration.inSeconds.toDouble());
      ctrl.seekTo(Duration(milliseconds: (targetSec * 1000).round()));
    }
    _activeGesture = null;
    setState(() => _showGestureHint = false);
    _scheduleHide();
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onVerticalDragStart: (d) => _onGestureStart(d, size),
        onVerticalDragUpdate: (d) => _onGestureUpdate(d, size),
        onVerticalDragEnd: _onGestureEnd,
        onHorizontalDragStart: _onHorizontalStart,
        onHorizontalDragUpdate: (d) => _onHorizontalUpdate(d, size),
        onHorizontalDragEnd: _onHorizontalEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 视频层 ────────────────────────────────────
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
                      const Text('MV 加载失败',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(_error!,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          setState(() { _loading = true; _error = null; });
                          _loadMv();
                        },
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

            // ── 手势提示浮层 ──────────────────────────────
            if (_showGestureHint && _activeGesture != null)
              _GestureHint(
                type: _activeGesture!,
                value: _activeGesture == _GestureType.seek
                    ? null
                    : _gestureCurrent,
                seekDelta: _seekDeltaSec,
                seekTarget: _activeGesture == _GestureType.seek
                    ? _seekStartSec + _seekDeltaSec
                    : null,
                fmt: _fmt,
              ),

            // ── 常驻返回按钮（控制栏隐藏时也可见）────────
            if (!_loading && _error == null && !_showControls)
              Positioned(
                top: 0, left: 0,
                child: SafeArea(
                  bottom: false,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),

            // ── 控制层（淡入淡出）─────────────────────────
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
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white, size: 20),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(widget.songName,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 15,
                                              fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(widget.artist,
                                          style: const TextStyle(
                                              color: Colors.white70, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 中间播放/暂停
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            if (ctrl != null) {
                              isPlaying ? ctrl.pause() : ctrl.play();
                            }
                            _scheduleHide();
                          },
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
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
                                            ctrl.seekTo(Duration(
                                                milliseconds:
                                                    (v * duration.inMilliseconds).round()));
                                            _scheduleHide();
                                          }
                                        : null,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                                  child: Row(
                                    children: [
                                      Text(_fmt(position),
                                          style: const TextStyle(
                                              color: Colors.white70, fontSize: 11)),
                                      const Spacer(),
                                      Text(_fmt(duration),
                                          style: const TextStyle(
                                              color: Colors.white70, fontSize: 11)),
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

enum _GestureType { brightness, volume, seek }

class _GestureHint extends StatelessWidget {
  final _GestureType type;
  final double? value;      // 0~1，亮度或音量
  final double seekDelta;
  final double? seekTarget; // 秒
  final String Function(Duration) fmt;

  const _GestureHint({
    required this.type,
    required this.value,
    required this.seekDelta,
    required this.seekTarget,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    if (type == _GestureType.brightness) {
      final pct = ((value ?? 0) * 100).round();
      icon = pct > 60
          ? Icons.brightness_high
          : pct > 30
              ? Icons.brightness_medium
              : Icons.brightness_low;
      label = '$pct%';
    } else if (type == _GestureType.volume) {
      final pct = ((value ?? 0) * 100).round();
      icon = pct == 0
          ? Icons.volume_off
          : pct < 50
              ? Icons.volume_down
              : Icons.volume_up;
      label = '$pct%';
    } else {
      final sec = seekDelta.round();
      icon = sec >= 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded;
      final t = seekTarget ?? 0;
      label = '${sec >= 0 ? '+' : ''}${sec}s  ${fmt(Duration(milliseconds: (t * 1000).round()))}';
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 6),
            if (type != _GestureType.seek)
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  value: value ?? 0,
                  backgroundColor: Colors.white30,
                  color: Colors.white,
                  minHeight: 3,
                ),
              ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
