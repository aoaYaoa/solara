import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solara_flutter/services/storage_service.dart';

void main() {
  test('StorageService saves and reads json', () async {
    SharedPreferences.setMockInitialValues({});
    final service = StorageService();

    await service.setJson('favorites', {'a': 1});
    final value = await service.getJson<Map<String, dynamic>>('favorites');

    expect(value?['a'], 1);
  });
}
