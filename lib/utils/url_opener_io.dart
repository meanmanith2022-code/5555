import 'package:url_launcher/url_launcher.dart';

/// Open a URL using the platform's url_launcher implementation.
/// Returns true on success.
Future<bool> openUrl(String raw) async {
  if (raw.trim().isEmpty) return false;
  Uri? uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme.isEmpty) {
    // assume https if no scheme provided
    uri = Uri.tryParse('https://${raw.trim()}');
  }
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
