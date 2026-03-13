# Solara CF Storage Sync + Local Request Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Cloudflare D1 storage sync (local-first) and fix local-to-CF request behavior for Solara Flutter.

**Architecture:** Introduce a remote storage layer (`RemoteStorageService`) plus a sync controller that merges local/remote state and pushes updates in the background. Update the API base URL and ensure credentialed requests work with cookies.

**Tech Stack:** Flutter, Dart, flutter_riverpod, dio, dio_web_adapter, shared_preferences.

---

### Task 1: Update base URL and credential handling

**Files:**
- Modify: `/Users/aay/自有项目/solara_flutter/lib/services/app_config.dart`
- Modify: `/Users/aay/自有项目/solara_flutter/lib/data/api/api_client.dart`
- Modify: `/Users/aay/自有项目/solara_flutter/pubspec.yaml`
- Test: `/Users/aay/自有项目/solara_flutter/test/api_client_test.dart`

**Step 1: Write the failing test**

Add a test that asserts `AppConfig.baseUrl` is `https://solara.uonoe.com`.

**Step 2: Run test to verify it fails**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/api_client_test.dart`
Expected: FAIL with baseUrl mismatch.

**Step 3: Implement minimal code**

- Update `AppConfig.baseUrl`.
- Add `dio_web_adapter` dependency.
- In `ApiClient`, if `kIsWeb`, set `dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true)`.

**Step 4: Run test to verify it passes**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/api_client_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
cd /Users/aay/自有项目/solara_flutter
git add lib/services/app_config.dart lib/data/api/api_client.dart pubspec.yaml test/api_client_test.dart
git commit -m "feat: set cf base url and credentialed requests"
```

---

### Task 2: Add remote storage models and merge logic

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/services/remote_state_models.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/remote_state_models_test.dart`

**Step 1: Write the failing test**

Create tests for:
- parsing a snapshot from JSON
- merging local vs remote by `updatedAt`

**Step 2: Run test to verify it fails**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/remote_state_models_test.dart`
Expected: FAIL (classes not found).

**Step 3: Implement minimal code**

Create:
- `RemoteStateSection` (updatedAt + payload)
- `RemoteStateSnapshot` (version, updatedAt, queue, favorites, settings)
- `mergeWith` method that keeps newest section by timestamp

**Step 4: Run test to verify it passes**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/remote_state_models_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
cd /Users/aay/自有项目/solara_flutter
git add lib/services/remote_state_models.dart test/remote_state_models_test.dart
git commit -m "feat: add remote state models and merge logic"
```

---

### Task 3: Implement RemoteStorageService (Cloudflare D1)

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/services/remote_storage_service.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/remote_storage_service_test.dart`

**Step 1: Write the failing test**

Test that the service:
- builds a GET to `/api/storage?keys=solara_state`
- encodes a POST body `{ data: { solara_state: <snapshot> } }`
- handles `d1Available: false` by returning null

**Step 2: Run test to verify it fails**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/remote_storage_service_test.dart`
Expected: FAIL.

**Step 3: Implement minimal code**

- `fetchState()` → GET keys
- `saveState(snapshot)` → POST data
- `deleteState()` → DELETE keys

Use `ApiClient.dio` and parse JSON into `RemoteStateSnapshot`.

**Step 4: Run test to verify it passes**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/remote_storage_service_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
cd /Users/aay/自有项目/solara_flutter
git add lib/services/remote_storage_service.dart test/remote_storage_service_test.dart
git commit -m "feat: add remote storage service"
```

---

### Task 4: Add SyncController (local-first + background sync)

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/services/sync_controller.dart`
- Modify: `/Users/aay/自有项目/solara_flutter/lib/services/persistent_state_service.dart`
- Modify: `/Users/aay/自有项目/solara_flutter/lib/services/providers.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/storage_sync_test.dart`

**Step 1: Write the failing test**

Test flow:
- local state exists
- remote state exists (newer)
- `SyncController.initialize()` merges and writes local with remote
- local changes enqueue a background save

**Step 2: Run test to verify it fails**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/storage_sync_test.dart`
Expected: FAIL.

**Step 3: Implement minimal code**

- `SyncController.initialize()`
- Debounced `scheduleSync()` for queue/favorites/settings
- `PersistentStateService` calls `syncController.scheduleSync()` on save
- Provide `syncControllerProvider`

**Step 4: Run test to verify it passes**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/storage_sync_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
cd /Users/aay/自有项目/solara_flutter
git add lib/services/sync_controller.dart lib/services/persistent_state_service.dart lib/services/providers.dart test/storage_sync_test.dart
git commit -m "feat: add local-first storage sync"
```

---

### Task 5: Wire sync initialization in app lifecycle

**Files:**
- Modify: `/Users/aay/自有项目/solara_flutter/lib/app/app.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/login_gate_test.dart`

**Step 1: Write the failing test**

Extend `login_gate_test.dart` to assert that `SyncController.initialize()` is triggered after auth success.

**Step 2: Run test to verify it fails**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/login_gate_test.dart`
Expected: FAIL.

**Step 3: Implement minimal code**

- After auth success, trigger sync initialization once (guarded).

**Step 4: Run test to verify it passes**

Run: `cd /Users/aay/自有项目/solara_flutter && flutter test test/login_gate_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
cd /Users/aay/自有项目/solara_flutter
git add lib/app/app.dart test/login_gate_test.dart
git commit -m "feat: initialize storage sync after login"
```

---

### Task 6: Docs update for CF requirements

**Files:**
- Modify: `/Users/aay/自有项目/solara_flutter/README.md`

**Step 1: Update docs**

Add a section noting:
- base URL is `https://solara.uonoe.com`
- CF headers required for cookies/CORS
- storage sync uses `/api/storage` key `solara_state`

**Step 2: Commit**

```bash
cd /Users/aay/自有项目/solara_flutter
git add README.md
git commit -m "docs: add cf base url and storage sync notes"
```

