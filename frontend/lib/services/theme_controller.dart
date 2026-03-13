import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'image_headers.dart' show proxyImageUrl;

class ThemeState {
  final Color seedColor;
  final String? artworkUrl;

  const ThemeState({
    required this.seedColor,
    required this.artworkUrl,
  });

  ThemeState copyWith({
    Color? seedColor,
    String? artworkUrl,
  }) {
    return ThemeState(
      seedColor: seedColor ?? this.seedColor,
      artworkUrl: artworkUrl ?? this.artworkUrl,
    );
  }

  static ThemeState initial() {
    return const ThemeState(seedColor: Color(0xFF222222), artworkUrl: null);
  }
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController() : super(ThemeState.initial());

  Future<void> updateFromArtwork(String? url) async {
    if (url == null || url.isEmpty || url == state.artworkUrl) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(proxyImageUrl(url)),
        maximumColorCount: 12,
      );
      final color = palette.dominantColor?.color ?? palette.vibrantColor?.color ?? state.seedColor;
      state = state.copyWith(seedColor: color, artworkUrl: url);
    } catch (_) {
      state = state.copyWith(artworkUrl: url);
    }
  }
}

final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => ThemeController(),
);
