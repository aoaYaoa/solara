import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api/api_client.dart';
import '../data/providers.dart';

const _kTokenKey = 'jwt_token';
const _kPasswordKey = 'user_password';

class AuthState {
  final bool isAuthed;
  const AuthState({required this.isAuthed});
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final ApiClient client;

  AuthStateNotifier({required this.client})
    : super(const AuthState(isAuthed: false));

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    if (token == null || token.isEmpty) return;
    client.setToken(token);
    // 本地有 token 直接信任，避免网络慢时长时间白屏
    // token 真正过期时会在 API 调用时触发 autoRelogin
    state = const AuthState(isAuthed: true);
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await client.dio.post(
        '/api/login',
        data: {'password': password},
      );
      final data = response.data;
      print(
        '[AuthService] login response: status=${response.statusCode} data=$data',
      );
      if (data is! Map || data['success'] != true) {
        state = const AuthState(isAuthed: false);
        return false;
      }
      final token = data['data']?['token'] as String?;
      if (token == null || token.isEmpty) {
        state = const AuthState(isAuthed: false);
        return false;
      }
      client.setToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      await prefs.setString(_kPasswordKey, password);
      state = const AuthState(isAuthed: true);
      return true;
    } catch (e, st) {
      print('[AuthService] login error: $e\n$st');
      state = const AuthState(isAuthed: false);
      return false;
    }
  }

  Future<bool> autoRelogin() async {
    final prefs = await SharedPreferences.getInstance();
    final password = prefs.getString(_kPasswordKey);
    if (password == null || password.isEmpty) return false;
    return login('', password);
  }

  Future<void> logout() async {
    client.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kPasswordKey);
    state = const AuthState(isAuthed: false);
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(client: ref.watch(apiClientProvider)),
);
