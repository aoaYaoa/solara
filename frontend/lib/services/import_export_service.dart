import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../domain/models/song.dart';

class ImportExportService {
  Future<String?> exportSongs({
    required String fileName,
    required List<Song> songs,
  }) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export',
      fileName: fileName,
    );
    if (path == null) return null;

    final json = jsonEncode(songs.map((s) => s.toJson()).toList());
    final file = File(path);
    await file.writeAsString(json);
    return path;
  }

  Future<List<Song>> importSongs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return [];

    final file = File(result.files.first.path!);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((item) => Song.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
