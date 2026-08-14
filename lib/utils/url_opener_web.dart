import 'dart:html' as html;

/// Web fallback to open a URL in a new tab/window.
Future<bool> openUrl(String raw) async {
  final r = raw.trim();
  if (r.isEmpty) return false;
  final url = (r.startsWith('http://') || r.startsWith('https://')) ? r : 'https://$r';
  try {
    html.window.open(url, '_blank');
    return true;
  } catch (_) {
    return false;
  }
}
