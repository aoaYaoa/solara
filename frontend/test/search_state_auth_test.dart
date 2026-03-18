import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/data/api/api_client.dart';
import 'package:solara_flutter/data/api/solara_api.dart';
import 'package:solara_flutter/data/solara_repository.dart';
import 'package:solara_flutter/domain/models/song.dart';
import 'package:solara_flutter/domain/state/search_state.dart';

class AuthFailRepo extends SolaraRepository {
  AuthFailRepo()
      : super(
          api: SolaraApi(client: ApiClient(baseUrl: 'https://example.com')),
          dio: Dio(BaseOptions(baseUrl: 'https://example.com')),
        );

  @override
  Future<List<Song>> search({
    required String keyword,
    required String source,
    int count = 20,
    int page = 1,
  }) {
    throw AuthRequiredException();
  }
}

void main() {
  test('SearchStateNotifier sets error state when auth fails after interceptor retry', () async {
    final notifier = SearchStateNotifier(
      repository: AuthFailRepo(),
    );

    await notifier.search('hello');

    expect(notifier.state.loading, isFalse);
    expect(notifier.state.error, isNotNull);
  });
}
