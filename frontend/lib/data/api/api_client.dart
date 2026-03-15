import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_adapter_stub.dart' if (dart.library.html) 'web_adapter_web.dart';

class ApiClient {
  final String baseUrl;
  final Dio dio;
  String? _token;

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
