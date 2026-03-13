import 'api_client.dart';

class SolaraApi {
  final ApiClient client;

  SolaraApi({required this.client});

  String _signature() {
    final first = DateTime.now().microsecondsSinceEpoch.toString();
    final second = DateTime.now().millisecondsSinceEpoch.toString();
    return '$first$second';
  }

  Uri _buildProxyUri(Map<String, String> params) {
    final all = Map<String, String>.from(params);
    all['s'] = _signature();
    return Uri(path: '/proxy', queryParameters: all);
  }

  Uri buildSearchUri({
    required String keyword,
    required String source,
    required int count,
    required int page,
  }) {
    return _buildProxyUri({
      'types': 'search',
      'source': source,
      'name': keyword,
      'count': count.toString(),
      'pages': page.toString(),
    });
  }

  Uri buildSongUrlUri({
    required String songId,
    required String source,
    required String quality,
  }) {
    return _buildProxyUri({
      'types': 'url',
      'id': songId,
      'source': source,
      'br': quality,
    });
  }

  Uri buildLyricUri({required String songId, required String source}) {
    return _buildProxyUri({'types': 'lyric', 'id': songId, 'source': source});
  }

  Uri buildPicUri({
    required String picId,
    required String source,
    int size = 300,
  }) {
    return _buildProxyUri({
      'types': 'pic',
      'id': picId,
      'source': source,
      'size': size.toString(),
    });
  }

  Uri buildPlaylistUri({
    required String playlistId,
    int limit = 50,
    int offset = 0,
  }) {
    return _buildProxyUri({
      'types': 'playlist',
      'id': playlistId,
      'limit': limit.toString(),
      'offset': offset.toString(),
    });
  }

  Uri buildDiscoverLeaderboardListUri({required String source}) {
    return Uri(
      path: '/api/discover/leaderboard',
      queryParameters: {'source': source},
    );
  }

  Uri buildDiscoverLeaderboardDetailUri({
    required String id,
    required String source,
    int page = 1,
    int limit = 30,
  }) {
    return Uri(
      path: '/api/discover/leaderboard/$id',
      queryParameters: {
        'source': source,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
  }

  Uri buildDiscoverSongListUri({
    required String source,
    String sort = 'hot',
    String tag = '',
    int page = 1,
    int limit = 30,
  }) {
    final params = <String, String>{
      'source': source,
      'sort': sort,
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (tag.isNotEmpty) params['tag'] = tag;
    return Uri(path: '/api/discover/songlist', queryParameters: params);
  }

  Uri buildDiscoverSongListDetailUri({
    required String id,
    required String source,
    int page = 1,
    int limit = 30,
  }) {
    return Uri(
      path: '/api/discover/songlist/$id',
      queryParameters: {
        'source': source,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
  }
}
