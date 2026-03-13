import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/data/api/api_client.dart';
import 'package:solara_flutter/services/remote_state_models.dart';
import 'package:solara_flutter/services/remote_storage_service.dart';
import 'package:solara_flutter/services/storage_service.dart';
import 'package:solara_flutter/services/sync_controller.dart';

class MemoryStorageService extends StorageService {
  final Map<String, Object?> _data = {};

  @override
  Future<void> setJson(String key, Object value) async {
    _data[key] = value;
  }

  @override
  Future<T?> getJson<T>(String key) async {
    return _data[key] as T?;
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }
}

class FakeRemoteStorageService extends RemoteStorageService {
  RemoteStateSnapshot? fetched;
  RemoteStateSnapshot? saved;

  FakeRemoteStorageService()
      : super(client: ApiClient(baseUrl: 'https://example.com', dio: Dio()));

  @override
  Future<RemoteStateSnapshot?> fetchState() async {
    return fetched;
  }

  @override
  Future<bool> saveState(RemoteStateSnapshot snapshot) async {
    saved = snapshot;
    return true;
  }
}

void main() {
  test('SyncController initializes and merges remote into local', () async {
    final storage = MemoryStorageService();
    await storage.setJson('playlistSongs', [
      {'id': 'local', 'name': 'Local'}
    ]);
    await storage.setJson('queueUpdatedAt', '2026-03-12T10:00:00Z');

    final remote = FakeRemoteStorageService();
    remote.fetched = RemoteStateSnapshot(
      version: 1,
      updatedAt: DateTime.parse('2026-03-12T11:00:00Z'),
      queue: RemoteQueueState(
        updatedAt: DateTime.parse('2026-03-12T11:01:00Z'),
        songs: [
          {'id': 'remote', 'name': 'Remote'}
        ],
      ),
    );

    final controller = SyncController(storage: storage, remote: remote);
    await controller.initialize();

    final stored = await storage.getJson<List<dynamic>>('playlistSongs');
    final updatedAt = await storage.getJson<String>('queueUpdatedAt');
    expect(stored?.first['id'], 'remote');
    expect(updatedAt, '2026-03-12T11:01:00.000Z');
  });

  test('SyncController schedules background save', () {
    fakeAsync((async) {
      final storage = MemoryStorageService();
      final remote = FakeRemoteStorageService();
      final controller = SyncController(
        storage: storage,
        remote: remote,
        debounce: const Duration(milliseconds: 50),
      );

      storage.setJson('favoriteSongs', [
        {'id': 'fav', 'name': 'Fav'}
      ]);
      storage.setJson('favoritesUpdatedAt', '2026-03-12T10:00:00Z');
      async.flushMicrotasks();

      controller.scheduleSync();
      async.elapse(const Duration(milliseconds: 49));
      expect(remote.saved, isNull);

      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(remote.saved?.favorites?.songs.first['id'], 'fav');
    });
  });
}
