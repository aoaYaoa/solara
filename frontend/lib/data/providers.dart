import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_client.dart';
import 'api/solara_api.dart';
import 'solara_repository.dart';
import '../services/app_config.dart';
import '../services/cookie_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: AppConfig.baseUrl);
});

final solaraApiProvider = Provider<SolaraApi>((ref) {
  return SolaraApi(client: ref.watch(apiClientProvider));
});

final solaraRepositoryProvider = Provider<SolaraRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return SolaraRepository(api: ref.watch(solaraApiProvider), dio: client.dio);
});

final cookieServiceProvider = Provider<CookieService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CookieService(client.dio);
});
