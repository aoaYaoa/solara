import 'dart:async';

class DebugLogBus {
  DebugLogBus._();

  static final StreamController<String> _controller = StreamController<String>.broadcast();

  static Stream<String> get stream => _controller.stream;

  static void add(String message) {
    _controller.add(message);
  }
}
