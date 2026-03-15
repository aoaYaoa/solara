import 'dart:io';
import 'package:audio_service/audio_service.dart';
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

  AndroidEqualizer? androidEq;
  if (Platform.isAndroid) {
    androidEq = AndroidEqualizer();
    sharedEqualizer = androidEq;
  }

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
