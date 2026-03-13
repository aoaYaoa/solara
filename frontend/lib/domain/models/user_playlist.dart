import 'song.dart';

class UserPlaylist {
  final String id;
  final String name;
  final String? description;
  final List<Song> songs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPlaylist({
    required this.id,
    required this.name,
    this.description,
    required this.songs,
    required this.createdAt,
    required this.updatedAt,
  });

  UserPlaylist copyWith({
    String? name,
    String? description,
    List<Song>? songs,
    DateTime? updatedAt,
  }) {
    return UserPlaylist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      songs: songs ?? this.songs,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    return UserPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      songs:
          (json['songs'] as List<dynamic>)
              .map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'songs': songs.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
