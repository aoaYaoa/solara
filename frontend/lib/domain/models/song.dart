class Song {
  final String id;
  final String name;
  final String artist;
  final String album;
  final String picId;
  final String urlId;
  final String lyricId;
  final String source;
  final String? picUrl; // 直接图片URL（来自发现页，避免pic_id精度损失）

  const Song({
    required this.id,
    required this.name,
    required this.artist,
    required this.album,
    required this.picId,
    required this.urlId,
    required this.lyricId,
    required this.source,
    this.picUrl,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      picId: json['pic_id']?.toString() ?? '',
      urlId: json['url_id']?.toString() ?? '',
      lyricId: json['lyric_id']?.toString() ?? '',
      source: json['source']?.toString() ?? 'netease',
      picUrl: json['pic_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'album': album,
      'pic_id': picId,
      'url_id': urlId,
      'lyric_id': lyricId,
      'source': source,
      if (picUrl != null) 'pic_url': picUrl,
    };
  }
}
