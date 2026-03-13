/// 发现页数据模型

// 排行榜榜单信息
class LeaderboardItem {
  final String id;
  final String name;
  final String? coverUrl;
  final String? updateFrequency;
  final String source;

  const LeaderboardItem({
    required this.id,
    required this.name,
    this.coverUrl,
    this.updateFrequency,
    required this.source,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      id: json['id']?.toString() ?? json['bangId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? json['cover']?.toString(),
      updateFrequency: json['updateFrequency']?.toString(),
      source: json['source']?.toString() ?? 'kw',
    );
  }
}

// 歌单信息
class SongListItem {
  final String id;
  final String name;
  final String author;
  final String? coverUrl;
  final String? playCount;
  final String? description;
  final String source;

  const SongListItem({
    required this.id,
    required this.name,
    required this.author,
    this.coverUrl,
    this.playCount,
    this.description,
    required this.source,
  });

  factory SongListItem.fromJson(Map<String, dynamic> json) {
    return SongListItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      author: json['author']?.toString() ?? json['creator']?.toString() ?? '',
      coverUrl:
          json['coverUrl']?.toString() ??
          json['cover']?.toString() ??
          json['pic']?.toString(),
      playCount:
          json['playCount']?.toString() ?? json['play_count']?.toString(),
      description: json['description']?.toString() ?? json['desc']?.toString(),
      source: json['source']?.toString() ?? 'kw',
    );
  }
}
