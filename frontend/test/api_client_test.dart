import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/data/api/api_client.dart';
import 'package:solara_flutter/services/app_config.dart';

void main() {
  test('ApiClient builds base url', () {
    final client = ApiClient(baseUrl: 'https://example.com');
    expect(client.baseUrl, 'https://example.com');
  });

  test('AppConfig baseUrl uses solara.uonoe.com', () {
    expect(AppConfig.baseUrl, 'https://solara.uonoe.com');
  });
}
