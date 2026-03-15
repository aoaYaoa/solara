import 'package:flutter/material.dart';

/// 播放指示器 - 显示动画均衡器条
class PlayingIndicator extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const PlayingIndicator({
    super.key,
    required this.isPlaying,
    required this.color,
    this.size = 18,
  });

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  static const _barCount = 4;
  // 每个条形有不同的持续时间以获得自然的外观
  static const _durations = [450, 550, 400, 500];
  static const _minHeight = 0.15;
  static const _maxHeights = [0.9, 0.7, 1.0, 0.65];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_barCount, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _durations[i]),
      );
    });
    _animations = List.generate(_barCount, (i) {
      return Tween<double>(begin: _minHeight, end: _maxHeights[i]).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
      );
    });
    if (widget.isPlaying) _startAnimations();
  }

  @override
  void didUpdateWidget(covariant PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _startAnimations();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _stopAnimations();
    }
  }

  void _startAnimations() {
    for (final c in _controllers) {
      c.repeat(reverse: true);
    }
  }

  void _stopAnimations() {
    for (final c in _controllers) {
      c.stop();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(_controllers),
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_barCount, (i) {
            final height = widget.isPlaying
                ? _animations[i].value
                : (_minHeight + 0.15 * (i % 2 == 0 ? 1 : 0.5));
            return Container(
              width: 3,
              height: widget.size * height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
