import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SleepTimerState {
  final Duration? remaining;
  final bool active;

  const SleepTimerState({this.remaining, this.active = false});

  SleepTimerState copyWith({
    Duration? remaining,
    bool? active,
    bool clearRemaining = false,
  }) {
    return SleepTimerState(
      remaining: clearRemaining ? null : (remaining ?? this.remaining),
      active: active ?? this.active,
    );
  }
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  Timer? _timer;
  void Function() onExpired;

  SleepTimerNotifier({required this.onExpired})
    : super(const SleepTimerState());

  void start(Duration duration) {
    _timer?.cancel();
    state = SleepTimerState(remaining: duration, active: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.remaining;
      if (remaining == null || remaining.inSeconds <= 1) {
        cancel();
        onExpired();
      } else {
        state = state.copyWith(
          remaining: remaining - const Duration(seconds: 1),
        );
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    state = const SleepTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>(
      (ref) => SleepTimerNotifier(
        onExpired: () {}, // 在 NowPlayingScreen 中通过 ref 覆盖实际行为
      ),
    );
