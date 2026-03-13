import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';
import 'persistent_state_service.dart';
import '../data/providers.dart';
import 'remote_storage_service.dart';
import 'sync_controller.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final remoteStorageServiceProvider = Provider<RemoteStorageService>((ref) {
  return RemoteStorageService(client: ref.watch(apiClientProvider));
});

final syncControllerProvider = Provider<SyncController>((ref) {
  return SyncController(
    storage: ref.watch(storageServiceProvider),
    remote: ref.watch(remoteStorageServiceProvider),
  );
});

final persistentStateProvider = Provider<PersistentStateService>(
  (ref) => PersistentStateService(
    storage: ref.watch(storageServiceProvider),
    syncController: ref.watch(syncControllerProvider),
  ),
);
