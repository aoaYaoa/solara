import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'app/app.dart';
import 'services/audio_handler.dart';

late SolaraAudioHandler audioHandler;
late AudioPlayer sharedPlayer;
AndroidEqualizer? sharedEqualizer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 捕获 Flutter 框架错误（如 build 阶段异常），防止 release 模式直接崩溃
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  // 捕获所有未处理的异步异常
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Unhandled] $error\n$stack');
    return true; // 已处理，不再传播到引擎层
  };

  AndroidEqualizer? androidEq;
  if (Platform.isAndroid) {
    androidEq = AndroidEqualizer();
    sharedEqualizer = androidEq;
  }

  // 限制图片缓存，防止 iOS 内存压力导致闪退
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
  PaintingBinding.instance.imageCache.maximumSize = 200; // 最多 200 张

  sharedPlayer = AudioPlayer(
    audioPipeline: androidEq != null
        ? AudioPipeline(androidAudioEffects: [androidEq])
        : null,
  );

  audioHandler = await AudioService.init(
    builder: () => SolaraAudioHandler(sharedPlayer),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.uonoe.solara.audio',
      androidNotificationChannelName: 'Solara',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      // macOS 媒体控制支持
      preloadArtwork: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
      fastForwardInterval: const Duration(seconds: 10),
      rewindInterval: const Duration(seconds: 10),
    ),
  );

  runApp(const ProviderScope(child: SolaraApp()));
}
