import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/data/api/api_client.dart';
import 'package:solara_flutter/services/remote_state_models.dart';
import 'package:solara_flutter/services/remote_storage_service.dart';

void main() {
  test('RemoteStorageService fetches solara_state', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) {
        requests.add(options);
        handler.resolve(
          Response(
            requestOptions: options,
            data: {
              'd1Available': true,
              'data': {
                'solara_state': {
                  'version': 1,
                  'updatedAt': '2026-03-12T10:00:00Z',
                  'queue': {
                    'updatedAt': '2026-03-12T10:01:00Z',
                    'songs': [],
                  },
                }
              },
            },
          ),
        );
      }),
    );

    final service = RemoteStorageService(
      client: ApiClient(baseUrl: 'https://example.com', dio: dio),
    );

    final snapshot = await service.fetchState();

    expect(requests.length, 1);
    expect(requests.single.path, '/api/storage');
    expect(requests.single.queryParameters['keys'], 'solara_state');
    expect(snapshot?.version, 1);
  });

  test('RemoteStorageService saves solara_state payload', () async {
    final requests = <RequestOptions>[];
    final payloads = <dynamic>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) {
        requests.add(options);
        payloads.add(options.data);
        handler.resolve(
          Response(
            requestOptions: options,
            data: {'d1Available': true, 'updated': 1},
          ),
        );
      }),
    );

    final service = RemoteStorageService(
      client: ApiClient(baseUrl: 'https://example.com', dio: dio),
    );

    final snapshot = RemoteStateSnapshot(
      version: 1,
      updatedAt: DateTime.parse('2026-03-12T10:00:00Z'),
      queue: RemoteQueueState(updatedAt: DateTime.utc(2026, 3, 12), songs: []),
    );

    final success = await service.saveState(snapshot);

    expect(success, isTrue);
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/api/storage');
    expect(
      payloads.single,
      {
        'data': {
          'solara_state': snapshot.toJson(),
        }
      },
    );
  });

  test('RemoteStorageService returns null when d1 unavailable', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            data: {'d1Available': false},
          ),
        );
      }),
    );

    final service = RemoteStorageService(
      client: ApiClient(baseUrl: 'https://example.com', dio: dio),
    );

    final snapshot = await service.fetchState();

    expect(snapshot, isNull);
  });
}
