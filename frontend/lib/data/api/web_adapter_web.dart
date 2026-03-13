import 'package:dio/dio.dart';
import 'package:dio_web_adapter/dio_web_adapter.dart';

void configureWebAdapter(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: false);
}
