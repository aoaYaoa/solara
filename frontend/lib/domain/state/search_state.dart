import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../../data/solara_repository.dart';
import '../../data/providers.dart';
import '../../services/providers.dart';

class SearchState {
  final String keyword;
  final String source;
  final int page;
  final bool loading;
  final bool hasMore;
  final String? error;
  final List<Song> results;
  final List<String> history; // 搜索历史词，最新在前

  const SearchState({
    required this.keyword,
    required this.source,
    required this.page,
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.results,
    this.history = const [],
  });

  SearchState copyWith({
    String? keyword,
    String? source,
    int? page,
    bool? loading,
    bool? hasMore,
    String? error,
    List<Song>? results,
    List<String>? history,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      source: source ?? this.source,
      page: page ?? this.page,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      results: results ?? this.results,
      history: history ?? this.history,
    );
  }

  static SearchState initial() {
    return const SearchState(
      keyword: '',
      source: 'netease',
      page: 1,
      loading: false,
      hasMore: true,
      error: null,
      results: [],
      history: [],
    );
  }
}

class SearchStateNotifier extends StateNotifier<SearchState> {
  final SolaraRepository repository;
  SearchStateNotifier({required this.repository})
    : super(SearchState.initial());

  void Function(List<String>)? _onHistoryChanged;

  void setOnHistoryChanged(void Function(List<String>) cb) {
    _onHistoryChanged = cb;
  }

  void loadHistory(List<String> history) {
    state = state.copyWith(history: history);
  }

  void _addHistory(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final updated = [trimmed, ...state.history.where((h) => h != trimmed)];
    state = state.copyWith(history: updated.take(20).toList());
    _onHistoryChanged?.call(state.history);
  }

  void removeHistory(String keyword) {
    state = state.copyWith(history: state.history.where((h) => h != keyword).toList());
    _onHistoryChanged?.call(state.history);
  }

  void clearHistory() {
    state = state.copyWith(history: []);
    _onHistoryChanged?.call(state.history);
  }

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    _addHistory(keyword.trim());
    state = state.copyWith(
      loading: true,
      error: null,
      keyword: keyword,
      page: 1,
    );
    try {
      final results = await repository.search(
        keyword: keyword,
        source: state.source,
        count: 20,
        page: 1,
      );
      state = state.copyWith(
        loading: false,
        results: results,
        hasMore: results.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.keyword.isEmpty) return;
    final nextPage = state.page + 1;
    state = state.copyWith(loading: true, error: null);
    try {
      final results = await repository.search(
        keyword: state.keyword,
        source: state.source,
        count: 20,
        page: nextPage,
      );
      state = state.copyWith(
        loading: false,
        page: nextPage,
        results: [...state.results, ...results],
        hasMore: results.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setSource(String source) {
    state = state.copyWith(source: source);
  }

  void clearResults() {
    state = SearchState.initial().copyWith(source: state.source, history: state.history);
  }
}

final searchStateProvider =
    StateNotifierProvider<SearchStateNotifier, SearchState>((ref) {
      final notifier = SearchStateNotifier(
        repository: ref.watch(solaraRepositoryProvider),
      );
      // 持久化搜索历史
      final persistence = ref.read(persistentStateProvider);
      persistence.loadSearchHistory(notifier);
      notifier.setOnHistoryChanged((history) => persistence.saveSearchHistory(history));
      return notifier;
    });
