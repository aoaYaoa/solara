import '../models/song.dart';
import '../models/lyric_line.dart';

class PlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final List<LyricLine> lyrics;
  final int currentLyricIndex;
  final String? artworkUrl;
  final String? error;

  const PlayerState({
    required this.currentSong,
    required this.isPlaying,
    required this.position,
    this.duration,
    required this.lyrics,
    required this.currentLyricIndex,
    required this.artworkUrl,
    required this.error,
  });

  /// [clearArtworkUrl] 为 true 时将 artworkUrl 重置为 null（因为 String? 的 copyWith 无法通过传 null 来清除）
  PlayerState copyWith({
    Song? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<LyricLine>? lyrics,
    int? currentLyricIndex,
    String? artworkUrl,
    bool clearArtworkUrl = false,
    String? error,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      lyrics: lyrics ?? this.lyrics,
      currentLyricIndex: currentLyricIndex ?? this.currentLyricIndex,
      artworkUrl: clearArtworkUrl ? null : (artworkUrl ?? this.artworkUrl),
      error: error,
    );
  }

  static PlayerState initial() {
    return const PlayerState(
      currentSong: null,
      isPlaying: false,
      position: Duration.zero,
      duration: null,
      lyrics: [],
      currentLyricIndex: -1,
      artworkUrl: null,
      error: null,
    );
  }
}
