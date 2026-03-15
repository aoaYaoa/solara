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
  final String? loadedSource; // 记录当前已加载数据对应的音源

  const DiscoverState({
    this.leaderboards = const [],
    this.songLists = const [],
    this.loading = false,
    this.loadingMoreSongLists = false,
    this.songListPage = 1,
    this.hasMoreSongLists = true,
    this.error,
    this.loadedSource,
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
    String? loadedSource,
  }) {
    return DiscoverState(
      leaderboards: leaderboards ?? this.leaderboards,
      songLists: songLists ?? this.songLists,
      loading: loading ?? this.loading,
      loadingMoreSongLists: loadingMoreSongLists ?? this.loadingMoreSongLists,
      songListPage: songListPage ?? this.songListPage,
      hasMoreSongLists: hasMoreSongLists ?? this.hasMoreSongLists,
      error: clearError ? null : (error ?? this.error),
      loadedSource: loadedSource ?? this.loadedSource,
    );
  }
}

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  final Ref _ref;
  final Map<String, List<Song>> _detailCache = {};

  DiscoverNotifier(this._ref) : super(const DiscoverState());

  /// 如果当前 source 数据已加载则跳过，避免每次切换 tab 重新请求
  Future<void> ensureLoaded({required String source}) async {
    // 已加载完成且是同一 source 则跳过
    if (state.loadedSource == source && !state.loading && state.leaderboards.isNotEmpty) return;
    // 正在加载同一 source 则等待，不重复发请求
    if (state.loading && state.loadedSource == source) return;
    await loadAll(source: source);
  }

  Future<void> loadAll({String source = 'netease'}) async {
    state = DiscoverState(loading: true, loadedSource: source);
    try {
      final repo = _ref.read(solaraRepositoryProvider);
      List<LeaderboardItem> leaderboards = [];
      List<SongListItem> songLists = [];
      try {
        leaderboards = await repo.fetchLeaderboardList(source: source)
            .timeout(const Duration(seconds: 15));
      } catch (_) {}
      if (!mounted) return;
      state = state.copyWith(
        leaderboards: leaderboards,
        loading: false,
        loadedSource: source,
        clearError: true,
      );
      try {
        songLists = await repo.fetchSongList(source: source, page: 1)
            .timeout(const Duration(seconds: 15));
      } catch (_) {}
      if (!mounted) return;
      state = state.copyWith(
        songLists: songLists,
        songListPage: 1,
        hasMoreSongLists: songLists.length >= 30,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
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
    final cacheKey = '$source:leaderboard:$id:$page';
    if (_detailCache.containsKey(cacheKey)) return _detailCache[cacheKey]!;
    final repo = _ref.read(solaraRepositoryProvider);
    final songs = await repo.fetchLeaderboardDetail(id: id, source: source, page: page);
    _detailCache[cacheKey] = songs;
    return songs;
  }

  Future<List<Song>> fetchSongListDetail({
    required String id,
    required String source,
    int page = 1,
  }) async {
    final cacheKey = '$source:songlist:$id:$page';
    if (_detailCache.containsKey(cacheKey)) return _detailCache[cacheKey]!;
    final repo = _ref.read(solaraRepositoryProvider);
    final songs = await repo.fetchSongListDetail(id: id, source: source, page: page);
    _detailCache[cacheKey] = songs;
    return songs;
  }
}

final discoverStateProvider =
    StateNotifierProvider<DiscoverNotifier, DiscoverState>(
      (ref) => DiscoverNotifier(ref),
    );
