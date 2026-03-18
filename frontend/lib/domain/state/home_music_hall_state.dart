import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discover.dart';
import '../../data/providers.dart';

class HomeMusicHallState {
  final List<LeaderboardItem> leaderboards;
  final bool loading;
  final String? error;
  final String? loadedSource;

  const HomeMusicHallState({
    this.leaderboards = const [],
    this.loading = false,
    this.error,
    this.loadedSource,
  });

  HomeMusicHallState copyWith({
    List<LeaderboardItem>? leaderboards,
    bool? loading,
    String? error,
    bool clearError = false,
    String? loadedSource,
  }) {
    return HomeMusicHallState(
      leaderboards: leaderboards ?? this.leaderboards,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      loadedSource: loadedSource ?? this.loadedSource,
    );
  }
}

class HomeMusicHallNotifier extends StateNotifier<HomeMusicHallState> {
  final Ref _ref;
  final Map<String, List<LeaderboardItem>> _leaderboardCache = {};

  HomeMusicHallNotifier(this._ref) : super(const HomeMusicHallState());

  Future<void> ensureLoaded({required String source}) async {
    if (state.loadedSource == source || state.loading) return;
    await load(source: source);
  }

  Future<void> load({required String source, bool forceRefresh = false}) async {
    final cached = _leaderboardCache[source];
    if (!forceRefresh && cached != null) {
      state = HomeMusicHallState(leaderboards: cached, loadedSource: source);
      return;
    }

    state = state.copyWith(
      loading: true,
      loadedSource: source,
      clearError: true,
    );

    try {
      final repo = _ref.read(solaraRepositoryProvider);
      final leaderboards = await repo.fetchLeaderboardList(source: source);
      _leaderboardCache[source] = leaderboards;
      state = state.copyWith(
        leaderboards: leaderboards,
        loading: false,
        loadedSource: source,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败: $e');
    }
  }
}

final homeMusicHallStateProvider =
    StateNotifierProvider<HomeMusicHallNotifier, HomeMusicHallState>(
      (ref) => HomeMusicHallNotifier(ref),
    );
