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
  test('SearchStateNotifier triggers auth callback on auth error', () async {
    var logoutCalled = false;
    final notifier = SearchStateNotifier(
      repository: AuthFailRepo(),
      onAuthRequired: () {
        logoutCalled = true;
      },
    );

    await notifier.search('hello');

    expect(logoutCalled, isTrue);
    expect(notifier.state.loading, isFalse);
    expect(notifier.state.error, contains('登录已失效'));
  });
}
