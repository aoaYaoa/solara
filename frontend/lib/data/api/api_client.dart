import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_adapter_stub.dart' if (dart.library.html) 'web_adapter_web.dart';

class ApiClient {
  final String baseUrl;
  final Dio dio;
  String? _token;

  /// 当 token 过期时调用，返回 true 表示重新登录成功
  Future<bool> Function()? onTokenExpired;

  ApiClient({required this.baseUrl, Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 90),
              followRedirects: false,
              validateStatus: (status) => status != null && status < 500,
            ),
          ) {
    if (kIsWeb) {
      configureWebAdapter(this.dio);
    }
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final status = response.statusCode ?? 0;
          final location = response.headers.value('location') ?? '';
          final isAuthFail =
              status == 401 ||
              status == 403 ||
              status == 302 ||
              location.contains('/login');
          final isRetry = response.requestOptions.extra['_retry'] == true;
          if (isAuthFail && !isRetry && onTokenExpired != null) {
            final relogined = await onTokenExpired!();
            if (relogined) {
              try {
                final opts = response.requestOptions;
                opts.extra['_retry'] = true;
                final retry = await this.dio.fetch(opts);
                return handler.resolve(retry);
              } catch (_) {}
            }
          }
          handler.next(response);
        },
      ),
    );
  }

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }
}
