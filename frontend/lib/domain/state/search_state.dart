import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../../data/solara_repository.dart';
import '../../data/providers.dart';
import '../../services/auth_service.dart';

class SearchState {
  final String keyword;
  final String source;
  final int page;
  final bool loading;
  final bool hasMore;
  final String? error;
  final List<Song> results;

  const SearchState({
    required this.keyword,
    required this.source,
    required this.page,
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.results,
  });

  SearchState copyWith({
    String? keyword,
    String? source,
    int? page,
    bool? loading,
    bool? hasMore,
    String? error,
    List<Song>? results,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      source: source ?? this.source,
      page: page ?? this.page,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      results: results ?? this.results,
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
    );
  }
}

class SearchStateNotifier extends StateNotifier<SearchState> {
  final SolaraRepository repository;
  final void Function()? onAuthRequired;

  SearchStateNotifier({required this.repository, this.onAuthRequired})
    : super(SearchState.initial());

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) return;
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
      if (e is AuthRequiredException) {
        onAuthRequired?.call();
        state = state.copyWith(loading: false, error: '登录已失效，请重新登录');
        return;
      }
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
      if (e is AuthRequiredException) {
        onAuthRequired?.call();
        state = state.copyWith(loading: false, error: '登录已失效，请重新登录');
        return;
      }
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setSource(String source) {
    state = state.copyWith(source: source);
  }

  void clearResults() {
    state = SearchState.initial().copyWith(source: state.source);
  }
}

final searchStateProvider =
    StateNotifierProvider<SearchStateNotifier, SearchState>(
      (ref) => SearchStateNotifier(
        repository: ref.watch(solaraRepositoryProvider),
        onAuthRequired: () => ref.read(authStateProvider.notifier).logout(),
      ),
    );
