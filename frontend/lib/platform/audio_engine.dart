import 'dart:async';

abstract class AudioEngine {
  bool get isPlaying;
  Duration get position;
  Duration? get duration;
  Stream<void> get onComplete;

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSource(String url);
  Future<void> setVolume(double volume);
  double get volume;

  double get speed;
  Future<void> setSpeed(double speed);
}

class FakeAudioEngine implements AudioEngine {
  final _completeController = StreamController<void>.broadcast();

  @override
  Stream<void> get onComplete => _completeController.stream;

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _volume = 1.0;
  double _speed = 1.0;

  @override
  bool get isPlaying => _playing;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  Future<void> play() async {
    _playing = true;
  }

  @override
  Future<void> pause() async {
    _playing = false;
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _position = Duration.zero;
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
  }

  @override
  double get volume => _volume;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> setSource(String url) async {
    _position = Duration.zero;
    _duration = null;
  }

  @override
  double get speed => _speed;

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
  }
}
