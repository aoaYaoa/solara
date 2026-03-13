import 'dart:async';
import 'remote_state_models.dart';
import 'remote_storage_service.dart';
import 'storage_service.dart';

class SyncController {
  final StorageService storage;
  final RemoteStorageService remote;
  final Duration debounce;
  Timer? _debounceTimer;
  bool _syncInFlight = false;
  bool _initialized = false;

  SyncController({
    required this.storage,
    required this.remote,
    this.debounce = const Duration(milliseconds: 800),
  });

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final local = await _loadLocalSnapshot();
    final remoteSnapshot = await remote.fetchState();
    if (remoteSnapshot == null) {
      if (local != null) {
        await _persistSnapshot(local);
        await remote.saveState(local);
      }
      return;
    }

    final merged = local == null ? remoteSnapshot : local.mergeWith(remoteSnapshot);
    await _persistSnapshot(merged);

    if (local != null && merged.updatedAt.isAfter(remoteSnapshot.updatedAt)) {
      await remote.saveState(merged);
    }
  }

  void scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _performSync);
  }

  Future<void> _performSync() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final local = await _loadLocalSnapshot();
      if (local != null) {
        await remote.saveState(local);
      }
    } finally {
      _syncInFlight = false;
    }
  }

  Future<RemoteStateSnapshot?> _loadLocalSnapshot() async {
    final now = DateTime.now().toUtc();

    final queueRaw = await storage.getJson<List<dynamic>>('playlistSongs');
    final queueUpdatedAtRaw = await storage.getJson<String>('queueUpdatedAt');
    final queue = _buildQueue(queueRaw, queueUpdatedAtRaw, now);

    final favoritesRaw = await storage.getJson<List<dynamic>>('favoriteSongs');
    final favoritesUpdatedAtRaw =
        await storage.getJson<String>('favoritesUpdatedAt');
    final favorites = _buildFavorites(favoritesRaw, favoritesUpdatedAtRaw, now);

    final settingsRaw = await storage.getJson<Map<String, dynamic>>('settings');
    final settingsUpdatedAtRaw = await storage.getJson<String>('settingsUpdatedAt');
    final settings = _buildSettings(settingsRaw, settingsUpdatedAtRaw, now);

    if (queue == null && favorites == null && settings == null) {
      return null;
    }

    final latest = _latestTimestamp([
      queue?.updatedAt,
      favorites?.updatedAt,
      settings?.updatedAt,
    ]);

    return RemoteStateSnapshot(
      version: 1,
      updatedAt: latest,
      queue: queue,
      favorites: favorites,
      settings: settings,
    );
  }

  RemoteQueueState? _buildQueue(
    List<dynamic>? raw,
    String? updatedAtRaw,
    DateTime now,
  ) {
    if (raw == null) return null;
    final updatedAt = _resolveUpdatedAt(updatedAtRaw, now: now, hasData: true);
    final songs = raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    return RemoteQueueState(updatedAt: updatedAt, songs: songs);
  }

  RemoteFavoritesState? _buildFavorites(
    List<dynamic>? raw,
    String? updatedAtRaw,
    DateTime now,
  ) {
    if (raw == null) return null;
    final updatedAt = _resolveUpdatedAt(updatedAtRaw, now: now, hasData: true);
    final songs = raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    return RemoteFavoritesState(updatedAt: updatedAt, songs: songs);
  }

  RemoteSettingsState? _buildSettings(
    Map<String, dynamic>? raw,
    String? updatedAtRaw,
    DateTime now,
  ) {
    if (raw == null) return null;
    final updatedAt = _resolveUpdatedAt(updatedAtRaw, now: now, hasData: true);
    return RemoteSettingsState(updatedAt: updatedAt, data: raw);
  }

  DateTime _resolveUpdatedAt(
    String? raw, {
    required DateTime now,
    required bool hasData,
  }) {
    if (raw != null && raw.isNotEmpty) {
      return DateTime.parse(raw);
    }
    if (!hasData) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return now;
  }

  DateTime _latestTimestamp(List<DateTime?> candidates) {
    DateTime latest = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    for (final candidate in candidates) {
      if (candidate != null && candidate.isAfter(latest)) {
        latest = candidate;
      }
    }
    return latest;
  }

  Future<void> _persistSnapshot(RemoteStateSnapshot snapshot) async {
    final queue = snapshot.queue;
    if (queue != null) {
      await storage.setJson('playlistSongs', queue.songs);
      await storage.setJson('queueUpdatedAt', queue.updatedAt.toIso8601String());
    }

    final favorites = snapshot.favorites;
    if (favorites != null) {
      await storage.setJson('favoriteSongs', favorites.songs);
      await storage.setJson(
        'favoritesUpdatedAt',
        favorites.updatedAt.toIso8601String(),
      );
    }

    final settings = snapshot.settings;
    if (settings != null) {
      await storage.setJson('settings', settings.data);
      await storage.setJson(
        'settingsUpdatedAt',
        settings.updatedAt.toIso8601String(),
      );
    }
  }
}
