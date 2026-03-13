import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/services/remote_state_models.dart';

void main() {
  test('RemoteStateSnapshot parses json', () {
    final json = {
      'version': 1,
      'updatedAt': '2026-03-12T10:00:00Z',
      'queue': {
        'updatedAt': '2026-03-12T10:01:00Z',
        'songs': [
          {'id': '1', 'name': 'A'}
        ],
      },
      'favorites': {
        'updatedAt': '2026-03-12T10:02:00Z',
        'songs': [
          {'id': '2', 'name': 'B'}
        ],
      },
      'settings': {
        'updatedAt': '2026-03-12T10:03:00Z',
        'data': {'playbackQuality': '320'},
      },
    };

    final snapshot = RemoteStateSnapshot.fromJson(json);

    expect(snapshot.version, 1);
    expect(snapshot.updatedAt.toIso8601String(), '2026-03-12T10:00:00.000Z');
    expect(snapshot.queue?.songs.length, 1);
    expect(snapshot.queue?.songs.first['id'], '1');
    expect(snapshot.favorites?.songs.first['id'], '2');
    expect(snapshot.settings?.data['playbackQuality'], '320');
  });

  test('RemoteStateSnapshot merges by updatedAt', () {
    final local = RemoteStateSnapshot(
      version: 1,
      updatedAt: DateTime.parse('2026-03-12T10:00:00Z'),
      queue: RemoteQueueState(
        updatedAt: DateTime.parse('2026-03-12T10:01:00Z'),
        songs: [
          {'id': 'local', 'name': 'Local'},
        ],
      ),
      favorites: RemoteFavoritesState(
        updatedAt: DateTime.parse('2026-03-12T10:02:00Z'),
        songs: [
          {'id': 'fav-local', 'name': 'FavLocal'},
        ],
      ),
      settings: RemoteSettingsState(
        updatedAt: DateTime.parse('2026-03-12T10:03:00Z'),
        data: {'playbackQuality': '320'},
      ),
    );

    final remote = RemoteStateSnapshot(
      version: 1,
      updatedAt: DateTime.parse('2026-03-12T11:00:00Z'),
      queue: RemoteQueueState(
        updatedAt: DateTime.parse('2026-03-12T11:01:00Z'),
        songs: [
          {'id': 'remote', 'name': 'Remote'},
        ],
      ),
      favorites: RemoteFavoritesState(
        updatedAt: DateTime.parse('2026-03-12T09:59:00Z'),
        songs: [
          {'id': 'fav-remote', 'name': 'FavRemote'},
        ],
      ),
      settings: RemoteSettingsState(
        updatedAt: DateTime.parse('2026-03-12T10:04:00Z'),
        data: {'playbackQuality': '128'},
      ),
    );

    final merged = local.mergeWith(remote);

    expect(merged.queue?.songs.first['id'], 'remote');
    expect(merged.favorites?.songs.first['id'], 'fav-local');
    expect(merged.settings?.data['playbackQuality'], '128');
  });
}
