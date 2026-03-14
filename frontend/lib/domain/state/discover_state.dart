import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discover.dart';
import '../models/song.dart';
import '../../data/providers.dart';

class DiscoverState {
  final List<LeaderboardItem> leaderboards;
  final List<SongListItem> songLists;
  final bool loading; // unified initial/refresh loading
  final bool loadingMoreSongLists;
  final int songListPage;
  final bool hasMoreSongLists;
  final String? error;

  const DiscoverState({
    this.leaderboards = const [],
    this.songLists = const [],
    this.loading = false,
    this.loadingMoreSongLists = false,
    this.songListPage = 1,
    this.hasMoreSongLists = true,
    this.error,
  });

  // Keep legacy getters so existing UI code keeps compiling
  bool get loadingLeaderboards => loading;
  bool get loadingSongLists => loading;

  DiscoverState copyWith({
    List<LeaderboardItem>? leaderboards,
    List<SongListItem>? songLists,
    bool? loading,
    bool? loadingMoreSongLists,
    int? songListPage,
    bool? hasMoreSongLists,
    String? error,
    bool clearError = false,
  }) {
    return DiscoverState(
      leaderboards: leaderboards ?? this.leaderboards,
      songLists: songLists ?? this.songLists,
      loading: loading ?? this.loading,
      loadingMoreSongLists: loadingMoreSongLists ?? this.loadingMoreSongLists,
      songListPage: songListPage ?? this.songListPage,
      hasMoreSongLists: hasMoreSongLists ?? this.hasMoreSongLists,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  final Ref _ref;

  DiscoverNotifier(this._ref) : super(const DiscoverState());

  Future<void> loadAll({String source = 'kw'}) async {
    state = state.copyWith(
      loading: true,
      songListPage: 1,
      hasMoreSongLists: true,
      clearError: true,
    );
    try {
      final repo = _ref.read(solaraRepositoryProvider);
      final results = await Future.wait([
        repo.fetchLeaderboardList(source: source),
        repo.fetchSongList(source: source, page: 1),
      ]);
      final leaderboards = results[0] as List<LeaderboardItem>;
      final songLists = results[1] as List<SongListItem>;
      state = state.copyWith(
        leaderboards: leaderboards,
        songLists: songLists,
        loading: false,
        songListPage: 1,
        hasMoreSongLists: songLists.length >= 30,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败: $e');
    }
  }

  Future<void> loadMoreSongLists({required String source}) async {
    if (state.loadingMoreSongLists || !state.hasMoreSongLists) return;
    state = state.copyWith(loadingMoreSongLists: true);
    try {
      final repo = _ref.read(solaraRepositoryProvider);
      final nextPage = state.songListPage + 1;
      final items = await repo.fetchSongList(source: source, page: nextPage);
      state = state.copyWith(
        songLists: [...state.songLists, ...items],
        loadingMoreSongLists: false,
        songListPage: nextPage,
        hasMoreSongLists: items.length >= 30,
      );
    } catch (e) {
      state = state.copyWith(loadingMoreSongLists: false);
    }
  }

  Future<List<Song>> fetchLeaderboardDetail({
    required String id,
    required String source,
    int page = 1,
  }) async {
    final repo = _ref.read(solaraRepositoryProvider);
    return repo.fetchLeaderboardDetail(id: id, source: source, page: page);
  }

  Future<List<Song>> fetchSongListDetail({
    required String id,
    required String source,
    int page = 1,
  }) async {
    final repo = _ref.read(solaraRepositoryProvider);
    return repo.fetchSongListDetail(id: id, source: source, page: page);
  }
}

final discoverStateProvider =
    StateNotifierProvider<DiscoverNotifier, DiscoverState>(
      (ref) => DiscoverNotifier(ref),
    );
