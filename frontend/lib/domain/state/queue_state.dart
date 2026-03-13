import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../../services/persistent_state_service.dart';
import '../../services/providers.dart';

enum PlayMode { list, single, random }

class QueueState {
  final List<Song> songs;
  final int currentIndex;
  final PlayMode playMode;

  const QueueState({
    required this.songs,
    required this.currentIndex,
    required this.playMode,
  });

  QueueState copyWith({
    List<Song>? songs,
    int? currentIndex,
    PlayMode? playMode,
  }) {
    return QueueState(
      songs: songs ?? this.songs,
      currentIndex: currentIndex ?? this.currentIndex,
      playMode: playMode ?? this.playMode,
    );
  }

  static QueueState initial() {
    return const QueueState(
      songs: [],
      currentIndex: 0,
      playMode: PlayMode.list,
    );
  }
}

class QueueStateNotifier extends StateNotifier<QueueState> {
  final PersistentStateService persistence;

  QueueStateNotifier({required this.persistence})
    : super(QueueState.initial()) {
    persistence.loadQueue(this);
  }

  void addSong(Song song) {
    // 已存在则跳过，避免重复
    if (state.songs.any((s) => s.id == song.id)) return;
    final updated = [...state.songs, song];
    state = state.copyWith(songs: updated);
    persistence.saveQueue(state);
  }

  void selectSong(Song song) {
    final index = state.songs.indexWhere((item) => item.id == song.id);
    if (index == -1) {
      addSong(song);
      setCurrentIndex(state.songs.length - 1);
      return;
    }
    setCurrentIndex(index);
  }

  void addSongs(List<Song> songs) {
    if (songs.isEmpty) return;
    final existingIds = state.songs.map((s) => s.id).toSet();
    final newSongs = songs.where((s) => !existingIds.contains(s.id)).toList();
    if (newSongs.isEmpty) return;
    final updated = [...state.songs, ...newSongs];
    state = state.copyWith(songs: updated);
    persistence.saveQueue(state);
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.songs.length) return;
    final updated = [...state.songs]..removeAt(index);
    final nextIndex = state.currentIndex.clamp(
      0,
      updated.isEmpty ? 0 : updated.length - 1,
    );
    state = state.copyWith(songs: updated, currentIndex: nextIndex);
    persistence.saveQueue(state);
  }

  void clear() {
    state = state.copyWith(songs: [], currentIndex: 0);
    persistence.saveQueue(state);
  }

  void setCurrentIndex(int index) {
    if (index < 0 || index >= state.songs.length) return;
    state = state.copyWith(currentIndex: index);
  }

  void setPlayMode(PlayMode mode) {
    state = state.copyWith(playMode: mode);
  }

  void cyclePlayMode() {
    final modes = PlayMode.values;
    final next = modes[(modes.indexOf(state.playMode) + 1) % modes.length];
    state = state.copyWith(playMode: next);
  }
}

final queueStateProvider = StateNotifierProvider<
  QueueStateNotifier,
  QueueState
>((ref) => QueueStateNotifier(persistence: ref.watch(persistentStateProvider)));
