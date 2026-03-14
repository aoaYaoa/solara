import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'audio_engine.dart';

class JustAudioEngine implements AudioEngine {
  final AudioPlayer _player;

  JustAudioEngine(this._player);

  @override
  Stream<void> get onComplete => _player.playerStateStream
      .map((s) => s.processingState == ProcessingState.completed)
      .distinct()
      .where((isCompleted) => isCompleted)
      .map((_) {});

  @override
  bool get isPlaying => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  double get volume => _player.volume;

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  @override
  Future<void> setSource(String url) async {
    await _player.setUrl(url);
  }
}
