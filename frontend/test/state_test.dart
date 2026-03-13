import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solara_flutter/domain/models/song.dart';
import 'package:solara_flutter/domain/state/favorites_state.dart';
import 'package:solara_flutter/domain/state/queue_state.dart';
import 'package:solara_flutter/domain/state/settings_state.dart';
import 'package:solara_flutter/services/persistent_state_service.dart';
import 'package:solara_flutter/services/storage_service.dart';

Song makeSong(String id) {
  return Song(
    id: id,
    name: 'Song $id',
    artist: 'Artist',
    album: 'Album',
    picId: 'pic',
    urlId: 'url',
    lyricId: 'lyric',
    source: 'netease',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final persistence = PersistentStateService(storage: StorageService());

  test('QueueState add/remove/clear', () {
    final notifier = QueueStateNotifier(persistence: persistence);
    expect(notifier.state.songs.length, 0);

    notifier.addSong(makeSong('1'));
    notifier.addSong(makeSong('2'));
    expect(notifier.state.songs.length, 2);

    notifier.removeAt(0);
    expect(notifier.state.songs.length, 1);
    expect(notifier.state.songs.first.id, '2');

    notifier.clear();
    expect(notifier.state.songs.length, 0);
  });

  test('Favorites toggle', () {
    final notifier = FavoritesStateNotifier(persistence: persistence);
    final song = makeSong('a');
    expect(notifier.isFavorite(song), false);

    notifier.toggleFavorite(song);
    expect(notifier.isFavorite(song), true);

    notifier.toggleFavorite(song);
    expect(notifier.isFavorite(song), false);
  });

  test('Settings updates', () {
    final notifier = SettingsStateNotifier(persistence: persistence);
    expect(notifier.state.playbackQuality, '320');

    notifier.setPlaybackQuality('128');
    expect(notifier.state.playbackQuality, '128');

    notifier.setVolume(0.5);
    expect(notifier.state.volume, 0.5);
  });
}
