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
    // 先立即更新封面 URL，让 UI 马上开始渲染图片，不等调色板
    state = state.copyWith(artworkUrl: url);
    // 后台异步提取调色板，完成后再更新主题色
    _extractPaletteAsync(url);
  }

  void _extractPaletteAsync(String url) {
    PaletteGenerator.fromImageProvider(
      NetworkImage(proxyImageUrl(url)),
      maximumColorCount: 12,
    ).then((palette) {
      // 如果 URL 已经切换到下一首歌，放弃旧结果
      if (state.artworkUrl != url) return;
      final color = palette.dominantColor?.color ?? palette.vibrantColor?.color ?? state.seedColor;
      state = state.copyWith(seedColor: color);
    }).catchError((_) {});
  }
}

final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => ThemeController(),
);
