import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:file_saver/file_saver.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'file_io.dart' if (dart.library.html) 'file_stub.dart';
import 'settings_dialog.dart';
import 'app_theme.dart';
import 'dubbing_progress_dialog.dart';
import 'dubbing_result_screen.dart';
import 'watermark_editor_screen.dart';
import 'auto_process_settings_screen.dart';
import 'srt_subtitle_tile.dart';

class DashboardPalette {
  static bool get isLight => themeNotifier.value == ThemeMode.light;
  static Color get background =>
      isLight ? const Color(0xFFF7F5EF) : const Color(0xFF0F141C);
  static Color get surface => isLight ? Colors.white : const Color(0xFF151D2A);
  static Color get card =>
      isLight ? const Color(0xFFF0F3F8) : const Color(0xFF1E2638);
  static Color get field => isLight ? Colors.white : const Color(0xFF1A2130);
  static Color get border => isLight ? const Color(0xFFD8DEE9) : Colors.white12;
  static Color get text => isLight ? const Color(0xFF182234) : Colors.white;
  static Color get muted => isLight ? const Color(0xFF667085) : Colors.white54;
  static Color get mutedStrong =>
      isLight ? const Color(0xFF475467) : Colors.white70;
}

class LightDashboardHome extends StatefulWidget {
  const LightDashboardHome({super.key});

  @override
  State<LightDashboardHome> createState() => _LightDashboardHomeState();
}

class _LightDashboardHomeState extends State<LightDashboardHome> {
  // --- Variables ---
  String _selectedVideoName = "មិនទាន់មានវីដេអូជ្រើសរើសទេ";
  String _selectedSrtName = "មិនទាន់មានឯកសារ SRT ទេ";
  final String _selectedAssistantModel = 'Gemini 3.6 Flash';
  final List<String> _assistantModels = [
    'Gemini 3.6 Flash',
    'Gemini 3.6 Pro',
    'Gemini 3.6 Nano',
  ];
  double _speed = 1.2;
  double _pitch = 0.0;
  final bool _isDucking = true;
  double _originalVoice = 15.0;
  double _dubbedVoice = 100.0;
  bool _removeBackgroundNoise = true;
  Duration _videoPosition = Duration.zero;
  final bool _isSeeking = false;
  String _selectedSpeaker = 'Auto'; // 'Auto', 'Sreymom', 'Piseth', 'Clone'
  bool _isGenerating = false;
  bool _isCancelled = false;
  String _generatedVideoUrl = '';
  Uint8List? _pickedSrtBytes;
  String _translatedSrtContent = '';
  Uint8List? _selectedAudioBytes;
  String? _selectedAudioName;
  File? _selectedAudioFile;
  bool _isCloningLoading = false;
  String _newCloneVoiceName = '';
  String _newCloneVoiceGender = 'auto';
  String _cloneVoiceOption = 'auto';
  int _cloneMode = 0; // 0 = ជ្រើសរើសសំឡេងដែលមានស្រាប់, 1 = Upload ថ្មី
  String? _selectedClonedVoiceId = 'Malyn.wav'; // សំឡេងដែលបានជ្រើសរើស

  final List<Map<String, String>> _savedClonedVoices = [
    {'id': 'Malyn.wav', 'name': 'Malyn', 'gender': 'female'},
    {'id': 'Mean.wav', 'name': 'Mean', 'gender': 'male'},
  ];

  String apiUrl = ApiService.defaultBaseUrl;
  Timer? _progressTimer;
  int currentStep = 1;
  int totalSteps = 43;
  String speaker = 'Auto';
  double progress = 0.0;

  // Example state for progress updates during translation loop:
  // final progressValue = 0; // 0 ถึง 100
  // final currentStepValue = 1;
  // final totalStepsValue = 10;
  // final speakerValue = 'female';
  // Inside the loop:
  // setState(() {
  //   progress = ((i + 1) / totalItems * 100).floorToDouble();
  //   currentStep = i + 1;
  //   totalSteps = totalItems;
  // });
  // Example segment data and loop update pattern:
  // final segments = [
  //   {'id': 1, 'speaker': 'Female'},
  //   {'id': 2, 'speaker': 'Male'},
  //   {'id': 3, 'speaker': 'Female'},
  // ];
  // final totalSegments = segments.length;
  // var currentProgress = 0;
  // var currentStepNumber = 1;
  // var currentSpeakerName = 'Female';
  // for (var i = 0; i < totalSegments; i++) {
  //   currentStepNumber = i + 1;
  //   currentSpeakerName = segments[i]['speaker'] as String;
  //   currentProgress = ((i + 1) / totalSegments * 100).round();
  //   updateUI({
  //     'progress': currentProgress,
  //     'step': currentStepNumber,
  //     'total': totalSegments,
  //     'speaker': currentSpeakerName,
  //   });
  // }
  // Example UI layout for a progress card:
  // Container(
  //   padding: const EdgeInsets.all(16),
  //   decoration: BoxDecoration(
  //     color: const Color(0xFF0F172A),
  //     borderRadius: BorderRadius.circular(12),
  //     border: Border.all(color: const Color(0xFF334155)),
  //   ),
  //   child: Column(
  //     children: [
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           const Text('កំពុងបង្កើតវីដេអូបកប្រែ...'),
  //           Text('$currentProgress%'),
  //         ],
  //       ),
  //       const SizedBox(height: 8),
  //       LinearProgressIndicator(value: currentProgress / 100),
  //       const SizedBox(height: 12),
  //       Container(
  //         padding: const EdgeInsets.all(10),
  //         decoration: BoxDecoration(
  //           color: const Color(0xFF1E293B),
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //         child: Column(
  //           children: [
  //             Text('ជំហានសំឡេង (Voice Step): $currentStepNumber / $totalSegments'),
  //             Text('អ្នកបញ្ចេញសំឡេង (Speaker): $currentSpeakerName'),
  //           ],
  //         ),
  //       ),
  //       const SizedBox(height: 10),
  //       const Text('សូមកុំចាកចេញពីកម្មវិធី រហូតដល់ដំណើរការចប់!'),
  //       const SizedBox(height: 8),
  //       OutlinedButton.icon(
  //         onPressed: () {},
  //         icon: const Icon(Icons.close),
  //         label: const Text('បោះបង់ការបង្កើត (Cancel Generation)'),
  //       ),
  //     ],
  //   ),
  // );

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  VoidCallback? _videoListener;
  String? _videoFilePath;
  Uint8List? _pickedVideoBytes;
  final AudioPlayer _soundPlayer = AudioPlayer();

  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);

  bool _isRegisteredCloneVoice(Map<String, String> voice) {
    final id = (voice['id'] ?? '').toLowerCase().trim();
    final name = (voice['name'] ?? '').toLowerCase().trim();
    return id.contains('malyn') ||
        id.contains('mean') ||
        name.contains('malyn') ||
        name.contains('mean');
  }

  List<Map<String, String>> _filterRegisteredCloneVoices(
    List<Map<String, String>> voices,
  ) {
    final filtered = voices.where(_isRegisteredCloneVoice).toList();
    if (filtered.isNotEmpty) {
      return filtered;
    }

    return [
      {'id': 'Malyn.wav', 'name': 'Malyn', 'gender': 'female'},
      {'id': 'Mean.wav', 'name': 'Mean', 'gender': 'male'},
    ];
  }

  @override
  void initState() {
    super.initState();
    ApiService.setBaseUrl(apiUrl);
    _loadCloneVoices();
  }

  Future<void> _loadCloneVoices() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/clone-voices'),
      );
      if (response.statusCode != 200) return;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final voices = payload['voices'];
      if (voices is! List || !mounted) return;

      final loaded = voices
          .whereType<Map>()
          .map(
            (voice) => voice.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          )
          .toList();

      final filteredVoices = _filterRegisteredCloneVoices(loaded);
      setState(() {
        _savedClonedVoices
          ..clear()
          ..addAll(filteredVoices);
        if (!_savedClonedVoices.any(
          (voice) => voice['id'] == _selectedClonedVoiceId,
        )) {
          _selectedClonedVoiceId = _savedClonedVoices.first['id'];
        }
      });
    } catch (_) {
      // The built-in Mean/Malyn voices remain available while offline.
    }
  }

  Future<void> _fetchDubbingStatus() async {
    if (apiUrl.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/dubbing-status'),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final status = payload['status'] ?? 'unknown';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API URL saved. Dubbing status: $status')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'API URL saved, but status check failed (${response.statusCode}).',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API URL saved, but server could not be reached.'),
        ),
      );
    }
  }

  // --- Functions ---
  void _pickVideo() {
    _pickVideoFile().then((_) => _autoTranslateAfterPick());
  }

  Future<void> _autoTranslateAfterPick() async {
    if (_selectedVideoName.contains('មិនទាន់')) return;
    _progressNotifier.value = 0.05;
    await Future.delayed(const Duration(milliseconds: 400));
    _progressNotifier.value = 0.25;
    await Future.delayed(const Duration(milliseconds: 400));
    _progressNotifier.value = 0.6;
    await Future.delayed(const Duration(milliseconds: 600));
    _progressNotifier.value = 1.0;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SRT transcription completed.')),
      );
    }
    _progressNotifier.value = 0.0;
  }

  Future<void> _editVideo() async {
    if (!_hasGeneratedVideo()) return;
    final start = TextEditingController(text: '0');
    final end = TextEditingController();
    final text = TextEditingController();
    final volume = TextEditingController(text: '1.0');
    final fadeIn = TextEditingController(text: '0');
    String crop = 'original';
    String effect = 'none';
    String rotate = '0';
    String flip = 'none';
    Uint8List? stickerBytes;
    String? stickerName;
    final editorResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit video'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: start,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Trim start (seconds)',
                  ),
                ),
                TextField(
                  controller: end,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Trim end (optional)',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: crop,
                  decoration: const InputDecoration(labelText: 'Crop'),
                  items: const [
                    DropdownMenuItem(
                      value: 'original',
                      child: Text('Original'),
                    ),
                    DropdownMenuItem(
                      value: 'square',
                      child: Text('Square 1:1'),
                    ),
                    DropdownMenuItem(
                      value: 'portrait',
                      child: Text('Portrait 9:16'),
                    ),
                    DropdownMenuItem(
                      value: 'landscape',
                      child: Text('Landscape 16:9'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => crop = value!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: rotate,
                  decoration: const InputDecoration(labelText: 'Rotate'),
                  items: const [
                    DropdownMenuItem(value: '0', child: Text('No rotation')),
                    DropdownMenuItem(value: '90', child: Text('90° clockwise')),
                    DropdownMenuItem(value: '180', child: Text('180°')),
                    DropdownMenuItem(
                      value: '270',
                      child: Text('270° clockwise'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => rotate = value!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: flip,
                  decoration: const InputDecoration(labelText: 'Flip'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(
                      value: 'horizontal',
                      child: Text('Horizontal'),
                    ),
                    DropdownMenuItem(
                      value: 'vertical',
                      child: Text('Vertical'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => flip = value!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: effect,
                  decoration: const InputDecoration(
                    labelText: 'Effect / filter',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(
                      value: 'grayscale',
                      child: Text('Grayscale'),
                    ),
                    DropdownMenuItem(value: 'warm', child: Text('Warm')),
                    DropdownMenuItem(value: 'blur', child: Text('Blur')),
                    DropdownMenuItem(value: 'vintage', child: Text('Vintage')),
                  ],
                  onChanged: (value) => setDialogState(() => effect = value!),
                ),
                TextField(
                  controller: text,
                  decoration: const InputDecoration(
                    labelText: 'Add text (optional)',
                  ),
                ),
                TextField(
                  controller: volume,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Volume (0.0 - 2.0)',
                  ),
                ),
                TextField(
                  controller: fadeIn,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fade in (seconds)',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final file = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );
                      if (file != null && file.files.single.bytes != null) {
                        setDialogState(() {
                          stickerBytes = file.files.single.bytes;
                          stickerName = file.files.single.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      stickerName == null
                          ? 'Add image / sticker'
                          : 'Sticker: $stickerName',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'start': start.text,
                'end': end.text,
                'crop': crop,
                'rotate': rotate,
                'flip': flip,
                'effect': effect,
                'text': text.text,
                'volume': volume.text,
                'fade_in': fadeIn.text,
              }),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    start.dispose();
    end.dispose();
    text.dispose();
    volume.dispose();
    fadeIn.dispose();
    if (editorResult != null) {
      await _runEditVideo(editorResult, stickerBytes, stickerName);
    }
  }

  Future<void> _downloadMp3() async {
    final hasSelectedVideo =
        _pickedVideoBytes != null ||
        (_videoFilePath != null && _videoFilePath!.isNotEmpty);
    if (_generatedVideoUrl.isEmpty && !hasSelectedVideo) {
      _showMessage('Please select a video first.');
      return;
    }
    String bitrate = '192k';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Extract MP3'),
          content: DropdownButtonFormField<String>(
            initialValue: bitrate,
            decoration: const InputDecoration(
              labelText: 'Audio quality (bitrate)',
            ),
            items: const [
              DropdownMenuItem(value: '128k', child: Text('128 kbps')),
              DropdownMenuItem(value: '192k', child: Text('192 kbps')),
              DropdownMenuItem(value: '256k', child: Text('256 kbps')),
              DropdownMenuItem(value: '320k', child: Text('320 kbps')),
            ],
            onChanged: (value) => setDialogState(() => bitrate = value!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Extract'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    _showMessage('Extracting MP3...');
    final result = hasSelectedVideo
        ? await ApiService.extractMp3FromVideo(
            videoBytes: _pickedVideoBytes,
            videoFileName: _selectedVideoName,
            videoPath: _videoFilePath,
            bitrate: bitrate,
          )
        : await ApiService.runVideoTool(
            'extract-mp3',
            videoUrl: _generatedVideoUrl,
            options: {'bitrate': bitrate},
          );
    final audioUrl = result?['audio_url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) {
      _showToolError(result);
      return;
    }
    try {
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode != 200) throw Exception('Download failed');
      await FileSaver.instance.saveFile(
        name: 'dubbed_audio',
        bytes: response.bodyBytes,
        ext: 'mp3',
        mimeType: MimeType.other,
      );
      _showMessage('MP3 extracted and saved.');
      await _playDownloadCompleteSound();
    } catch (_) {
      _showMessage('Could not save the extracted MP3.');
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final PlatformFile file = result.files.first;
      setState(() {
        _selectedAudioName = file.name;
        _selectedAudioBytes = file.bytes;
        if (file.path != null) {
          _selectedAudioFile = File(file.path!);
        }
      });
    }
  }

  Future<void> _processVoiceCloning() async {
    if (_selectedAudioBytes == null && _selectedAudioFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('សូមជ្រើសរើស File សំឡេងជាមុនសិន!')),
        );
      }
      return;
    }

    if (_newCloneVoiceName.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('សូមបញ្ចូលឈ្មោះសំឡេងថ្មី')),
        );
      }
      return;
    }

    setState(() => _isCloningLoading = true);

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/upload-clone-voice');
      final request = http.MultipartRequest('POST', uri);
      request.fields['voice_name'] = _newCloneVoiceName.trim();
      request.fields['voice_gender'] = _newCloneVoiceGender;

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _selectedAudioBytes!,
            filename: _selectedAudioName ?? 'clone_voice.wav',
          ),
        );
      } else {
        final filePath = _selectedAudioFile?.path ?? '';
        if (filePath.isEmpty) {
          throw Exception('Local audio file path is missing');
        }
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final savedFileName = data['voice_id'] as String?;
        final voiceName = _newCloneVoiceName.trim();

        if (savedFileName == null || savedFileName.isEmpty) {
          throw Exception('Server response missing voice_id');
        }

        final updatedVoices = _filterRegisteredCloneVoices([
          ..._savedClonedVoices,
          {
            'id': savedFileName,
            'name': voiceName,
            'gender': data['gender']?.toString() ?? _newCloneVoiceGender,
          },
        ]);

        setState(() {
          _savedClonedVoices
            ..clear()
            ..addAll(updatedVoices);
          _selectedClonedVoiceId = _savedClonedVoices.first['id'];
          _cloneMode = 0;
          _newCloneVoiceName = '';
          _selectedAudioName = null;
          _selectedAudioBytes = null;
          _selectedAudioFile = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'សំឡេង "$voiceName" ត្រូវបានបង្កើត​និងរក្សាទុក ដោយជោគជ័យ!',
              ),
            ),
          );
        }
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('មានបញ្ហា៖ $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCloningLoading = false;
        });
      }
    }
  }

  Future<void> _importSrt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt'],
    );
    if (result == null) return;
    final xFile = result.files.single.xFile;
    final bytes = await xFile.readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    setState(() {
      _selectedSrtName = xFile.name;
      _pickedSrtBytes = bytes;
      _translatedSrtContent = content;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SRT imported')));
    }
  }

  Future<void> _convertDocument() async {
    final hasSelectedVideo =
        _pickedVideoBytes != null ||
        (_videoFilePath != null && _videoFilePath!.isNotEmpty);
    if (!hasSelectedVideo) {
      _showMessage('សូមជ្រើសរើសវីដេអូ ឬ សំឡេង មុនពេលបំលែង។');
      return;
    }

    _showMessage(
      'Converting document from $_selectedVideoName using $_selectedAssistantModel...',
    );
    final result = await ApiService.convertDocument(
      videoBytes: _pickedVideoBytes,
      videoFileName: _selectedVideoName,
      videoPath: _videoFilePath,
      assistantModel: _selectedAssistantModel,
    );

    if (result == null || result['srt_url'] == null) {
      _showToolError(result);
      return;
    }

    final srtUrl = result['srt_url'] as String;
    _showMessage('Khmer SRT generated. Download ready.');
    try {
      final response = await http.get(Uri.parse(srtUrl));
      if (response.statusCode != 200) throw Exception('Download failed');
      await FileSaver.instance.saveFile(
        name: 'khmer_subtitles',
        bytes: response.bodyBytes,
        ext: 'srt',
        mimeType: MimeType.other,
      );
      _showMessage('Khmer SRT subtitles downloaded.');
      await _playDownloadCompleteSound();
    } catch (e) {
      _showMessage('Could not download generated SRT: $e');
    }
  }

  Future<void> _translateDocument() async {
    if (_pickedSrtBytes == null ||
        _selectedSrtName == 'មិនទាន់មានឯកសារ SRT ទេ') {
      _showMessage('សូមជ្រើសរើសឯកសារ SRT មុនពេលបកប្រែ។');
      return;
    }

    _showMessage(
      'Translating $_selectedSrtName using $_selectedAssistantModel...',
    );
    final result = await ApiService.translateSrt(
      srtBytes: _pickedSrtBytes,
      srtFileName: _selectedSrtName,
      assistantModel: _selectedAssistantModel,
    );

    if (result == null || result['srt_url'] == null) {
      _showToolError(result);
      return;
    }

    final srtUrl = result['srt_url'] as String;
    try {
      final response = await http.get(Uri.parse(srtUrl));
      if (response.statusCode != 200) throw Exception('Download failed');
      await FileSaver.instance.saveFile(
        name: 'translated_subtitles',
        bytes: response.bodyBytes,
        ext: 'srt',
        mimeType: MimeType.other,
      );
      _showMessage('Translated Khmer SRT downloaded.');
      await _playDownloadCompleteSound();
    } catch (e) {
      _showMessage('Could not download translated SRT: $e');
    }
  }

  Future<void> _openAutoProcessSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AutoProcessSettingsScreen(),
      ),
    );
  }

  Future<void> _launchAIStudioApp() async {
    final Uri url = Uri.parse(
      'https://aistudio.google.com/apps/5ffb7163-9565-40e5-bf25-adafe12c6836?fullscreenApplet=true&showPreview=true&showAssistant=true',
    );

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open AI Studio app.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open AI Studio app.')),
        );
      }
    }
  }

  Future<void> _startAutoProcess() async {
    if (_videoFilePath == null && _pickedVideoBytes == null) {
      _showMessage('សូមជ្រើសរើសវីដេអូសិន មុនចាប់ផ្តើម Auto Process។');
      return;
    }

    _showMessage('Starting auto process...');

    final result = await ApiService.autoProcessVideo(
      videoBytes: _pickedVideoBytes,
      videoPath: _videoFilePath,
      sourceLang: null,
      voiceOption: _selectedSpeaker.toLowerCase(),
    );

    if (result == null || result['video_url'] == null) {
      _showToolError(result);
      return;
    }

    final videoUrl = result['video_url'] as String;
    await _refreshGeneratedPreview(videoUrl);
    _showMessage('Auto process completed.');
  }

  Future<void> _watermarkAndBlur() async {
    final hasSelectedVideo =
        _pickedVideoBytes != null ||
        (_videoFilePath != null && _videoFilePath!.isNotEmpty);
    if (_generatedVideoUrl.isEmpty && !hasSelectedVideo) {
      _showMessage('Please select a video first.');
      return;
    }
    final controller = TextEditingController(text: 'MeanNey AI');
    final size = TextEditingController(text: '1');
    final opacity = TextEditingController(text: '70');
    final start = TextEditingController(text: '0');
    final end = TextEditingController();
    String position = 'bottom-right';
    bool useLogoImage = false;
    String selectedAction = 'Logo';
    Uint8List? logoBytes;
    String? logoName;
    final options = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final previewText = controller.text.trim().isEmpty
              ? 'MeanNey AI'
              : controller.text.trim();
          final previewSize = (double.tryParse(size.text) ?? 1.0).clamp(
            0.3,
            3.0,
          );
          final previewOpacity =
              ((double.tryParse(opacity.text) ?? 70.0).clamp(0.0, 100.0) /
                      100.0)
                  .clamp(0.0, 1.0);
          final previewStart = int.tryParse(start.text);
          final previewEnd = int.tryParse(end.text);

          Alignment previewAlignment;
          switch (position) {
            case 'top':
              previewAlignment = Alignment.topCenter;
              break;
            case 'bottom':
              previewAlignment = Alignment.bottomCenter;
              break;
            case 'left':
              previewAlignment = Alignment.centerLeft;
              break;
            case 'right':
              previewAlignment = Alignment.centerRight;
              break;
            case 'top-left':
              previewAlignment = Alignment.topLeft;
              break;
            case 'top-right':
              previewAlignment = Alignment.topRight;
              break;
            case 'bottom-left':
              previewAlignment = Alignment.bottomLeft;
              break;
            case 'center':
            default:
              previewAlignment = Alignment.center;
              break;
          }

          return AlertDialog(
            backgroundColor: DashboardPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              'Watermark',
              style: TextStyle(
                color: DashboardPalette.text,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: DashboardPalette.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    width: double.infinity,
                                    height: 240,
                                    color: Colors.black,
                                    child: SizedBox.expand(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (_videoController != null &&
                                              _videoController!
                                                  .value
                                                  .isInitialized)
                                            SizedBox.expand(
                                              child: AspectRatio(
                                                aspectRatio:
                                                    _videoController!
                                                            .value
                                                            .aspectRatio >
                                                        0
                                                    ? _videoController!
                                                          .value
                                                          .aspectRatio
                                                    : 16 / 9,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(0),
                                                  child: VideoPlayer(
                                                    _videoController!,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            SizedBox.expand(
                                              child: Container(
                                                color: Colors.grey.shade900,
                                                alignment: Alignment.center,
                                                child: const Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.movie_outlined,
                                                      color: Colors.white54,
                                                      size: 42,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'No preview available',
                                                      style: TextStyle(
                                                        color: Colors.white54,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          Align(
                                            alignment: previewAlignment,
                                            child: Transform.scale(
                                              scale: previewSize,
                                              child: Opacity(
                                                opacity: previewOpacity,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: DashboardPalette
                                                        .background
                                                        .withValues(alpha: 0.55),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (logoBytes != null)
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          child: Image.memory(
                                                            logoBytes!,
                                                            width: 28,
                                                            height: 28,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        )
                                                      else
                                                        Icon(
                                                          Icons
                                                              .branding_watermark,
                                                          color: DashboardPalette
                                                              .mutedStrong,
                                                          size: 18,
                                                        ),
                                                      if (previewText
                                                          .isNotEmpty) ...[
                                                        if (logoBytes != null)
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                        Text(
                                                          previewText,
                                                          style: TextStyle(
                                                            color:
                                                                DashboardPalette
                                                                    .text,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 10,
                                            right: 10,
                                            bottom: 10,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: DashboardPalette
                                                    .background
                                                    .withValues(alpha: 0.45),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    _videoController
                                                                ?.value
                                                                .isPlaying ==
                                                            true
                                                        ? Icons
                                                              .pause_circle_filled
                                                        : Icons
                                                              .play_circle_fill,
                                                    color:
                                                        DashboardPalette.text,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      _videoController !=
                                                                  null &&
                                                              _videoController!
                                                                  .value
                                                                  .isInitialized
                                                          ? '${_formatDuration(_videoController!.value.position)} / ${_formatDuration(_videoController!.value.duration)}'
                                                          : 'Preview',
                                                      style: TextStyle(
                                                        color:
                                                            DashboardPalette
                                                                .mutedStrong,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white12,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${(previewOpacity * 100).round()}%',
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildWatermarkActionButton(
                                    'Logo',
                                    Icons.image,
                                    selectedAction == 'Logo',
                                    () {
                                      setDialogState(
                                        () => selectedAction = 'Logo',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  _buildWatermarkActionButton(
                                    'Text',
                                    Icons.text_fields,
                                    selectedAction == 'Text',
                                    () {
                                      setDialogState(
                                        () => selectedAction = 'Text',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  _buildWatermarkActionButton(
                                    'Blur',
                                    Icons.blur_on,
                                    selectedAction == 'Blur',
                                    () {
                                      setDialogState(
                                        () => selectedAction = 'Blur',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  _buildWatermarkActionButton(
                                    'Video',
                                    Icons.video_label,
                                    selectedAction == 'Video',
                                    () {
                                      setDialogState(
                                        () => selectedAction = 'Video',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 14, bottom: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    position = 'bottom-right';
                                    size.text = '1';
                                    opacity.text = '70';
                                  });
                                },
                                child: Text(
                                  'Reset Position',
                                  style: TextStyle(color: Colors.blue.shade300),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: DashboardPalette.surface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_formatDuration(_videoController?.value.position ?? const Duration(seconds: 5))} / ${_formatDuration(_videoController?.value.duration ?? const Duration(seconds: 54))}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                ),
                                child: Slider(
                                  value:
                                      (_videoController
                                                  ?.value
                                                  .position
                                                  .inMilliseconds
                                                  .toDouble() ??
                                              5000)
                                          .clamp(
                                            0.0,
                                            _videoController
                                                    ?.value
                                                    .duration
                                                    .inMilliseconds
                                                    .toDouble() ??
                                                54000,
                                          ),
                                  min: 0.0,
                                  max:
                                      _videoController
                                          ?.value
                                          .duration
                                          .inMilliseconds
                                          .toDouble() ??
                                      54000,
                                  activeColor: Colors.blueAccent,
                                  inactiveColor: Colors.white24,
                                  onChanged: (value) async {
                                    if (_videoController != null &&
                                        _videoController!.value.isInitialized) {
                                      await _videoController!.seekTo(
                                        Duration(milliseconds: value.toInt()),
                                      );
                                      setDialogState(() {});
                                    }
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      if (_videoController != null &&
                                          _videoController!
                                              .value
                                              .isInitialized) {
                                        final current =
                                            _videoController!.value.position -
                                            const Duration(seconds: 5);
                                        final clamped = current < Duration.zero
                                            ? Duration.zero
                                            : current;
                                        await _videoController!.seekTo(clamped);
                                        setDialogState(() {});
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.replay_5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      shape: const CircleBorder(),
                                      fixedSize: const Size(56, 56),
                                    ),
                                    onPressed: () async {
                                      if (_videoController != null &&
                                          _videoController!
                                              .value
                                              .isInitialized) {
                                        if (_videoController!.value.isPlaying) {
                                          await _videoController!.pause();
                                        } else {
                                          await _videoController!.play();
                                        }
                                        setDialogState(() {});
                                      }
                                    },
                                    child: Icon(
                                      _videoController?.value.isPlaying == true
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.black,
                                      size: 32,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      if (_videoController != null &&
                                          _videoController!
                                              .value
                                              .isInitialized) {
                                        final current =
                                            _videoController!.value.position +
                                            const Duration(seconds: 5);
                                        final clamped =
                                            current >
                                                _videoController!.value.duration
                                            ? _videoController!.value.duration
                                            : current;
                                        await _videoController!.seekTo(clamped);
                                        setDialogState(() {});
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.forward_5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DashboardPalette.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'ប្រើរូបភាព Logo (Use Logo Image)',
                                style: TextStyle(
                                  color: DashboardPalette.text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Switch(
                              value: useLogoImage,
                              onChanged: (value) =>
                                  setDialogState(() => useLogoImage = value),
                              activeThumbColor: Colors.blueAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final file = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (file != null &&
                                file.files.single.bytes != null) {
                              setDialogState(() {
                                logoBytes = file.files.single.bytes;
                                logoName = file.files.single.name;
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.upload_file,
                            color: Colors.blueAccent,
                          ),
                          label: Text(
                            logoName == null ? 'ដាក់ Logo' : 'Logo: $logoName',
                            style: TextStyle(color: DashboardPalette.text),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.blueAccent.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildWatermarkSliderRow(
                          label: 'ភាពច្បាស់ (Clarity)',
                          value: (double.tryParse(size.text) ?? 1.0).clamp(
                            0.3,
                            3.0,
                          ),
                          min: 0.3,
                          max: 3.0,
                          unit: 'x',
                          onChanged: (newValue) => setDialogState(() {
                            size.text = newValue.toStringAsFixed(2);
                          }),
                        ),
                        const SizedBox(height: 12),
                        _buildWatermarkSliderRow(
                          label: 'កម្រិតតម្លាភាព (Opacity)',
                          value: (double.tryParse(opacity.text) ?? 70.0).clamp(
                            0.0,
                            100.0,
                          ),
                          min: 0.0,
                          max: 100.0,
                          unit: '%',
                          onChanged: (newValue) => setDialogState(() {
                            opacity.text = newValue.toStringAsFixed(0);
                          }),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Position',
                          style: TextStyle(
                            color: DashboardPalette.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                'top-left',
                                'top-right',
                                'bottom-left',
                                'bottom-right',
                                'center',
                              ].map((value) {
                                final label = value == 'top-left'
                                    ? 'Top Left'
                                    : value == 'top-right'
                                    ? 'Top Right'
                                    : value == 'bottom-left'
                                    ? 'Bottom Left'
                                    : value == 'bottom-right'
                                    ? 'Bottom Right'
                                    : 'Center';
                                final selected = position == value;
                                return ChoiceChip(
                                  label: Text(
                                    label,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : DashboardPalette.text,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  selected: selected,
                                  onSelected: (_) =>
                                      setDialogState(() => position = value),
                                  selectedColor: Colors.blueAccent,
                                  backgroundColor: DashboardPalette.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.pop(context, {'no_watermark': true}),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(color: DashboardPalette.border),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('មិនដាក់ (No Watermark)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, {
                            'text': controller.text.trim(),
                            'position': position,
                            'size': size.text,
                            'opacity': opacity.text,
                            'start': start.text,
                            'end': end.text,
                          }),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('រក្សាទុក (Save & Apply)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [],
          );
        },
      ),
    );
    // The dialog route is still finishing its pop animation when showDialog
    // completes. Dispose its TextEditingControllers after that frame so its
    // TextFields never try to reattach a listener to an already disposed one.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        controller.dispose();
        size.dispose();
        opacity.dispose();
        start.dispose();
        end.dispose();
      }),
    );
    if (options == null) return;
    _showMessage('Applying watermark...');
    final result = await ApiService.watermarkVideo(
      videoUrl: _generatedVideoUrl.isEmpty ? null : _generatedVideoUrl,
      options: options,
      logoBytes: logoBytes,
      logoName: logoName,
      videoBytes: _pickedVideoBytes,
      videoFileName: _selectedVideoName,
      videoPath: _videoFilePath,
    );
    final videoUrl = result?['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
      _showToolError(result);
      return;
    }
    await _refreshGeneratedPreview(videoUrl);
    _showMessage('Watermark applied.');
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Select a clone voice id for a given SRT/video segment.
  ///
  /// [segmentData] is a map containing metadata for the segment (for example
  /// it may include a `speaker_gender` key with values like 'M' or 'F').
  /// [voiceOption] is one of: 'auto', 'male', 'female'.
  String _selectVoiceForSegment(
    Map<String, dynamic> segmentData,
    String voiceOption,
  ) {
    // 1. If user explicitly selected male
    if (voiceOption.toLowerCase() == 'male') return 'Mean';

    // 2. If user explicitly selected female
    if (voiceOption.toLowerCase() == 'female') return 'Malyn';

    // 3. Auto-detect based on segment metadata
    if (voiceOption.toLowerCase() == 'auto') {
      final dynamic g =
          segmentData['speaker_gender'] ?? segmentData['gender'] ?? 'M';
      final gender = g?.toString() ?? 'M';
      if (gender.toUpperCase() == 'F') return 'Malyn';
      return 'Mean';
    }

    // Default fallback
    return 'Mean';
  }

  bool _hasGeneratedVideo() {
    if (_generatedVideoUrl.isNotEmpty) return true;
    _showMessage('Generate a video first.');
    return false;
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showToolError(Map<String, dynamic>? result) => _showMessage(
        result?['error']?.toString() ??
            result?['message']?.toString() ??
            'Video processing failed.',
      );

  Future<void> _playDownloadCompleteSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('settings_download_sound') ?? true;
      if (enabled) {
        await _soundPlayer.play(AssetSource('sounds/welcome.mp3'));
      }
    } catch (e) {
      debugPrint('Error playing download sound: $e');
    }
  }

  Future<void> _runVideoTool(
    String action,
    Map<String, dynamic> options,
  ) async {
    _showMessage('Processing video...');
    final result = await ApiService.runVideoTool(
      action,
      videoUrl: _generatedVideoUrl,
      options: options,
    );
    final videoUrl = result?['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
      _showToolError(result);
      return;
    }
    await _refreshGeneratedPreview(videoUrl);
    _showMessage('Video updated.');
  }

  Future<void> _runEditVideo(
    Map<String, dynamic> options,
    Uint8List? stickerBytes,
    String? stickerName,
  ) async {
    _showMessage('Processing video...');
    final result = await ApiService.editVideo(
      videoUrl: _generatedVideoUrl,
      options: options,
      stickerBytes: stickerBytes,
      stickerName: stickerName,
    );
    final videoUrl = result?['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
      _showToolError(result);
      return;
    }
    await _refreshGeneratedPreview(videoUrl);
    _showMessage('Video updated.');
  }

  Future<void> _refreshGeneratedPreview(String videoUrl) async {
    setState(() => _generatedVideoUrl = videoUrl);
    await _disposeVideoController();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _videoController!.initialize();
    _videoListener = () {
      if (mounted && !_isSeeking && _videoController!.value.isInitialized) {
        setState(() => _videoPosition = _videoController!.value.position);
      }
    };
    _videoController!.addListener(_videoListener!);
    if (mounted) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          showControls: true,
          allowFullScreen: true,
          allowMuting: true,
          showControlsOnInitialize: true,
        );
      });
    }
  }

  Future<void> _saveToDevice() async {
    if (_generatedVideoUrl.isEmpty) {
      _showMessage('សូមបង្កើតវីដេអូរួចសិន មុននឹង Export។');
      return;
    }

    String format = 'mp4';
    String resolution = 'original';
    String quality = 'high';
    String fps = 'original';
    final export = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Export video'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: format,
                  decoration: const InputDecoration(labelText: 'Format'),
                  items: const [
                    DropdownMenuItem(value: 'mp4', child: Text('MP4')),
                    DropdownMenuItem(value: 'mov', child: Text('MOV')),
                    DropdownMenuItem(value: 'avi', child: Text('AVI')),
                  ],
                  onChanged: (value) => setDialogState(() => format = value!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: resolution,
                  decoration: const InputDecoration(labelText: 'Resolution'),
                  items: const [
                    DropdownMenuItem(
                      value: 'original',
                      child: Text('Original'),
                    ),
                    DropdownMenuItem(value: '720p', child: Text('720p')),
                    DropdownMenuItem(value: '1080p', child: Text('1080p')),
                    DropdownMenuItem(value: '4k', child: Text('4K')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => resolution = value!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: quality,
                  decoration: const InputDecoration(labelText: 'Quality'),
                  items: const [
                    DropdownMenuItem(
                      value: 'standard',
                      child: Text('Standard'),
                    ),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'maximum', child: Text('Maximum')),
                  ],
                  onChanged: (value) => setDialogState(() => quality = value!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: fps,
                  decoration: const InputDecoration(labelText: 'Frame rate'),
                  items: const [
                    DropdownMenuItem(
                      value: 'original',
                      child: Text('Original'),
                    ),
                    DropdownMenuItem(value: '24', child: Text('24 fps')),
                    DropdownMenuItem(value: '30', child: Text('30 fps')),
                    DropdownMenuItem(value: '60', child: Text('60 fps')),
                  ],
                  onChanged: (value) => setDialogState(() => fps = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'format': format,
                'resolution': resolution,
                'quality': quality,
                'fps': fps,
              }),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
    if (export == null) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('កំពុងទាញយក និងរក្សាទុកវីដេអូ...')),
        );
      }

      final exportResult = await ApiService.runVideoTool(
        'export',
        videoUrl: _generatedVideoUrl,
        options: export,
      );

      String? downloadUrl;
      final fileUrlRaw = exportResult?['file_url'];
      if (fileUrlRaw is String && fileUrlRaw.trim().isNotEmpty) {
        downloadUrl = fileUrlRaw.startsWith('http') ? fileUrlRaw : '${ApiService.baseUrl}$fileUrlRaw';
      } else {
        final videoUrlRaw = exportResult?['video_url'];
        if (videoUrlRaw is String && videoUrlRaw.trim().isNotEmpty) {
          downloadUrl = videoUrlRaw.startsWith('http') ? videoUrlRaw : '${ApiService.baseUrl}$videoUrlRaw';
        } else {
          downloadUrl = _generatedVideoUrl.isNotEmpty ? _generatedVideoUrl : null;
        }
      }

      if (downloadUrl == null || downloadUrl.isEmpty) {
        _showToolError(exportResult);
        return;
      }

      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        await FileSaver.instance.saveFile(
          name: 'dubbed_video',
          bytes: response.bodyBytes,
          ext: export['format']!,
          mimeType: MimeType.other,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('រក្សាទុកវីដេអូបានជោគជ័យ!')),
          );
        }
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    }
  }

  void stopProgressPolling() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void startProgressPolling(
    ValueNotifier<Map<String, dynamic>> statusNotifier,
  ) {
    stopProgressPolling();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _isCancelled) {
        stopProgressPolling();
        return;
      }

      try {
        final response = await http.get(
          Uri.parse('${ApiService.baseUrl}/api/dubbing-status'),
        );

        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);
          final data = decoded is Map<String, dynamic>
              ? decoded
              : Map<String, dynamic>.from(decoded as Map);

          if (!mounted) {
            stopProgressPolling();
            return;
          }

          setState(() {
            currentStep = (data['current_step'] as num?)?.toInt() ?? 0;
            totalSteps = (data['total_steps'] as num?)?.toInt() ?? 0;
            speaker = data['speaker'] ?? 'Auto';

            final backendPercent = (data['percent'] as num?)?.toDouble();
            progress =
                backendPercent ??
                (totalSteps > 0 ? currentStep / totalSteps : 0.0);
            progress = progress.clamp(0.0, 1.0).toDouble();
          });

          statusNotifier.value = {
            'percent': progress,
            'current_step': currentStep,
            'total_steps': totalSteps,
            'speaker': speaker,
            'status': data['status'] ?? 'processing',
            'message': data['message'] ?? '',
            'video_url': data['video_url'] ?? '',
          };

          if (progress >= 1.0 ||
              data['status'] == 'completed' ||
              data['status'] == 'error') {
            stopProgressPolling();
          }
        } else {
          statusNotifier.value = {
            'percent': progress,
            'current_step': currentStep,
            'total_steps': totalSteps,
            'speaker': speaker,
            'status': 'error',
            'message': 'HTTP ${response.statusCode}',
          };
          stopProgressPolling();
        }
      } catch (e) {
        statusNotifier.value = {
          'percent': progress,
          'current_step': currentStep,
          'total_steps': totalSteps,
          'speaker': speaker,
          'status': 'error',
          'message': e.toString(),
        };
        stopProgressPolling();
      }
    });
  }

  String _progressPreviewText() {
    for (final rawLine in _translatedSrtContent.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty ||
          RegExp(r'^\d+$').hasMatch(line) ||
          line.contains('-->')) {
        continue;
      }
      return line;
    }
    return '';
  }

  Future<void> handleGenerateDubbedVideo() async {
    if (!mounted) return;

    setState(() {
      _isGenerating = true;
      _isCancelled = false;
    });

    final dialogContext = context;
    final statusNotifier = ValueNotifier<Map<String, dynamic>>({
      'percent': 0.0,
      'current_step': 0,
      'total_steps': 1,
      'speaker': _selectedSpeaker,
      'status': 'processing',
    });

    startProgressPolling(statusNotifier);

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => DubbingProgressDialog(
        progress: 0.0,
        currentStep: 0,
        totalSteps: 0,
        speakerName: _selectedSpeaker == 'Clone'
            ? (_cloneMode == 0
                  ? 'Clone: $_selectedClonedVoiceId'
                  : 'Custom Clone Voice')
            : _selectedSpeaker,
        previewText: _progressPreviewText().isNotEmpty
            ? _progressPreviewText()
            : _translatedSrtContent.isNotEmpty
            ? _translatedSrtContent
                  .split('\n')
                  .firstWhere(
                    (line) => line.trim().isNotEmpty,
                    orElse: () => 'ការបកប្រែកំពុងដំណើរការ',
                  )
            : 'ការបកប្រែកំពុងដំណើរការ',
        statusNotifier: statusNotifier,
        onCancel: () {
          setState(() {
            _isCancelled = true;
          });
          stopProgressPolling();
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('បានបោះបង់ការបកប្រែ!')),
            );
          }
        },
        onClose: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          // TODO: add preview logic here when the generated video is ready.
        },
      ),
    );

    try {
      // 💡 កែប្រែ logic សម្រាប់ Speaker & Voice Clone
      String speakerModeToSend = _selectedSpeaker;
      String? clonedVoiceIdToSend;
      Uint8List? cloneAudioBytesToSend;
      String? cloneAudioNameToSend;
      String? cloneVoiceOptionToSend;

      if (_selectedSpeaker == 'Clone') {
        speakerModeToSend = 'clone';
        cloneVoiceOptionToSend = _cloneVoiceOption;

        if (_cloneVoiceOption == 'male') {
          clonedVoiceIdToSend = 'Mean';
        } else if (_cloneVoiceOption == 'female') {
          clonedVoiceIdToSend = 'Malyn';
        }

        if (_cloneMode == 1) {
          cloneAudioBytesToSend = _selectedAudioBytes;
          cloneAudioNameToSend = _selectedAudioName;
        }
      }

      final responseData = await ApiService.generateDubbedVideo(
        videoBytes: _pickedVideoBytes,
        videoFileName: _selectedVideoName,
        videoPath: _videoFilePath,
        srtBytes: _pickedSrtBytes,
        srtFileName: _selectedSrtName,
        srtContent: _translatedSrtContent,
        voiceGender: _selectedSpeaker == 'Piseth'
            ? 'male'
            : _selectedSpeaker == 'Clone'
            ? (_cloneVoiceOption == 'male'
                  ? 'male'
                  : _cloneVoiceOption == 'female'
                  ? 'female'
                  : 'auto')
            : 'female',
        speakerMode: speakerModeToSend,
        clonedVoiceId: clonedVoiceIdToSend,
        cloneVoiceOption: cloneVoiceOptionToSend,
        cloneAudioBytes: cloneAudioBytesToSend,
        cloneAudioName: cloneAudioNameToSend,
        originalVol: _originalVoice / 100.0,
        dubVol: _dubbedVoice / 100.0,
        addSubtitle: true,
      );

      stopProgressPolling();

      if (_isCancelled) return;
      if (!mounted) return;

      // The upload request completes immediately after the backend reaches
      // 100%.  Publish that final state briefly so the progress dialog visibly
      // finishes instead of disappearing at the last generated segment.
      final completedTotal = totalSteps > 0 ? totalSteps : currentStep;
      statusNotifier.value = {
        ...statusNotifier.value,
        'percent': 1.0,
        'current_step': completedTotal,
        'total_steps': completedTotal,
        'status': 'completed',
      };
      await Future<void>.delayed(const Duration(milliseconds: 450));

      if (_isCancelled || !mounted) return;

      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }

      if (responseData != null && responseData['video_url'] is String) {
        final videoUrl = responseData['video_url'] as String;
        if (videoUrl.isNotEmpty) {
          setState(() {
            _generatedVideoUrl = videoUrl;
          });
          await _disposeVideoController();
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(videoUrl),
          );
          await _videoController!.initialize();
          await _videoController!.setVolume(1.0);
          await _videoController!.play();

          _videoListener = () {
            if (_videoController == null) return;
            if (!_isSeeking && _videoController!.value.isInitialized) {
              if (mounted) {
                setState(
                  () => _videoPosition = _videoController!.value.position,
                );
              }
            }
          };
          _videoController!.addListener(_videoListener!);

          if (mounted) {
            setState(() {
              _chewieController = ChewieController(
                videoPlayerController: _videoController!,
                autoPlay: true,
                looping: false,
                showControls: true,
                allowFullScreen: true,
                allowMuting: true,
                showControlsOnInitialize: true,
              );
            });
          }

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DubbingResultScreen(
                  videoPath: videoUrl,
                  fileSize: responseData['file_size']?.toString() ?? '20.6 MB',
                ),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('បកប្រែ និងបញ្ចូលសំឡេងជោគជ័យ!')),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('បរាជ័យក្នុងការទទួលបាន Video URL')),
        );
      }
    } catch (e) {
      stopProgressPolling();
      if (_isCancelled) return;
      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('មានបញ្ហា៖ $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _isCancelled = false;
        });
      }
    }
  }

  Widget _buildVideoPreviewSurface({bool fullScreen = false}) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return GestureDetector(
        onTap: _pickVideo,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: fullScreen ? 360 : 220,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DashboardPalette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DashboardPalette.border, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 10),
                Text(
                  'សូមជ្រើសរើសវីដេអូ',
                  style: TextStyle(
                    color: DashboardPalette.mutedStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final videoChild = _chewieController != null
        ? Chewie(controller: _chewieController!)
        : VideoPlayer(_videoController!);

    final videoSize = _videoController!.value.size;
    final videoWidth = videoSize.width > 0 ? videoSize.width : 16.0;
    final videoHeight = videoSize.height > 0 ? videoSize.height : 9.0;
    final bool isPortrait = videoHeight >= videoWidth;
    final double displayAspectRatio = isPortrait ? 9 / 16 : 16 / 9;

    return AspectRatio(
      aspectRatio: displayAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: videoWidth,
            height: videoHeight,
            child: videoChild,
          ),
        ),
      ),
    );
  }

  Future<void> _disposeVideoController() async {
    final previousVideoController = _videoController;
    final previousChewieController = _chewieController;
    final previousListener = _videoListener;

    if (previousVideoController != null && previousListener != null) {
      try {
        previousVideoController.removeListener(previousListener);
      } catch (_) {}
    }

    // Remove the player from the widget tree before disposing it. This avoids
    // disposing a controller while VideoPlayer/Chewie still depend on it.
    if (mounted) {
      setState(() {
        _videoListener = null;
        _chewieController = null;
        _videoController = null;
        _videoPosition = Duration.zero;
      });
      await WidgetsBinding.instance.endOfFrame;
    } else {
      _videoListener = null;
      _chewieController = null;
      _videoController = null;
      _videoPosition = Duration.zero;
    }

    try {
      previousChewieController?.dispose();
    } catch (_) {}
    try {
      previousVideoController?.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    stopProgressPolling();
    _videoListener = null;
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result == null) return;
      if (!mounted) return;

      final xFile = result.files.single.xFile;
      // A freshly selected video must take precedence over an older dubbed
      // output when the user chooses Extract MP3.
      _generatedVideoUrl = '';
      _pickedVideoBytes = null;
      _videoFilePath = null;
      _selectedVideoName = xFile.name;

      await _disposeVideoController();

      if (!mounted) return;

      try {
        if (kIsWeb) {
          final bytes = await xFile.readAsBytes();
          _pickedVideoBytes = bytes;
          final base64String = base64Encode(bytes);
          final dataUrl = 'data:video/mp4;base64,$base64String';
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(dataUrl),
          );
        } else {
          final filePath = xFile.path;
          _videoFilePath = filePath;
          final nativeFile = createFile(filePath);
          _videoController = VideoPlayerController.file(nativeFile);
        }

        await _videoController!.initialize();

        _videoListener = () {
          if (_videoController == null) return;
          if (!_isSeeking && _videoController!.value.isInitialized) {
            setState(() => _videoPosition = _videoController!.value.position);
          }
        };
        _videoController!.addListener(_videoListener!);

        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          showControls: true,
          allowFullScreen: true,
          allowMuting: true,
          showControlsOnInitialize: true,
        );

        await _videoController!.setVolume(1.0);
        await _videoController!.play();

        setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initializing video: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Helper Widgets ---
  Widget _buildSpeakerCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    bool isSelected = _selectedSpeaker == id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedSpeaker = id;
        });
        final speakerLabel = switch (id) {
          'Sreymom' => 'Female (Sreymom)',
          'Piseth' => 'Male (Piseth)',
          'Auto' => 'Auto Detect Gender',
          _ => 'Clone Voice',
        };
        _showMessage('បានជ្រើសរើស $speakerLabel');
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
        decoration: BoxDecoration(
          color: isSelected ? DashboardPalette.card : DashboardPalette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.greenAccent : DashboardPalette.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isSelected
                  ? iconColor.withValues(alpha: 0.2)
                  : DashboardPalette.border.withValues(alpha: .6),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: DashboardPalette.text,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: DashboardPalette.muted, fontSize: 13, height: 1.4),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              const Icon(
                Icons.check_circle,
                color: Colors.greenAccent,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCloneOptionCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _cloneVoiceOption == value;

    return InkWell(
      onTap: () => setState(() => _cloneVoiceOption = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? DashboardPalette.card : DashboardPalette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.amber : DashboardPalette.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: isSelected
                  ? iconColor.withValues(alpha: 0.2)
                  : DashboardPalette.border.withValues(alpha: .6),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: DashboardPalette.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: DashboardPalette.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.amber, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(VoidCallback onPressed, IconData icon, String label) {
    final bool isDarkMode = themeNotifier.value == ThemeMode.dark;

    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: isDarkMode ? Colors.blueAccent : DashboardPalette.text,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDarkMode ? Colors.blueAccent : DashboardPalette.text,
          side: BorderSide(
            color: isDarkMode ? Colors.blueAccent : Colors.white,
            width: 2,
          ),
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    String unit,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: DashboardPalette.mutedStrong,
                fontSize: 12,
              ),
            ),
            Text(
              "${value.toStringAsFixed(1)}$unit",
              style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Colors.blueAccent,
            inactiveColor: DashboardPalette.border,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildWatermarkSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    final step = unit == '%' ? 1.0 : 0.05;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: DashboardPalette.mutedStrong,
                fontSize: 12,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: DashboardPalette.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${value.toStringAsFixed(value < 1 ? 2 : 0)}$unit',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: DashboardPalette.border),
                ),
                onPressed: () => onChanged((value - step).clamp(min, max)),
                child: const Icon(Icons.remove, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  activeColor: Colors.blueAccent,
                  inactiveColor: DashboardPalette.border,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: DashboardPalette.border),
                ),
                onPressed: () => onChanged((value + step).clamp(min, max)),
                child: const Icon(Icons.add, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWatermarkActionButton(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blueAccent.withValues(alpha: 0.18)
              : DashboardPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.blueAccent : DashboardPalette.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected
                  ? Colors.blueAccent
                  : DashboardPalette.mutedStrong,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.blueAccent : DashboardPalette.text,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardPalette.background,
      appBar: AppBar(
        backgroundColor: DashboardPalette.background,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/logo.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.movie, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "មានន័យ - កម្មវិធីបញ្ចូលសំឡេងវីដេអូ AI",
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.4,
                      fontWeight: FontWeight.bold,
                      color: DashboardPalette.text,
                      fontFamily: 'NotoSerifKhmer',
                    ),
                  ),
                  Text(
                    "MeanNey - AI Video Voice Dubber",
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: DashboardPalette.muted,
                      fontFamily: 'NotoSerifKhmer',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(Icons.settings, color: DashboardPalette.text),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => SettingsDialog(
                    currentApiUrl: apiUrl,
                    onSaveUrl: (value) {
                      setState(() {
                        apiUrl = value;
                        ApiService.setBaseUrl(apiUrl);
                      });
                      if (value.isNotEmpty) {
                        _fetchDubbingStatus();
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 📺 VIDEO PLAYER BOX
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: _buildVideoPreviewSurface(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: DashboardPalette.field,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: DashboardPalette.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Icon(
                    Icons.subtitles_outlined,
                    color: DashboardPalette.mutedStrong,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'រៀបចំឯកសារ (Subtitles)',
                  style: TextStyle(
                    color: DashboardPalette.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Original-video picker.  Keep it beside the SRT import flow so a
            // user can supply both source files before choosing a TTS speaker.
            Material(
              color: DashboardPalette.surface,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _pickVideo,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.video_file_outlined,
                          size: 24,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'វីដេអូដើម (Original Video)',
                              style: TextStyle(
                                color: DashboardPalette.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedVideoName == 'មិនទាន់មានវីដេអូជ្រើសរើសទេ'
                                  ? 'ចុចដើម្បីជ្រើសរើសវីដេអូដើមរបស់អ្នក'
                                  : _selectedVideoName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: DashboardPalette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: DashboardPalette.muted),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SrtSubtitleTile(
              subtitleText: _selectedSrtName == 'មិនទាន់មានឯកសារ SRT ទេ'
                  ? 'មិនទាន់បានជ្រើសរើសឯកសារ SRT នៅឡើយទេ'
                  : _selectedSrtName,
              onTap: _importSrt,
            ),
            const SizedBox(height: 12),

            // 2.5. 🛠️ ACTION BUTTONS BELOW SRT SECTION
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(_editVideo, Icons.edit, 'Edit'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        _openAutoProcessSettings,
                        Icons.auto_awesome,
                        'Transcribe',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        _downloadMp3,
                        Icons.audio_file,
                        'Extract MP3',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        _saveToDevice,
                        Icons.download,
                        'Save File',
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DashboardPalette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DashboardPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'បកប្រែ Subtitle ឬ MP3 ច្រើនព្រមគ្នា',
                          style: TextStyle(
                            color: DashboardPalette.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _launchAIStudioApp,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('បើកកម្មវិធី AI Studio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. 🎙️ SELECT TTS SPEAKER SECTION (4 CARDS)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: DashboardPalette.field,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: DashboardPalette.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Icon(
                    Icons.mic,
                    color: DashboardPalette.mutedStrong,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "កំណត់សំឡេង (Voice & Audio)",
                  style: TextStyle(
                    color: DashboardPalette.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.45,
                    fontFamily: 'NotoSerifKhmer',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildSpeakerCard(
                    id: "Auto",
                    title: "Auto",
                    subtitle: "Auto Detect",
                    icon: Icons.auto_awesome,
                    iconColor: Colors.purpleAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSpeakerCard(
                    id: "Sreymom",
                    title: "ស្រីមុំ (Sreymom)",
                    subtitle: "ស្រី (Female)",
                    icon: Icons.person,
                    iconColor: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSpeakerCard(
                    id: "Piseth",
                    title: "ពិសិដ្ឋ (Piseth)",
                    subtitle: "ប្រុស (Male)",
                    icon: Icons.person,
                    iconColor: Colors.blueAccent,
                  ),
                ),
              ],
            ),

            // ⚡ CLONE AUDIO PANEL (រៀបរយស្អាត + មានជម្រើស ២)
            if (_selectedSpeaker == "Clone") ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DashboardPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. Tab Bar / Segmented Switch រវាង "ប្រើសំឡេងដែលមាន" & "Upload ថ្មី" ---
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: DashboardPalette.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _cloneMode = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _cloneMode == 0
                                      ? Colors.amber
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    "សំឡេង Clone រួច",
                                    style: TextStyle(
                                      color: _cloneMode == 0
                                          ? Colors.black
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _cloneMode = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _cloneMode == 1
                                      ? Colors.amber
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    "Upload សំឡេងថ្មី",
                                    style: TextStyle(
                                      color: _cloneMode == 1
                                          ? Colors.black
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // --- 2. បង្ហាញ UI តាម ជម្រើសដែលបានជ្រើស (Mode 0 ឬ Mode 1) ---
                    Text(
                      "ជ្រើសរើសជម្រើសសំឡេង៖",
                      style: TextStyle(
                        color: DashboardPalette.mutedStrong,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        _buildCloneOptionCard(
                          value: 'auto',
                          title: 'Auto Detect',
                          subtitle: 'អាន SRT Subtitles / Detect male & female',
                          icon: Icons.auto_awesome,
                          iconColor: Colors.purpleAccent,
                        ),
                        const SizedBox(height: 8),
                        _buildCloneOptionCard(
                          value: 'male',
                          title: 'Mean (Male Voice)',
                          subtitle: 'Force male voice for all segments',
                          icon: Icons.male,
                          iconColor: Colors.blueAccent,
                        ),
                        const SizedBox(height: 8),
                        _buildCloneOptionCard(
                          value: 'female',
                          title: 'Malyn (Female Voice)',
                          subtitle: 'Force female voice for all segments',
                          icon: Icons.female,
                          iconColor: Colors.pinkAccent,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_cloneMode == 0) ...[
                      Text(
                        "ជ្រើសរើសសំឡេងដែលបានរក្សាទុក ៖",
                        style: TextStyle(
                          color: DashboardPalette.mutedStrong,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: DashboardPalette.field,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DashboardPalette.border),
                        ),
                        child: Text(
                          _cloneVoiceOption == 'auto'
                              ? 'Auto Detect will use subtitle gender cues'
                              : _cloneVoiceOption == 'male'
                              ? 'Mean will be used for all generated segments'
                              : 'Malyn will be used for all generated segments',
                          style: TextStyle(
                            color: DashboardPalette.muted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        "បញ្ចូល File សំឡេងគំរូថ្មីរយៈពេល 3-10 វិនាទី ៖",
                        style: TextStyle(
                          color: DashboardPalette.mutedStrong,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickAudioFile,
                            icon: const Icon(Icons.music_note, size: 14),
                            label: const Text(
                              "Pick Audio File",
                              style: TextStyle(fontSize: 13, height: 1.4),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DashboardPalette.card,
                              foregroundColor: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedAudioName ?? "មិនទាន់មាន File ជ្រើសរើស",
                              style: TextStyle(
                                color: DashboardPalette.muted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        style: TextStyle(
                          color: DashboardPalette.text,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText: "វាយឈ្មោះសំឡេង (ឧ. សំឡេងលោក A)",
                          hintStyle: TextStyle(
                            color: DashboardPalette.muted.withValues(
                              alpha: .65,
                            ),
                            fontSize: 13,
                            height: 1.4,
                          ),
                          filled: true,
                          fillColor: DashboardPalette.field,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _newCloneVoiceName = val;
                          });
                        },
                      ),

                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        initialValue: _newCloneVoiceGender,
                        decoration: InputDecoration(
                          labelText: 'ភេទសំឡេង (Voice gender)',
                          filled: true,
                          fillColor: DashboardPalette.field,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'auto',
                            child: Text('Auto Detect'),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Malyn (Female)'),
                          ),
                          DropdownMenuItem(
                            value: 'male',
                            child: Text('Mean (Male)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _newCloneVoiceGender = value);
                          }
                        },
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isCloningLoading
                              ? null
                              : _processVoiceCloning,
                          icon: _isCloningLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.auto_fix_high, size: 16),
                          label: Text(
                            _isCloningLoading
                                ? "កំពុង Upload..."
                                : "បង្កើតសំឡេង (Create Voice)",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 4. 🎛️ AUDIO & VOICE CONTROLS (SLIDERS)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DashboardPalette.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildSliderRow(
                    "ល្បឿន",
                    _speed,
                    0.5,
                    2.0,
                    "x",
                    (v) => setState(() => _speed = v),
                  ),
                  _buildSliderRow(
                    "កម្រិតសំឡេង (Pitch)",
                    _pitch,
                    -10.0,
                    10.0,
                    " Hz",
                    (v) => setState(() => _pitch = v),
                  ),
                  _buildSliderRow(
                    "សំឡេងដើម",
                    _originalVoice,
                    0.0,
                    100.0,
                    "%",
                    (v) => setState(() => _originalVoice = v),
                  ),
                  _buildSliderRow(
                    "សំឡេងបកប្រែ",
                    _dubbedVoice,
                    0.0,
                    100.0,
                    "%",
                    (v) => setState(() => _dubbedVoice = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 5. 🔊 REMOVE NOISE TOGGLE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: DashboardPalette.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "លុបសំឡេងរំខាន",
                        style: TextStyle(
                          color: DashboardPalette.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        "រក្សាទុកតែសំឡេងនិយាយ",
                        style: TextStyle(
                          color: DashboardPalette.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _removeBackgroundNoise,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (val) =>
                        setState(() => _removeBackgroundNoise = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 5.1. 🌫️ WATERMARK & BLUR SECTION
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DashboardPalette.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.blur_on,
                        color: DashboardPalette.mutedStrong,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ផ្លាកសញ្ញា (Watermark & Blur)',
                        style: TextStyle(
                          color: DashboardPalette.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.water_drop_outlined,
                        color: DashboardPalette.text,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DashboardPalette.text,
                        side: BorderSide(color: DashboardPalette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WatermarkEditorScreen(
                              videoPath: _generatedVideoUrl.isNotEmpty
                                  ? _generatedVideoUrl
                                  : _videoFilePath,
                              videoBytes: _pickedVideoBytes,
                              sourceLanguage: 'English',
                              selectedVoiceOption: _cloneVoiceOption,
                              selectedSpeaker: _selectedSpeaker,
                            ),
                          ),
                        );
                      },
                      label: Text(
                        'Watermark',
                        style: TextStyle(
                          color: DashboardPalette.text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: DashboardPalette.field,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: DashboardPalette.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Icon(
                    Icons.preview_outlined,
                    color: DashboardPalette.mutedStrong,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ចេញវីដេអូ (Preview & Export)',
                  style: TextStyle(
                    color: DashboardPalette.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 7. 🚀 MAIN GENERATE BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : handleGenerateDubbedVideo,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  _isGenerating
                      ? "កំពុងដំណើរការ..."
                      : "ចាប់ផ្តើមបកប្រែ និងបញ្ចូលសំឡេង",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
