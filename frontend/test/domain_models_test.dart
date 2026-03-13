import 'package:flutter_test/flutter_test.dart';
import 'package:solara_flutter/domain/models/song.dart';

void main() {
  test('Song.fromJson maps fields', () {
    final song = Song.fromJson({
      'id': '1',
      'name': 'A',
      'artist': 'B',
      'album': 'C',
      'pic_id': 'P',
      'url_id': 'U',
      'lyric_id': 'L',
      'source': 'netease',
    });
    expect(song.id, '1');
    expect(song.name, 'A');
    expect(song.artist, 'B');
    expect(song.album, 'C');
    expect(song.picId, 'P');
    expect(song.urlId, 'U');
    expect(song.lyricId, 'L');
    expect(song.source, 'netease');
  });
}
