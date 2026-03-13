import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/data/api/api_client.dart';
import 'package:solara_flutter/services/auth_service.dart';

void main() {
  test('login returns false when credentials are invalid', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'code': 401, 'message': '用户名或密码错误'},
              statusCode: 401,
            ),
          );
        },
      ),
    );

    final auth = AuthStateNotifier(
      client: ApiClient(baseUrl: 'https://example.com', dio: dio),
    );

    final ok = await auth.login('testuser', 'wrongpassword');

    expect(ok, isFalse);
    expect(auth.state.isAuthed, isFalse);
  });

  test('login returns true when credentials are valid', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'code': 200,
                'message': '登录成功',
                'data': {
                  'access_token': 'test.jwt.token',
                  'token_type': 'Bearer',
                  'expires_in': 86400,
                },
              },
              statusCode: 200,
            ),
          );
        },
      ),
    );

    final auth = AuthStateNotifier(
      client: ApiClient(baseUrl: 'https://example.com', dio: dio),
    );

    final ok = await auth.login('testuser', 'correctpassword');

    expect(ok, isTrue);
    expect(auth.state.isAuthed, isTrue);
  });
}
