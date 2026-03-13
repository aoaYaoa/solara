class RemoteQueueState {
  final DateTime updatedAt;
  final List<Map<String, dynamic>> songs;

  const RemoteQueueState({required this.updatedAt, required this.songs});

  factory RemoteQueueState.fromJson(Map<String, dynamic> json) {
    final rawSongs = (json['songs'] as List<dynamic>? ?? const []);
    final songs = rawSongs
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return RemoteQueueState(
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      songs: songs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'updatedAt': updatedAt.toIso8601String(),
      'songs': songs,
    };
  }
}

class RemoteFavoritesState {
  final DateTime updatedAt;
  final List<Map<String, dynamic>> songs;

  const RemoteFavoritesState({required this.updatedAt, required this.songs});

  factory RemoteFavoritesState.fromJson(Map<String, dynamic> json) {
    final rawSongs = (json['songs'] as List<dynamic>? ?? const []);
    final songs = rawSongs
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return RemoteFavoritesState(
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      songs: songs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'updatedAt': updatedAt.toIso8601String(),
      'songs': songs,
    };
  }
}

class RemoteSettingsState {
  final DateTime updatedAt;
  final Map<String, dynamic> data;

  const RemoteSettingsState({required this.updatedAt, required this.data});

  factory RemoteSettingsState.fromJson(Map<String, dynamic> json) {
    return RemoteSettingsState(
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'updatedAt': updatedAt.toIso8601String(),
      'data': data,
    };
  }
}

class RemoteStateSnapshot {
  final int version;
  final DateTime updatedAt;
  final RemoteQueueState? queue;
  final RemoteFavoritesState? favorites;
  final RemoteSettingsState? settings;

  const RemoteStateSnapshot({
    required this.version,
    required this.updatedAt,
    this.queue,
    this.favorites,
    this.settings,
  });

  factory RemoteStateSnapshot.fromJson(Map<String, dynamic> json) {
    return RemoteStateSnapshot(
      version: (json['version'] as num?)?.toInt() ?? 1,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      queue: json['queue'] == null
          ? null
          : RemoteQueueState.fromJson(Map<String, dynamic>.from(json['queue'] as Map)),
      favorites: json['favorites'] == null
          ? null
          : RemoteFavoritesState.fromJson(
              Map<String, dynamic>.from(json['favorites'] as Map),
            ),
      settings: json['settings'] == null
          ? null
          : RemoteSettingsState.fromJson(
              Map<String, dynamic>.from(json['settings'] as Map),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'updatedAt': updatedAt.toIso8601String(),
      if (queue != null) 'queue': queue!.toJson(),
      if (favorites != null) 'favorites': favorites!.toJson(),
      if (settings != null) 'settings': settings!.toJson(),
    };
  }

  RemoteStateSnapshot mergeWith(RemoteStateSnapshot other) {
    final mergedQueue = _pickNewestQueue(queue, other.queue);
    final mergedFavorites = _pickNewestFavorites(favorites, other.favorites);
    final mergedSettings = _pickNewestSettings(settings, other.settings);

    final latestTimestamp = _latestTimestamp([
      updatedAt,
      other.updatedAt,
      mergedQueue?.updatedAt,
      mergedFavorites?.updatedAt,
      mergedSettings?.updatedAt,
    ]);

    return RemoteStateSnapshot(
      version: version >= other.version ? version : other.version,
      updatedAt: latestTimestamp,
      queue: mergedQueue,
      favorites: mergedFavorites,
      settings: mergedSettings,
    );
  }

  static RemoteQueueState? _pickNewestQueue(
    RemoteQueueState? current,
    RemoteQueueState? incoming,
  ) {
    if (current == null) return incoming;
    if (incoming == null) return current;
    return incoming.updatedAt.isAfter(current.updatedAt) ? incoming : current;
  }

  static RemoteFavoritesState? _pickNewestFavorites(
    RemoteFavoritesState? current,
    RemoteFavoritesState? incoming,
  ) {
    if (current == null) return incoming;
    if (incoming == null) return current;
    return incoming.updatedAt.isAfter(current.updatedAt) ? incoming : current;
  }

  static RemoteSettingsState? _pickNewestSettings(
    RemoteSettingsState? current,
    RemoteSettingsState? incoming,
  ) {
    if (current == null) return incoming;
    if (incoming == null) return current;
    return incoming.updatedAt.isAfter(current.updatedAt) ? incoming : current;
  }

  static DateTime _latestTimestamp(List<DateTime?> candidates) {
    DateTime latest = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    for (final candidate in candidates) {
      if (candidate != null && candidate.isAfter(latest)) {
        latest = candidate;
      }
    }
    return latest;
  }
}
