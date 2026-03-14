import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// AudioHandler that bridges audio_service (lock screen controls / background)
/// with the existing static just_audio AudioPlayer.
class SolaraAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;

  /// 由 PlayerController 注入，响应锁屏/灵动岛/控制中心切歌
  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;

  SolaraAudioHandler(this._player) {
    // Forward player state to audio_service
    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });
    _player.playerStateStream.listen((_) {
      _broadcastState();
    });
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Update the media item shown on the lock screen / notification.
  void setNowPlaying({
    required String title,
    required String artist,
    String? artworkUrl,
    Duration? duration,
  }) {
    mediaItem.add(MediaItem(
      id: title,
      title: title,
      artist: artist,
      artUri: artworkUrl != null ? Uri.tryParse(artworkUrl) : null,
      duration: duration,
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    await onSkipNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await onSkipPrevious?.call();
  }
}
