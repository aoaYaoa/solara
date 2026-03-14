import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/domain/models/song.dart';
import 'package:solara_flutter/services/player_controller.dart';
import 'package:solara_flutter/services/persistent_state_service.dart';
import 'package:solara_flutter/services/storage_service.dart';
import 'package:solara_flutter/platform/audio_engine.dart';
import 'package:solara_flutter/data/solara_repository.dart';
import 'package:solara_flutter/data/api/solara_api.dart';
import 'package:solara_flutter/data/api/api_client.dart';
import 'package:solara_flutter/services/theme_controller.dart';
import 'package:solara_flutter/services/auth_service.dart';
import 'package:dio/dio.dart';

class FakeRepo extends SolaraRepository {
  FakeRepo() : super(api: SolaraApi(client: ApiClient(baseUrl: 'https://example.com')), dio: Dio());

  @override
  Future<String> fetchSongUrl({required String songId, required String source, required String quality}) async {
    return 'https://example.com/$songId.mp3';
  }

  @override
  Future<String> fetchLyric({required String songId, required String source}) async {
    return '[00:00.00]Hello';
  }

  @override
  Future<String> fetchPicUrl({required String picId, required String source, int size = 300}) async {
    return 'https://example.com/pic.jpg';
  }
}

class FakeEngine implements AudioEngine {
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _volume = 1.0;
  double _speed = 1.0;
  final _completeController = StreamController<void>.broadcast();

  @override
  bool get isPlaying => _playing;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  Stream<void> get onComplete => _completeController.stream;

  @override
  double get volume => _volume;

  @override
  double get speed => _speed;

  @override
  Future<void> pause() async { _playing = false; }

  @override
  Future<void> play() async { _playing = true; }

  @override
  Future<void> seek(Duration position) async { _position = position; }

  @override
  Future<void> setSource(String url) async {
    _position = Duration.zero;
    _duration = null;
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _position = Duration.zero;
  }

  @override
  Future<void> setVolume(double volume) async { _volume = volume; }

  @override
  Future<void> setSpeed(double speed) async { _speed = speed; }
}

class FakeThemeController extends ThemeController {
  @override
  Future<void> updateFromArtwork(String? url) async {}
}

class FakeAuth extends AuthStateNotifier {
  FakeAuth() : super(client: ApiClient(baseUrl: 'https://example.com', dio: Dio()));
}

void main() {
  test('PlayerController playSong updates state', () async {
    final controller = PlayerController(
      repository: FakeRepo(),
      engine: FakeEngine(),
      themeController: FakeThemeController(),
      auth: FakeAuth(),
      persistence: PersistentStateService(storage: StorageService()),
    );
    final song = Song(
      id: '1',
      name: 'Song 1',
      artist: 'Artist',
      album: 'Album',
      picId: 'pic',
      urlId: 'url',
      lyricId: 'lyric',
      source: 'netease',
    );

    await controller.playSong(song, quality: '320');

    expect(controller.state.currentSong?.id, '1');
    expect(controller.state.isPlaying, true);
    expect(controller.state.lyrics.isNotEmpty, true);
  });
}
