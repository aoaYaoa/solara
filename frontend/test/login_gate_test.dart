import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/app/app.dart';
import 'package:solara_flutter/data/api/api_client.dart';
import 'package:solara_flutter/services/auth_service.dart';
import 'package:solara_flutter/services/providers.dart';
import 'package:solara_flutter/services/remote_state_models.dart';
import 'package:solara_flutter/services/remote_storage_service.dart';
import 'package:solara_flutter/services/storage_service.dart';
import 'package:solara_flutter/services/sync_controller.dart';

class TestAuthNotifier extends AuthStateNotifier {
  TestAuthNotifier()
      : super(client: ApiClient(baseUrl: 'https://example.com', dio: Dio()));

  void setAuthed(bool value) {
    state = AuthState(isAuthed: value);
  }
}

class NoopStorageService extends StorageService {
  @override
  Future<void> setJson(String key, Object value) async {}

  @override
  Future<T?> getJson<T>(String key) async => null;

  @override
  Future<void> remove(String key) async {}
}

class NoopRemoteStorageService extends RemoteStorageService {
  NoopRemoteStorageService()
      : super(client: ApiClient(baseUrl: 'https://example.com', dio: Dio()));

  @override
  Future<RemoteStateSnapshot?> fetchState() async => null;

  @override
  Future<bool> saveState(RemoteStateSnapshot snapshot) async => true;
}

class FakeSyncController extends SyncController {
  bool initializeCalled = false;

  FakeSyncController()
      : super(storage: NoopStorageService(), remote: NoopRemoteStorageService());

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }
}

void main() {
  testWidgets('Unauthed user sees login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SolaraApp()));
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Authed user triggers sync initialization', (tester) async {
    final authNotifier = TestAuthNotifier();
    final syncController = FakeSyncController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => authNotifier),
          syncControllerProvider.overrideWithValue(syncController),
        ],
        child: const SolaraApp(),
      ),
    );

    expect(syncController.initializeCalled, isFalse);

    authNotifier.setAuthed(true);
    await tester.pump();
    await tester.pump();

    expect(syncController.initializeCalled, isTrue);
  });
}
