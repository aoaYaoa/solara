import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/persistent_state_service.dart';
import '../../services/providers.dart';

class SettingsState {
  final String playbackQuality;
  final double volume;
  final String searchSource;
  final bool debugMode;
  final String themeMode; // 'system', 'light', 'dark'

  const SettingsState({
    required this.playbackQuality,
    required this.volume,
    required this.searchSource,
    required this.debugMode,
    required this.themeMode,
  });

  SettingsState copyWith({
    String? playbackQuality,
    double? volume,
    String? searchSource,
    bool? debugMode,
    String? themeMode,
  }) {
    return SettingsState(
      playbackQuality: playbackQuality ?? this.playbackQuality,
      volume: volume ?? this.volume,
      searchSource: searchSource ?? this.searchSource,
      debugMode: debugMode ?? this.debugMode,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  static SettingsState initial() {
    return const SettingsState(
      playbackQuality: '320',
      volume: 1.0,
      searchSource: 'netease',
      debugMode: false,
      themeMode: 'system',
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

  void setDebugMode(bool enabled) {
    state = state.copyWith(debugMode: enabled);
    persistence.saveSettings(state);
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    persistence.saveSettings(state);
  }
}

final settingsStateProvider = StateNotifierProvider<SettingsStateNotifier, SettingsState>(
  (ref) => SettingsStateNotifier(persistence: ref.watch(persistentStateProvider)),
);
