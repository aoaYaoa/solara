import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/persistent_state_service.dart';
import '../../services/providers.dart';

class SettingsState {
  final String playbackQuality;
  final double volume;
  final String searchSource;
  final String discoverSource; // 发现页独立音源
  final bool debugMode;
  final String themeMode; // 'system', 'light', 'dark'
  final String eqPreset;  // EQ preset id, default 'flat'
  final double playbackSpeed; // 播放速度，默认 1.0

  const SettingsState({
    required this.playbackQuality,
    required this.volume,
    required this.searchSource,
    this.discoverSource = 'netease',
    required this.debugMode,
    required this.themeMode,
    required this.eqPreset,
    this.playbackSpeed = 1.0,
  });

  SettingsState copyWith({
    String? playbackQuality,
    double? volume,
    String? searchSource,
    String? discoverSource,
    bool? debugMode,
    String? themeMode,
    String? eqPreset,
    double? playbackSpeed,
  }) {
    return SettingsState(
      playbackQuality: playbackQuality ?? this.playbackQuality,
      volume: volume ?? this.volume,
      searchSource: searchSource ?? this.searchSource,
      discoverSource: discoverSource ?? this.discoverSource,
      debugMode: debugMode ?? this.debugMode,
      themeMode: themeMode ?? this.themeMode,
      eqPreset: eqPreset ?? this.eqPreset,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  static SettingsState initial() {
    return const SettingsState(
      playbackQuality: '320',
      volume: 1.0,
      searchSource: 'netease',
      discoverSource: 'netease',
      debugMode: false,
      themeMode: 'system',
      eqPreset: 'flat',
      playbackSpeed: 1.0,
    );
  }
}

class SettingsStateNotifier extends StateNotifier<SettingsState> {
  final PersistentStateService persistence;

  SettingsStateNotifier({required this.persistence}) : super(SettingsState.initial()) {
    persistence.loadSettings(this);
  }

  void setPlaybackQuality(String quality) {
    state = state.copyWith(playbackQuality: quality);
    persistence.saveSettings(state);
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
    persistence.saveSettings(state);
  }

  void setSearchSource(String source) {
    state = state.copyWith(searchSource: source);
    persistence.saveSettings(state);
  }

  void setDiscoverSource(String source) {
    state = state.copyWith(discoverSource: source);
    persistence.saveSettings(state);
  }

  void setDebugMode(bool enabled) {
    state = state.copyWith(debugMode: enabled);
    persistence.saveSettings(state);
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    persistence.saveSettings(state);
  }

  void setEqPreset(String presetId) {
    state = state.copyWith(eqPreset: presetId);
    persistence.saveSettings(state);
  }

  void setPlaybackSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed.clamp(0.25, 2.0));
    persistence.saveSettings(state);
  }
}

final settingsStateProvider = StateNotifierProvider<SettingsStateNotifier, SettingsState>(
  (ref) => SettingsStateNotifier(persistence: ref.watch(persistentStateProvider)),
);
