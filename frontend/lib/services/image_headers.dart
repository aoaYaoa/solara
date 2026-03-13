import 'app_config.dart';

/// Rewrites CDN image URLs to go through the backend imgproxy endpoint,
/// which injects the correct Referer header server-side.
/// Returns the original URL unchanged if it doesn't need proxying.
String proxyImageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host;
  if (host.endsWith('.music.126.net') ||
      host.endsWith('.163.com') ||
      host.endsWith('.qq.com')) {
    return '${AppConfig.baseUrl}/imgproxy?url=${Uri.encodeComponent(url)}';
  }
  return url;
}
