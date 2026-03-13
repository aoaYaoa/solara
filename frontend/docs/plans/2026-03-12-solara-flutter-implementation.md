# Solara Flutter (No Web) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild Solara as a full-featured Flutter app (Android, iOS, Windows, macOS, Linux; Web deferred) while reusing the existing Cloudflare Functions API.

**Architecture:** A new standalone Flutter project at `/Users/aay/自有项目/solara_flutter`, layered by `presentation/`, `domain/`, and `data/`, with a platform-abstracted audio engine and a thin API client compatible with Solara Functions.

**Tech Stack:** Flutter, Dart, flutter_riverpod, dio, just_audio, audio_service, palette_generator, shared_preferences, file_picker, path_provider.

---

### Task 1: Capture API contract from Solara Functions

**Files:**
- Read: `/tmp/Solara/functions/**`
- Read: `/tmp/Solara/js/index.js`
- Create: `/Users/aay/自有项目/solara_flutter/docs/plans/solara-api-notes.md`

**Step 1: Inspect Functions routes**

Run: `rg -n "export async function|onRequest|fetch" /tmp/Solara/functions -S`

Expected: List of endpoints (search, lyric, download, etc.)

**Step 2: Inspect client usage**

Run: `rg -n "API\\.|baseUrl|fetch\\(" /tmp/Solara/js/index.js -S`

Expected: Concrete endpoint paths and response shapes

**Step 3: Record API notes**

Write a short note file with endpoint paths, params, and response fields in `/Users/aay/自有项目/solara_flutter/docs/plans/solara-api-notes.md`.

**Step 4: Commit**

Run:
```bash
cd /Users/aay/自有项目/solara_flutter
git add docs/plans/solara-api-notes.md
git commit -m "docs: capture solara functions api notes"
```

---

### Task 2: Create Flutter project scaffold

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/`

**Step 1: Create project**

Run:
```bash
cd /Users/aay/自有项目
flutter create solara_flutter --platforms=android,ios,windows,macos,linux
```

Expected: Flutter project created

**Step 2: Verify baseline**

Run:
```bash
cd /Users/aay/自有项目/solara_flutter
flutter test
```

Expected: PASS

**Step 3: Commit**

Run:
```bash
cd /Users/aay/自有项目/solara_flutter
git add .
git commit -m "chore: create solara flutter project scaffold"
```

---

### Task 3: Add dependencies and base project structure

**Files:**
- Modify: `/Users/aay/自有项目/solara_flutter/pubspec.yaml`
- Create: `/Users/aay/自有项目/solara_flutter/lib/` (structure below)

**Step 1: Update dependencies**

Edit `pubspec.yaml` and add:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  dio: ^5.5.0
  just_audio: ^0.9.39
  audio_service: ^0.18.13
  palette_generator: ^0.3.3+3
  shared_preferences: ^2.2.3
  file_picker: ^8.0.7
  path_provider: ^2.1.4
  path: ^1.9.0
  collection: ^1.18.0
```

**Step 2: Create directories**

Create:
```
lib/
  app/
  data/
  domain/
  presentation/
  platform/
  services/
```

**Step 3: Run flutter pub get**

Run: `flutter pub get`

Expected: success

**Step 4: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/pubspec.yaml /Users/aay/自有项目/solara_flutter/lib
git commit -m "chore: add dependencies and base structure"
```

---

### Task 4: Define core domain models

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/domain/models/song.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/domain/models/lyric_line.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/domain/models/playlist.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/domain_models_test.dart`

**Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/domain/models/song.dart';

void main() {
  test('Song.fromJson maps fields', () {
    final song = Song.fromJson({
      'id': '1',
      'title': 'A',
      'artist': 'B',
      'coverUrl': 'C',
    });
    expect(song.id, '1');
    expect(song.title, 'A');
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/domain_models_test.dart`

Expected: FAIL (missing classes)

**Step 3: Implement models**

Implement `Song`, `LyricLine`, `PlaylistItem` with `fromJson` and `toJson`.

**Step 4: Run test to verify it passes**

Run: `flutter test test/domain_models_test.dart`

Expected: PASS

**Step 5: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/lib/domain/models /Users/aay/自有项目/solara_flutter/test/domain_models_test.dart
git commit -m "feat: add core domain models"
```

---

### Task 5: API client + Solara endpoints adapter

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/data/api/api_client.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/data/api/solara_api.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/api_client_test.dart`

**Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/data/api/api_client.dart';

void main() {
  test('ApiClient builds base url', () {
    final client = ApiClient(baseUrl: 'https://example.com');
    expect(client.baseUrl, 'https://example.com');
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/api_client_test.dart`

Expected: FAIL

**Step 3: Implement client**

Create `ApiClient` wrapper around Dio with configurable `baseUrl`.

**Step 4: Implement Solara API adapter**

Add functions aligned to Task 1 notes, e.g.:
- `searchSongs(source, keyword, page)`
- `fetchLyric(songId)`
- `fetchStreamUrl(songId, quality)`
- `downloadUrl(songId, quality)`

**Step 5: Run test to verify it passes**

Run: `flutter test test/api_client_test.dart`

Expected: PASS

**Step 6: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/lib/data/api /Users/aay/自有项目/solara_flutter/test/api_client_test.dart
git commit -m "feat: add api client and solara adapter"
```

---

### Task 6: State management for queue, favorites, settings

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/domain/state/queue_state.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/domain/state/favorites_state.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/domain/state/settings_state.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/state_test.dart`

**Step 1: Write failing tests**

Add tests for:
- Queue add/remove/clear
- Favorites toggle
- Playback mode persistence

**Step 2: Run tests to verify they fail**

Run: `flutter test test/state_test.dart`

Expected: FAIL

**Step 3: Implement state classes**

Use Riverpod `StateNotifier` with immutable states.

**Step 4: Run tests to verify they pass**

Run: `flutter test test/state_test.dart`

Expected: PASS

**Step 5: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/lib/domain/state /Users/aay/自有项目/solara_flutter/test/state_test.dart
git commit -m "feat: add queue favorites settings state"
```

---

### Task 7: Audio engine abstraction + just_audio implementation

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/platform/audio_engine.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/platform/just_audio_engine.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/audio_engine_test.dart`

**Step 1: Write failing test**

Test that `AudioEngine` exposes play/pause/seek interface.

**Step 2: Run test to verify it fails**

Run: `flutter test test/audio_engine_test.dart`

Expected: FAIL

**Step 3: Implement abstraction**

Define interface + minimal just_audio wrapper.

**Step 4: Run test to verify it passes**

Run: `flutter test test/audio_engine_test.dart`

Expected: PASS

**Step 5: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/lib/platform /Users/aay/自有项目/solara_flutter/test/audio_engine_test.dart
git commit -m "feat: add audio engine abstraction"
```

---

### Task 8: Persistence layer (shared_preferences)

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/services/storage_service.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/storage_service_test.dart`

**Step 1: Write failing test**

Test saving/loading favorites JSON.

**Step 2: Run test to verify it fails**

Run: `flutter test test/storage_service_test.dart`

Expected: FAIL

**Step 3: Implement storage service**

Use shared_preferences with JSON serialization.

**Step 4: Run test to verify it passes**

Run: `flutter test test/storage_service_test.dart`

Expected: PASS

**Step 5: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/lib/services /Users/aay/自有项目/solara_flutter/test/storage_service_test.dart
git commit -m "feat: add local storage service"
```

---

### Task 9: Presentation shell + routing + login gate

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/app/app.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/presentation/login/login_screen.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/presentation/home/home_screen.dart`
- Modify: `/Users/aay/自有项目/solara_flutter/lib/main.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/login_gate_test.dart`

**Step 1: Write failing widget test**

Test that unauthenticated user sees login screen.

**Step 2: Run test to verify it fails**

Run: `flutter test test/login_gate_test.dart`

Expected: FAIL

**Step 3: Implement app shell + login gate**

Create app routing, read password token from storage.

**Step 4: Run test to verify it passes**

Run: `flutter test test/login_gate_test.dart`

Expected: PASS

**Step 5: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/lib/app /Users/aay/自有项目/solara_flutter/lib/presentation /Users/aay/自有项目/solara_flutter/lib/main.dart /Users/aay/自有项目/solara_flutter/test/login_gate_test.dart
git commit -m "feat: add app shell and login gate"
```

---

### Task 10: Core UI modules (search, queue, player, lyric)

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/presentation/search/search_panel.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/presentation/player/player_bar.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/presentation/lyrics/lyrics_view.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/ui_smoke_test.dart`

**Step 1: Write failing widget test**

Render `HomeScreen` and ensure search bar + player bar present.

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_smoke_test.dart`

Expected: FAIL

**Step 3: Implement UI scaffolds**

Create panels with placeholder data hookup to state.

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_smoke_test.dart`

Expected: PASS

**Step 5: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/lib/presentation /Users/aay/自有项目/solara_flutter/test/ui_smoke_test.dart
git commit -m "feat: add core ui scaffolds"
```

---

### Task 11: Feature completion (downloads, explore radar, import/export)

**Files:**
- Modify: `/Users/aay/自有项目/solara_flutter/lib/presentation/home/home_screen.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/services/download_service.dart`
- Create: `/Users/aay/自有项目/solara_flutter/lib/services/import_export_service.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/feature_services_test.dart`

**Step 1: Write failing tests**

Test download URL resolution and import/export JSON shape.

**Step 2: Run test to verify it fails**

Run: `flutter test test/feature_services_test.dart`

Expected: FAIL

**Step 3: Implement services**

Use file_picker and path_provider; web uses save dialog.

**Step 4: Run test to verify it passes**

Run: `flutter test test/feature_services_test.dart`

Expected: PASS

**Step 5: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/lib/services /Users/aay/自有项目/solara_flutter/test/feature_services_test.dart
git commit -m "feat: add download and import export services"
```

---

### Task 12: Theme + palette + glassmorphism

**Files:**
- Create: `/Users/aay/自有项目/solara_flutter/lib/app/theme.dart`
- Modify: `/Users/aay/自有项目/solara_flutter/lib/presentation/home/home_screen.dart`
- Test: `/Users/aay/自有项目/solara_flutter/test/theme_test.dart`

**Step 1: Write failing test**

Verify theme returns color scheme from a fake palette.

**Step 2: Run test to verify it fails**

Run: `flutter test test/theme_test.dart`

Expected: FAIL

**Step 3: Implement theme**

Use palette_generator to extract colors from album cover.

**Step 4: Run test to verify it passes**

Run: `flutter test test/theme_test.dart`

Expected: PASS

**Step 5: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/lib/app/theme.dart /Users/aay/自有项目/solara_flutter/lib/presentation/home/home_screen.dart /Users/aay/自有项目/solara_flutter/test/theme_test.dart
git commit -m "feat: add dynamic theme and glassmorphism"
```

---

### Task 13: End-to-end integration + docs

**Files:**
- Modify: `/Users/aay/自有项目/solara_flutter/README.md`
- Test: `/Users/aay/自有项目/solara_flutter/test/e2e_flow_test.dart`

**Step 1: Write failing integration test**

Simulate search → queue → play.

**Step 2: Run test to verify it fails**

Run: `flutter test test/e2e_flow_test.dart`

Expected: FAIL

**Step 3: Implement wiring**

Connect UI to controllers and services.

**Step 4: Run test to verify it passes**

Run: `flutter test test/e2e_flow_test.dart`

Expected: PASS

**Step 5: Update README**

Add setup and run commands for each platform.

**Step 6: Commit**

Run:
```bash
git add /Users/aay/自有项目/solara_flutter/README.md /Users/aay/自有项目/solara_flutter/test/e2e_flow_test.dart
git commit -m "docs: add flutter setup and e2e test"
```
