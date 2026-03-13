import '../data/api/api_client.dart';
import 'remote_state_models.dart';

class RemoteStorageService {
  final ApiClient client;
  final String key;

  RemoteStorageService({required this.client, this.key = 'solara_state'});

  Future<RemoteStateSnapshot?> fetchState() async {
    final response = await client.dio.get(
      '/api/storage',
      queryParameters: {'keys': key},
    );
    final data = response.data;
    if (data is! Map) return null;
    if (data['d1Available'] != true) return null;
    final payload = data['data'];
    if (payload is! Map) return null;
    final raw = payload[key];
    if (raw is! Map) return null;
    return RemoteStateSnapshot.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<bool> saveState(RemoteStateSnapshot snapshot) async {
    final response = await client.dio.post(
      '/api/storage',
      data: {
        'data': {key: snapshot.toJson()},
      },
    );
    return response.data is Map && response.data['d1Available'] == true;
  }

  Future<bool> deleteState() async {
    final response = await client.dio.delete(
      '/api/storage',
      data: {'keys': [key]},
    );
    return response.data is Map && response.data['d1Available'] == true;
  }
}
