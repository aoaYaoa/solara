import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'app_config.dart';

class CookieStatus {
  final bool exists;
  final int? expiry; // Unix timestamp

  const CookieStatus({required this.exists, this.expiry});

  bool get isExpired {
    if (!exists || expiry == null || expiry == 0) return false;
    return DateTime.fromMillisecondsSinceEpoch(expiry! * 1000)
        .isBefore(DateTime.now());
  }

  int? get daysUntilExpiry {
    if (!exists || expiry == null || expiry == 0) return null;
    final exp = DateTime.fromMillisecondsSinceEpoch(expiry! * 1000);
    return exp.difference(DateTime.now()).inDays;
  }

  String get label {
    if (!exists) return '未上传';
    if (expiry == null || expiry == 0) return '已上传（无过期信息）';
    final days = daysUntilExpiry!;
    if (days < 0) return '已过期';
    if (days == 0) return '今天过期';
    return '$days 天后过期';
  }
}

class CookieService {
  final Dio _dio;
  CookieService(this._dio);

  Future<Map<String, CookieStatus>> fetchStatus() async {
    final resp = await _dio.get('${AppConfig.baseUrl}/api/cookies/status');
    final data = resp.data as Map<String, dynamic>;
    return {
      'youtube': _parse(data['youtube']),
      'bilibili': _parse(data['bilibili']),
    };
  }

  Future<CookieStatus> uploadCookie(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      dialogTitle: '选择 ${type == 'youtube' ? 'YouTube' : 'B站'} Cookie 文件',
    );
    if (result == null || result.files.isEmpty) throw Exception('未选择文件');
    final path = result.files.single.path;
    if (path == null) throw Exception('无法读取文件路径');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: 'cookies.txt'),
    });
    final resp = await _dio.post(
      '${AppConfig.baseUrl}/api/cookies/upload?type=$type',
      data: formData,
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error'] ?? '上传失败');
    return CookieStatus(
      exists: true,
      expiry: (data['expiry'] as num?)?.toInt(),
    );
  }

  CookieStatus _parse(dynamic raw) {
    if (raw == null) return const CookieStatus(exists: false);
    final m = raw as Map<String, dynamic>;
    return CookieStatus(
      exists: m['exists'] == true,
      expiry: (m['expiry'] as num?)?.toInt(),
    );
  }
}
