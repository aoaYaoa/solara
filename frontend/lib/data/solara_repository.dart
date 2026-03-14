import 'package:dio/dio.dart';
import '../domain/models/discover.dart';
import '../domain/models/song.dart';
import 'api/solara_api.dart';
import '../services/debug_log_bus.dart';

class AuthRequiredException implements Exception {
  @override
  String toString() => 'Auth required';
}

class SolaraRepository {
  final SolaraApi api;
  final Dio dio;

  SolaraRepository({required this.api, required this.dio});

  Uri _resolve(Uri relative) {
    return Uri.parse(dio.options.baseUrl).resolveUri(relative);
  }

  void _ensureAuthed(Response response) {
    final status = response.statusCode ?? 0;
    final location = response.headers.value('location') ?? '';
    if (status == 302 ||
        status == 401 ||
        status == 403 ||
        location.contains('/login')) {
      throw AuthRequiredException();
    }
  }

  Future<List<Song>> search({
    required String keyword,
    required String source,
    int count = 20,
    int page = 1,
  }) async {
    final uri = _resolve(
      api.buildSearchUri(
        keyword: keyword,
        source: source,
        count: count,
        page: page,
      ),
    );
    DebugLogBus.add('Search: $keyword ($source) page=$page');
    final response = await dio.getUri(uri);
    _ensureAuthed(response);
    final data = response.data;
    if (data is! List) {
      throw Exception('Invalid search response');
    }
    DebugLogBus.add('Search results: ${data.length}');
    return data
        .map((item) => Song.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<String> fetchSongUrl({
    required String songId,
    required String source,
    required String quality,
  }) async {
    final uri = _resolve(
      api.buildSongUrlUri(songId: songId, source: source, quality: quality),
    );
    DebugLogBus.add('Fetch song url: $songId');
    final response = await dio.getUri(uri);
    _ensureAuthed(response);
    final data = response.data;
    DebugLogBus.add('Song url response: status=${response.statusCode} data=$data');
    // API 可能返回 {url: ...} 或 [{url: ...}] 或直接字符串
    if (data is Map && data['url'] != null) {
      return data['url'].toString();
    }
    if (data is List && data.isNotEmpty && data[0] is Map && data[0]['url'] != null) {
      return data[0]['url'].toString();
    }
    if (data is String && data.startsWith('http')) {
      return data;
    }
    throw Exception('Invalid song url response: $data');
  }

  Future<String> fetchLyric({
    required String songId,
    required String source,
  }) async {
    final uri = _resolve(api.buildLyricUri(songId: songId, source: source));
    DebugLogBus.add('Fetch lyric: $songId');
    final response = await dio.getUri(uri);
    _ensureAuthed(response);
    return response.data.toString();
  }

  /// 直接本地计算封面代理 URL，不发网络请求
  String buildPicProxyUrl({
    required String picId,
    required String source,
    int size = 300,
  }) {
    final uri = _resolve(
      api.buildPicUri(picId: picId, source: source, size: size),
    );
    return uri.toString();
  }

  Future<String> fetchPicUrl({
    required String picId,
    required String source,
    int size = 300,
  }) async {
    final uri = _resolve(
      api.buildPicUri(picId: picId, source: source, size: size),
    );
    DebugLogBus.add('Fetch pic: $picId');
    final response = await dio.getUri(uri);
    _ensureAuthed(response);
    final data = response.data;
    if (data is Map && data['url'] != null) {
      return data['url'].toString();
    }
    return uri.toString();
  }

  Future<String> fetchMvUrl({
    required String mvId,
    required String source,
  }) async {
    final uri = _resolve(api.buildMvUrlUri(mvId: mvId, source: source));
    DebugLogBus.add('Fetch mv url: $mvId');
    final response = await dio.getUri(uri);
    _ensureAuthed(response);
    final data = response.data;
    // 支持 {url:...}, {video:...}, [{url:...}], [{video:...}] 等格式
    if (data is Map) {
      final v = data['url'] ?? data['video'];
      if (v != null) return v.toString();
    }
    if (data is List && data.isNotEmpty && data[0] is Map) {
      final v = data[0]['url'] ?? data[0]['video'];
      if (v != null) return v.toString();
    }
    if (data is String && data.startsWith('http')) return data;
    throw Exception('Invalid mv url response: \$data');
  }

  Future<List<LeaderboardItem>> fetchLeaderboardList({
    required String source,
  }) async {
    final uri = _resolve(api.buildDiscoverLeaderboardListUri(source: source));
    DebugLogBus.add('Fetch leaderboard list: $source');
    final response = await dio.getUri(uri);
    _ensureAuthed(response);
    final data = response.data;
    if (data is! List) throw Exception('Invalid leaderboard list response');
    return data
        .map(
          (e) => LeaderboardItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<SongListItem>> fetchSongList({
    required String source,
    String sort = 'hot',
    String tag = '',
    int page = 1,
    int limit = 30,
  }) async {
    final uri = _resolve(
      api.buildDiscoverSongListUri(
        source: source,
        sort: sort,
        tag: tag,
        page: page,
        limit: limit,
      ),
    );
    DebugLogBus.add('Fetch song list: $source sort=$sort');
    final response = await dio.getUri(uri);
    _ensureAuthed(response);
    final data = response.data;
    if (data is! List) throw Exception('Invalid song list response');
    return data
        .map((e) => SongListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Song>> fetchLeaderboardDetail({
    required String id,
    required String source,
    int page = 1,
    int limit = 30,
  }) async {
    final uri = _resolve(
      api.buildDiscoverLeaderboardDetailUri(
        id: id,
        source: source,
        page: page,
        limit: limit,
      ),
    );
    DebugLogBus.add('Fetch leaderboard detail: $id ($source)');
    final response = await dio.getUri(uri);
    _ensureAuthed(response);
    final data = response.data;
    if (data is! List) throw Exception('Invalid leaderboard detail response');
    return data
        .map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Song>> fetchSongListDetail({
    required String id,
    required String source,
    int page = 1,
    int limit = 30,
  }) async {
    final uri = _resolve(
      api.buildDiscoverSongListDetailUri(
        id: id,
        source: source,
        page: page,
        limit: limit,
      ),
    );
    DebugLogBus.add('Fetch song list detail: $id ($source)');
    final response = await dio.getUri(uri);
    _ensureAuthed(response);
    final data = response.data;
    if (data is! List) throw Exception('Invalid song list detail response');
    return data
        .map((e) => Song.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
