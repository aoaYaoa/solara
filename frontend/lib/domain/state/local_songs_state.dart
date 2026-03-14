import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../../services/providers.dart';

class LocalSongsNotifier extends StateNotifier<List<Song>> {
  LocalSongsNotifier(this._ref) : super([]) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final songs = await _ref.read(persistentStateProvider).loadLocalSongs();
    state = songs;
  }

  Future<void> addSongs(List<Song> songs) async {
    // 按路径去重
    final existing = {for (final s in state) s.id};
    final newSongs = songs.where((s) => !existing.contains(s.id)).toList();
    if (newSongs.isEmpty) return;
    state = [...state, ...newSongs];
    await _ref.read(persistentStateProvider).saveLocalSongs(state);
  }

  Future<void> removeSong(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _ref.read(persistentStateProvider).saveLocalSongs(state);
  }

  Future<void> clear() async {
    state = [];
    await _ref.read(persistentStateProvider).saveLocalSongs([]);
  }
}

final localSongsProvider =
    StateNotifierProvider<LocalSongsNotifier, List<Song>>(
      (ref) => LocalSongsNotifier(ref),
    );
