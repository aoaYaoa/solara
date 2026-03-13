import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'app/app.dart';
import 'services/audio_handler.dart';

late SolaraAudioHandler audioHandler;
late AudioPlayer sharedPlayer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sharedPlayer = AudioPlayer();

  audioHandler = await AudioService.init(
    builder: () => SolaraAudioHandler(sharedPlayer),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.uonoe.solara.audio',
      androidNotificationChannelName: 'Solara',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const ProviderScope(child: SolaraApp()));
}
