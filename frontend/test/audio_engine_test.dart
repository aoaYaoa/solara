import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/platform/audio_engine.dart';

void main() {
  test('AudioEngine interface exposes required methods', () {
    final engine = FakeAudioEngine();
    expect(engine.isPlaying, false);
    engine.play();
    expect(engine.isPlaying, true);
    engine.pause();
    expect(engine.isPlaying, false);
    engine.seek(Duration(seconds: 10));
    expect(engine.position, const Duration(seconds: 10));
  });
}
