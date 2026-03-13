import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/models/song.dart';
import '../data/solara_repository.dart';

class DownloadService {
  final SolaraRepository repository;
  final Dio dio;

  DownloadService({required this.repository, required this.dio});

  Future<String?> downloadSong({
    required Song song,
    required String quality,
  }) async {
    final url = await repository.fetchSongUrl(
      songId: song.id,
      source: song.source,
      quality: quality,
    );

    final suggestedName = '${song.name}-${song.artist}-$quality.mp3';
    String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save song',
      fileName: suggestedName,
    );

    if (savePath == null) {
      final dir = await getApplicationDocumentsDirectory();
      savePath = '${dir.path}/$suggestedName';
    }

    await dio.download(url, savePath);
    return savePath;
  }
}
