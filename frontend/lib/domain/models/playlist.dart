import 'song.dart';

class PlaylistItem {
  final Song song;
  final int index;

  const PlaylistItem({
    required this.song,
    required this.index,
  });

  Map<String, dynamic> toJson() {
    return {
      'song': song.toJson(),
      'index': index,
    };
  }

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    return PlaylistItem(
      song: Song.fromJson(Map<String, dynamic>.from(json['song'] as Map)),
      index: json['index'] is int ? json['index'] as int : int.tryParse(json['index']?.toString() ?? '') ?? 0,
    );
  }
}
