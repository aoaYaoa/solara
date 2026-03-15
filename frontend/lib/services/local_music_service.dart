import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import '../domain/models/song.dart';

class LocalMusicService {
  /// 打开文件选择器，允许多选音频文件，返回 Song 列表
  static Future<List<Song>> pickFiles() async {
    const audioGroup = XTypeGroup(
      label: 'Audio',
      extensions: ['mp3', 'flac', 'm4a', 'aac', 'wav', 'ogg', 'opus'],
    );
    final files = await openFiles(acceptedTypeGroups: [audioGroup]);
    if (files.isEmpty) return [];

    return files.map((f) => _fileToSong(f)).toList();
  }

  static Song _fileToSong(XFile file) {
    final path = file.path;
    final filename = p.basenameWithoutExtension(file.name);

    // 尝试从文件名解析 "艺术家 - 歌名" 格式
    String name = filename;
    String artist = '';
    if (filename.contains(' - ')) {
      final parts = filename.split(' - ');
      artist = parts[0].trim();
      name = parts.sublist(1).join(' - ').trim();
    }

    return Song(
      id: path,
      name: name,
      artist: artist,
      album: '',
      picId: '',
      urlId: path,
      lyricId: '',
      source: 'local',
    );
  }
}
