import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../domain/models/song.dart';

class ImportExportService {
  Future<String?> exportSongs({
    required String fileName,
    required List<Song> songs,
  }) async {
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return null;

    final json = jsonEncode(songs.map((s) => s.toJson()).toList());
    final file = File(location.path);
    await file.writeAsString(json);
    return location.path;
  }

  Future<List<Song>> importSongs() async {
    const jsonGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [jsonGroup]);
    if (file == null) return [];

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((item) => Song.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
