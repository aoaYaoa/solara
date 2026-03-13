import 'dart:async';
import '../domain/models/history_entry.dart';
import '../domain/models/song.dart';
import '../domain/models/user_playlist.dart';
import '../domain/state/favorites_state.dart';
import '../domain/state/history_state.dart';
import '../domain/state/playlist_state.dart';
import '../domain/state/queue_state.dart';
import '../domain/state/settings_state.dart';
import 'storage_service.dart';
import 'sync_controller.dart';

class PersistentStateService {
  final StorageService storage;
  final SyncController? syncController;

  PersistentStateService({required this.storage, this.syncController});

  Future<void> loadQueue(QueueStateNotifier notifier) async {
    final data = await storage.getJson<List<dynamic>>('playlistSongs');
    if (data == null) return;
    final songs =
        data
            .map(
              (item) => Song.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
    notifier.addSongs(songs);
  }

  Future<void> saveQueue(QueueState state) async {
    final payload = state.songs.map((s) => s.toJson()).toList();
    await storage.setJson('playlistSongs', payload);
    await storage.setJson(
      'queueUpdatedAt',
      DateTime.now().toUtc().toIso8601String(),
    );
    syncController?.scheduleSync();
  }

  Future<void> loadFavorites(FavoritesStateNotifier notifier) async {
    final data = await storage.getJson<List<dynamic>>('favoriteSongs');
    if (data == null) return;
    final songs =
        data
            .map(
              (item) => Song.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
    for (final song in songs) {
      if (!notifier.isFavorite(song)) {
        notifier.toggleFavorite(song);
      }
    }
  }

  Future<void> saveFavorites(FavoritesState state) async {
    final payload = state.favorites.map((s) => s.toJson()).toList();
    await storage.setJson('favoriteSongs', payload);
    await storage.setJson(
      'favoritesUpdatedAt',
      DateTime.now().toUtc().toIso8601String(),
    );
    syncController?.scheduleSync();
  }

  Future<void> loadSettings(SettingsStateNotifier notifier) async {
    final data = await storage.getJson<Map<String, dynamic>>('settings');
    if (data == null) return;
    if (data['playbackQuality'] != null) {
      notifier.setPlaybackQuality(data['playbackQuality'].toString());
    }
    if (data['volume'] != null) {
      final volume = double.tryParse(data['volume'].toString());
      if (volume != null) notifier.setVolume(volume);
    }
    if (data['searchSource'] != null) {
      notifier.setSearchSource(data['searchSource'].toString());
    }
    if (data['debugMode'] != null) {
      notifier.setDebugMode(
        data['debugMode'] == true || data['debugMode'] == 'true',
      );
    }
    if (data['themeMode'] != null) {
      notifier.setThemeMode(data['themeMode'].toString());
    }
  }

  Future<void> saveSettings(SettingsState state) async {
    await storage.setJson('settings', {
      'playbackQuality': state.playbackQuality,
      'volume': state.volume,
      'searchSource': state.searchSource,
      'debugMode': state.debugMode,
      'themeMode': state.themeMode,
    });
    await storage.setJson(
      'settingsUpdatedAt',
      DateTime.now().toUtc().toIso8601String(),
    );
    syncController?.scheduleSync();
  }

  Future<void> loadHistory(HistoryStateNotifier notifier) async {
    final data = await storage.getJson<List<dynamic>>('listenHistory');
    if (data == null) return;
    final entries =
        data
            .map(
              (item) =>
                  HistoryEntry.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
    notifier.loadEntries(entries);
  }

  Future<void> saveHistory(HistoryState state) async {
    final payload = state.entries.map((e) => e.toJson()).toList();
    await storage.setJson('listenHistory', payload);
  }

  Future<void> loadPlaylists(PlaylistStateNotifier notifier) async {
    final data = await storage.getJson<List<dynamic>>('userPlaylists');
    if (data == null) return;
    final playlists =
        data
            .map(
              (item) =>
                  UserPlaylist.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
    notifier.loadPlaylists(playlists);
  }

  Future<void> savePlaylists(PlaylistState state) async {
    final payload = state.playlists.map((p) => p.toJson()).toList();
    await storage.setJson('userPlaylists', payload);
  }
}
