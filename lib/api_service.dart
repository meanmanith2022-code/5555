import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String defaultBaseUrl = 'https://meanney-ai-video-voice-dubber.onrender.com/';
  static const String _desktopHost = '127.0.0.1';
  static const String _androidEmulatorHost = '10.0.2.2';
  static const String _manualHost =
      ''; // Set this to your desktop IP for real Android devices.
  static String _configuredBaseUrl = '';

  static void setBaseUrl(String? url) {
    final trimmed = (url ?? '').trim();
    if (trimmed.isEmpty) {
      _configuredBaseUrl = '';
      return;
    }
    _configuredBaseUrl = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (_manualHost.isNotEmpty) {
      return 'http://$_manualHost:5000';
    }
    if (kIsWeb) {
      // When running on the web, auto-detect: if the browser is on localhost,
      // point to the local backend; otherwise use the production Render URL.
      try {
        final hostname = Uri.base.host;
        if (hostname == 'localhost' || hostname == '127.0.0.1') {
          return 'http://localhost:5000';
        }
      } catch (_) {}
      return defaultBaseUrl;
    }
    if (Platform.isAndroid) {
      return 'http://$_androidEmulatorHost:5000';
    }
    return defaultBaseUrl;
  }

  static Map<String, dynamic>? parseGenerateDubResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      print('Unable to parse backend response: $e');
    }
    return null;
  }

  /// Fetch the list of available Kiri TTS voices from the backend.
  ///
  /// If [serverUrl] is provided, it will be used instead of the configured base URL.
  /// Example: fetchVoicesFromServer('http://127.0.0.1:5000')
  static Future<List<dynamic>> fetchVoicesFromServer([String? serverUrl]) async {
    try {
      final base = (serverUrl ?? baseUrl).trim();
      final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      final response = await http.get(
        Uri.parse('$normalizedBase/api/get-voices'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['voices'] ?? [];
      } else {
        print('Failed to load voices from $normalizedBase');
        return [];
      }
    } catch (e) {
      print('Error fetching voices: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> generateDubbedVideo({
    Uint8List? videoBytes,
    String? videoFileName,
    String? videoPath,
    Uint8List? srtBytes,
    String? srtFileName,
    String? srtContent,
    String voiceGender = 'female',
    double originalVol = 0.0,
    double dubVol = 1.0,
    bool addSubtitle = true,
    String? speakerMode,
    String? clonedVoiceId,
    String? cloneVoiceOption,
    Uint8List? cloneAudioBytes,
    String? cloneAudioName,
    String? defaultSpeaker,
  }) async {
    try {
      if (videoBytes == null && (videoPath == null || videoPath.isEmpty)) {
        print('No video payload available for upload.');
        return null;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/generate-dub'),
      );

      request.fields['voice_gender'] = voiceGender;
      request.fields['original_vol'] = originalVol.toString();
      request.fields['dub_vol'] = dubVol.toString();
      request.fields['add_subtitle'] = addSubtitle.toString();
      if (speakerMode != null) {
        request.fields['speaker_mode'] = speakerMode;
      }
      if (clonedVoiceId != null) {
        request.fields['cloned_voice_id'] = clonedVoiceId;
      }
      if (cloneVoiceOption != null) {
        request.fields['clone_voice_option'] = cloneVoiceOption;
      }
      if (srtContent != null && srtContent.trim().isNotEmpty) {
        request.fields['srt_content'] = srtContent;
      }
      if (defaultSpeaker != null) {
        request.fields['default_speaker'] = defaultSpeaker;
      }

      if (videoBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            videoBytes,
            filename: videoFileName ?? 'selected_video.mp4',
          ),
        );
      } else if (videoPath != null && videoPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('video', videoPath),
        );
      }

      if (cloneAudioBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'clone_audio',
            cloneAudioBytes,
            filename: cloneAudioName ?? 'clone_audio.wav',
          ),
        );
      }

      if (srtBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'srt',
            srtBytes,
            filename: srtFileName ?? 'subtitle.srt',
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = parseGenerateDubResponse(response.body);
        final videoUrl = data?['video_url'];
        if (videoUrl is String && videoUrl.isNotEmpty) {
          final normalizedUrl = videoUrl.startsWith('http')
              ? videoUrl
              : '$baseUrl$videoUrl';
          final responseData = Map<String, dynamic>.from(data ?? {});
          responseData['video_url'] = normalizedUrl;
          return responseData;
        }
      }

      print('API error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('Error generating video: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> runVideoTool(
    String action, {
    required String videoUrl,
    Map<String, dynamic>? options,
  }) async {
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/api/run-video-tool'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'action': action,
        'video_url': videoUrl,
        'options': options ?? {},
      });

      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        final data = parseGenerateDubResponse(response.body);
        if (data == null) {
          return null;
        }

        final normalized = Map<String, dynamic>.from(data);
        final fileUrl = normalized['file_url'];
        if (fileUrl is String && fileUrl.isNotEmpty && !fileUrl.startsWith('http')) {
          normalized['file_url'] = '$baseUrl$fileUrl';
        }

        final normalizedVideoUrl = normalized['video_url'];
        if (normalizedVideoUrl is String &&
            normalizedVideoUrl.isNotEmpty &&
            !normalizedVideoUrl.startsWith('http')) {
          normalized['video_url'] = '$baseUrl$normalizedVideoUrl';
        }

        return normalized;
      }

      final parsedError = parseGenerateDubResponse(response.body);
      if (parsedError != null) {
        return parsedError;
      }
      print('API error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('Error running video tool: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> extractMp3FromVideo({
    Uint8List? videoBytes,
    String? videoFileName,
    String? videoPath,
    String bitrate = '192k',
  }) async {
    try {
      if (videoBytes == null && (videoPath == null || videoPath.isEmpty)) {
        print('No video payload available for MP3 extraction.');
        return null;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/extract-mp3'),
      );
      request.fields['bitrate'] = bitrate;

      if (videoBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            videoBytes,
            filename: videoFileName ?? 'selected_video.mp4',
          ),
        );
      } else if (videoPath != null && videoPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('video', videoPath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return parseGenerateDubResponse(response.body);
      }
      print('API error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('Error extracting MP3: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> autoProcessVideo({
    Uint8List? videoBytes,
    String? videoFileName,
    String? videoPath,
    String? sourceLang,
    String? voiceOption,
  }) async {
    try {
      if (videoBytes == null && (videoPath == null || videoPath.isEmpty)) {
        print('No video payload available for auto-process.');
        return null;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/auto-process'),
      );

      if (sourceLang != null) request.fields['source_lang'] = sourceLang;
      if (voiceOption != null) request.fields['voice_option'] = voiceOption;

      if (videoBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            videoBytes,
            filename: videoFileName ?? 'selected_video.mp4',
          ),
        );
      } else if (videoPath != null && videoPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('video', videoPath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return parseGenerateDubResponse(response.body);
      }
      print('API error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('Error auto-processing video: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> convertDocument({
    Uint8List? videoBytes,
    String? videoFileName,
    String? videoPath,
    Uint8List? audioBytes,
    String? audioFileName,
    String? audioPath,
    String? assistantModel,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/convert-document'),
      );
      if (assistantModel != null) {
        request.fields['assistant_model'] = assistantModel;
      }

      if (videoBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            videoBytes,
            filename: videoFileName ?? 'selected_video.mp4',
          ),
        );
      } else if (videoPath != null && videoPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('video', videoPath),
        );
      } else if (audioBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            audioBytes,
            filename: audioFileName ?? 'selected_audio.wav',
          ),
        );
      } else if (audioPath != null && audioPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('audio', audioPath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return parseGenerateDubResponse(response.body);
      }
      print('API error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('Error converting document: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> translateSrt({
    Uint8List? srtBytes,
    String? srtFileName,
    String? srtContent,
    String? assistantModel,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/translate-srt'),
      );
      if (srtBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'srt',
            srtBytes,
            filename: srtFileName ?? 'subtitle.srt',
          ),
        );
      } else if (srtContent != null && srtContent.trim().isNotEmpty) {
        request.fields['srt_content'] = srtContent;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return parseGenerateDubResponse(response.body);
      }
      print('API error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('Error translating SRT: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> editVideo({
    required String videoUrl,
    required Map<String, dynamic> options,
    Uint8List? stickerBytes,
    String? stickerName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/edit-video'),
      );
      request.fields['video_url'] = videoUrl;
      request.fields['options'] = jsonEncode(options);
      if (stickerBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'sticker',
            stickerBytes,
            filename: stickerName ?? 'sticker.png',
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return parseGenerateDubResponse(response.body);
      }
      print('API error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('Error editing video: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> watermarkVideo({
    String? videoUrl,
    Map<String, dynamic>? options,
    Uint8List? logoBytes,
    String? logoName,
    Uint8List? videoBytes,
    String? videoFileName,
    String? videoPath,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/watermark-video'),
      );
      if (videoUrl != null && videoUrl.isNotEmpty) {
        request.fields['video_url'] = videoUrl;
      }
      if (options != null) {
        request.fields['options'] = jsonEncode(options);
      }
      if (logoBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'logo',
            logoBytes,
            filename: logoName ?? 'logo.png',
          ),
        );
      }
      if (videoBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            videoBytes,
            filename: videoFileName ?? 'selected_video.mp4',
          ),
        );
      } else if (videoPath != null && videoPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('video', videoPath),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return parseGenerateDubResponse(response.body);
      }
      print('API error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('Error watermarking video: $e');
    }
    return null;
  }
}
