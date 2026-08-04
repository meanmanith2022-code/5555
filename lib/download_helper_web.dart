import 'dart:html' as html;

Future<void> downloadDubbedVideo(String url) async {
  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  final uri = Uri.parse(url);
  final fileName = uri.pathSegments.isNotEmpty
      ? uri.pathSegments.last
      : 'dubbed_video.mp4';
  anchor.download = fileName;
  anchor.target = '_blank';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
