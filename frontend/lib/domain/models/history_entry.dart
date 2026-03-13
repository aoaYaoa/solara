import 'song.dart';

class HistoryEntry {
  final Song song;
  final DateTime playedAt;

  const HistoryEntry({required this.song, required this.playedAt});

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      song: Song.fromJson(Map<String, dynamic>.from(json['song'] as Map)),
      playedAt: DateTime.parse(json['playedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'playedAt': playedAt.toIso8601String(),
  };
}
