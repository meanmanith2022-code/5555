import 'package:flutter_test/flutter_test.dart';
import 'package:meanney_ai_video_voice_dubber/api_service.dart';

void main() {
  test('uses the configured remote backend by default', () {
    expect(
      ApiService.defaultBaseUrl,
      'https://meanney-ai-video-voice-dubber.onrender.com',
    );
  });

  test('parses the backend video response payload', () {
    final parsed = ApiService.parseGenerateDubResponse(
      '{"video_url":"/outputs/example.mp4","file_size":"20.6 MB"}',
    );

    expect(parsed?['video_url'], '/outputs/example.mp4');
    expect(parsed?['file_size'], '20.6 MB');
  });
}
