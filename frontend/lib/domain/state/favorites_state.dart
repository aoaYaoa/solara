import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'queue_state.dart';
import '../../services/persistent_state_service.dart';
import '../../services/providers.dart';

class FavoritesState {
  final List<Song> favorites;
  final int currentIndex;
  final PlayMode playMode;

  const FavoritesState({
    required this.favorites,
    required this.currentIndex,
    required this.playMode,
  });

  FavoritesState copyWith({
    List<Song>? favorites,
    int? currentIndex,
    PlayMode? playMode,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      currentIndex: currentIndex ?? this.currentIndex,
      playMode: playMode ?? this.playMode,
    );
  }

  static FavoritesState initial() {
    return const FavoritesState(
      favorites: [],
      currentIndex: 0,
      playMode: PlayMode.list,
    );
  }
}

class FavoritesStateNotifier extends StateNotifier<FavoritesState> {
  final PersistentStateService persistence;

  FavoritesStateNotifier({required this.persistence}) : super(FavoritesState.initial()) {
    persistence.loadFavorites(this);
  }

  bool isFavorite(Song song) {
    return state.favorites.any((item) => item.id == song.id);
  }

  void toggleFavorite(Song song) {
    final updated = [...state.favorites];
    final index = updated.indexWhere((item) => item.id == song.id);
    if (index >= 0) {
      updated.removeAt(index);
    } else {
      updated.add(song);
    }
    final nextIndex = state.currentIndex.clamp(0, updated.isEmpty ? 0 : updated.length - 1);
    state = state.copyWith(favorites: updated, currentIndex: nextIndex);
    persistence.saveFavorites(state);
  }

  void clear() {
    state = state.copyWith(favorites: [], currentIndex: 0);
    persistence.saveFavorites(state);
  }

  void setPlayMode(PlayMode mode) {
    state = state.copyWith(playMode: mode);
  }
}

final favoritesStateProvider = StateNotifierProvider<FavoritesStateNotifier, FavoritesState>(
  (ref) => FavoritesStateNotifier(persistence: ref.watch(persistentStateProvider)),
);
