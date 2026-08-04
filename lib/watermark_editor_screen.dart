import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'file_io.dart' if (dart.library.html) 'file_stub.dart';

class WatermarkEditorScreen extends StatefulWidget {
  final String? videoPath;
  final Uint8List? videoBytes;
  final String? sourceLanguage;
  final String? selectedVoiceOption;
  final String? selectedSpeaker;

  const WatermarkEditorScreen({
    super.key,
    this.videoPath,
    this.videoBytes,
    this.sourceLanguage,
    this.selectedVoiceOption,
    this.selectedSpeaker,
  });

  @override
  State<WatermarkEditorScreen> createState() => _WatermarkEditorScreenState();
}

class _WatermarkEditorScreenState extends State<WatermarkEditorScreen> {
  int selectedTabIndex = 0;

  Offset logoPosition = const Offset(50, 50);
  double logoScale = 1.0;
  String? logoPath;
  Uint8List? logoBytes;
  String? logoName;
  bool isWatermarkEnabled = true;

  final TextEditingController _textController = TextEditingController(text: 'Subtitles / Text');
  Offset textPosition = const Offset(50, 150);
  double textSize = 24.0;
  Color textColor = Colors.white;
  bool isTextEnabled = false;

  Offset blurPosition = const Offset(100, 100);
  double blurWidth = 120.0;
  double blurHeight = 60.0;
  double blurSigma = 10.0;
  bool isBlurEnabled = false;

  double videoVolume = 1.0;
  double playbackSpeed = 1.0;
  bool isMuted = false;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.videoBytes != null) {
        final dataUrl = 'data:video/mp4;base64,${base64Encode(widget.videoBytes!)}';
        _videoController = VideoPlayerController.networkUrl(Uri.parse(dataUrl));
      } else if (widget.videoPath != null && widget.videoPath!.isNotEmpty) {
        final path = widget.videoPath!;
        if (path.toLowerCase().startsWith('http') || path.toLowerCase().startsWith('data:')) {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(path));
        } else {
          _videoController = VideoPlayerController.file(createFile(path));
        }
      }

      if (_videoController == null) return;

      await _videoController!.initialize();
      if (!mounted) return;
      _videoController!.addListener(_videoListener);
      _videoController!.setLooping(false);
      await _videoController!.play();
      setState(() {
        _isVideoInitialized = true;
        _isPlaying = _videoController!.value.isPlaying;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;
    setState(() {
      _isPlaying = _videoController!.value.isPlaying;
    });
  }

  Future<void> _pickLogoFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null) return;

    final file = result.files.single;
    setState(() {
      if (file.bytes != null) {
        logoBytes = file.bytes;
        logoPath = null;
      } else if (file.path != null) {
        logoPath = file.path;
        logoBytes = null;
      }
      logoName = file.name;
      isWatermarkEnabled = true;
      selectedTabIndex = 0;
    });
  }

  String _logoFileName() {
    if (logoName != null) return 'Logo: $logoName';
    if (logoPath != null) {
      final segments = logoPath!.split(RegExp(r'[\\/]+'));
      return 'Logo: ${segments.isNotEmpty ? segments.last : logoPath}';
    }
    return 'Select Logo File';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _sendToPythonBackend({bool applyWatermark = true}) async {
    setState(() => _isProcessing = true);

    try {
      final uri = Uri.parse('http://localhost:5000/api/process-video');

      final Map<String, dynamic> payload = {
        "video_path": widget.videoPath ?? 'outputs/dubbed_output.mp4',
        "source_language": widget.sourceLanguage ?? 'English',
        "voice_option": widget.selectedVoiceOption ?? 'auto',
        "speaker_profile": widget.selectedSpeaker ?? 'Auto',
        "apply_watermark": applyWatermark,
        "logo": {
          "enabled": isWatermarkEnabled,
          "position": {"x": logoPosition.dx, "y": logoPosition.dy},
          "scale": logoScale,
          "name": logoName ?? ''
        },
        "text": {
          "enabled": isTextEnabled,
          "content": _textController.text,
          "position": {"x": textPosition.dx, "y": textPosition.dy},
          "size": textSize,
          "color": textColor.toARGB32().toRadixString(16),
        },
        "blur": {
          "enabled": isBlurEnabled,
          "position": {"x": blurPosition.dx, "y": blurPosition.dy},
          "width": blurWidth,
          "height": blurHeight,
          "sigma": blurSigma,
        },
        "video_settings": {
          "volume": isMuted ? 0.0 : videoVolume,
          "speed": playbackSpeed,
        },
        "timestamp_ms": _videoController?.value.position.inMilliseconds ?? 0,
      };

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String newVideoUrl = data['video_url'] as String? ?? widget.videoPath ?? '';

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully sent data to Python Backend!')),
        );

        Navigator.pop(context, newVideoUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mock Data Saved: Server not connected (${e.toString()})')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1E1B18) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Video Editor Studio',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double containerWidth = constraints.maxWidth;
                      final double containerHeight = containerWidth * (16 / 9);

                      return Center(
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Container(
                            width: containerWidth,
                            height: containerHeight,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDarkMode ? Colors.white24 : Colors.black12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_isVideoInitialized && _videoController != null)
                                    Positioned.fill(
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _videoController!.value.size.width,
                                          height: _videoController!.value.size.height,
                                          child: VideoPlayer(_videoController!),
                                        ),
                                      ),
                                    )
                                  else
                                    const Center(child: CircularProgressIndicator()),

                                  if (isWatermarkEnabled && selectedTabIndex == 0)
                                    _buildDraggableElement(
                                      position: logoPosition,
                                      containerWidth: containerWidth,
                                      containerHeight: containerHeight,
                                      elementWidth: 70.0 * logoScale,
                                      elementHeight: 70.0 * logoScale,
                                      onChanged: (newPos) => setState(() => logoPosition = newPos),
                                      child: Transform.scale(
                                        scale: logoScale,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.blueAccent, width: 1.5),
                                            color: Colors.black26,
                                          ),
                                          child: _buildLogoImage(),
                                        ),
                                      ),
                                    ),

                                  if (isTextEnabled && selectedTabIndex == 1)
                                    _buildDraggableElement(
                                      position: textPosition,
                                      containerWidth: containerWidth,
                                      containerHeight: containerHeight,
                                      elementWidth: 150.0,
                                      elementHeight: 40.0,
                                      onChanged: (newPos) => setState(() => textPosition = newPos),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.greenAccent, width: 1.5),
                                          color: Colors.black54,
                                        ),
                                        child: Text(
                                          _textController.text,
                                          style: TextStyle(color: textColor, fontSize: textSize),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),

                                  if (isBlurEnabled && selectedTabIndex == 2)
                                    _buildDraggableElement(
                                      position: blurPosition,
                                      containerWidth: containerWidth,
                                      containerHeight: containerHeight,
                                      elementWidth: blurWidth,
                                      elementHeight: blurHeight,
                                      onChanged: (newPos) => setState(() => blurPosition = newPos),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.orangeAccent, width: 1.5),
                                          color: Colors.white.withValues(alpha: 0.3),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'Blur Area',
                                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildMenuButton(0, Icons.image, 'Logo', isDarkMode),
                      const SizedBox(height: 8),
                      _buildMenuButton(1, Icons.title, 'Text', isDarkMode),
                      const SizedBox(height: 8),
                      _buildMenuButton(2, Icons.grid_view, 'Blur', isDarkMode),
                      const SizedBox(height: 8),
                      _buildMenuButton(3, Icons.video_settings, 'Video', isDarkMode),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    logoPosition = const Offset(50, 50);
                    logoScale = 1.0;
                    textPosition = const Offset(50, 150);
                    blurPosition = const Offset(100, 100);
                  });
                },
                icon: const Icon(Icons.refresh, color: Color(0xFF3B99F5), size: 16),
                label: const Text(
                  'Reset Positions',
                  style: TextStyle(color: Color(0xFF3B99F5), fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF262320) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_videoController != null ? _videoController!.value.position : Duration.zero),
                        style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 12),
                      ),
                      Text(
                        _formatDuration(_videoController != null ? _videoController!.value.duration : Duration.zero),
                        style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 12),
                      ),
                    ],
                  ),
                  Slider(
                    value: _videoController != null && _videoController!.value.isInitialized
                        ? _videoController!.value.position.inMilliseconds.toDouble().clamp(
                            0.0,
                            _videoController!.value.duration.inMilliseconds.toDouble() > 0
                                ? _videoController!.value.duration.inMilliseconds.toDouble()
                                : 1.0,
                          )
                        : 0.0,
                    min: 0.0,
                    max: _videoController != null && _videoController!.value.isInitialized
                        ? (_videoController!.value.duration.inMilliseconds.toDouble() > 0
                            ? _videoController!.value.duration.inMilliseconds.toDouble()
                            : 1.0)
                        : 1.0,
                    activeColor: const Color(0xFF3B99F5),
                    onChanged: (value) {
                      _videoController?.seekTo(Duration(milliseconds: value.toInt()));
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Color(0xFF3B99F5)),
                        onPressed: () {
                          if (_videoController != null) {
                            final currentPos = _videoController!.value.position;
                            final newPos = currentPos - const Duration(seconds: 10);
                            _videoController!.seekTo(newPos > Duration.zero ? newPos : Duration.zero);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5A955),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () async {
                          if (_videoController != null && _videoController!.value.isInitialized) {
                            if (_videoController!.value.isPlaying) {
                              await _videoController!.pause();
                            } else {
                              await _videoController!.play();
                            }
                          }
                        },
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Pause' : 'Play'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Color(0xFF3B99F5)),
                        onPressed: () {
                          if (_videoController != null) {
                            final currentPos = _videoController!.value.position;
                            final duration = _videoController!.value.duration;
                            final newPos = currentPos + const Duration(seconds: 10);
                            _videoController!.seekTo(newPos < duration ? newPos : duration);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF262320) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildActiveTabContent(isDarkMode),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3B99F5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isProcessing ? null : () => _sendToPythonBackend(applyWatermark: false),
                    child: const Text(
                      'No Watermark',
                      style: TextStyle(color: Color(0xFF3B99F5), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B99F5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isProcessing ? null : () => _sendToPythonBackend(applyWatermark: true),
                    child: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'Save & Apply',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(bool isDarkMode) {
    switch (selectedTabIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3B99F5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _pickLogoFile,
                    icon: const Icon(Icons.insert_drive_file, color: Color(0xFF3B99F5)),
                    label: Text(
                      _logoFileName(),
                      style: const TextStyle(color: Color(0xFF3B99F5)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: isWatermarkEnabled,
                  activeThumbColor: const Color(0xFF3B99F5),
                  onChanged: (val) => setState(() => isWatermarkEnabled = val),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Logo Size: ', style: TextStyle(fontSize: 12)),
                CircleAvatar(
                  backgroundColor: const Color(0xFFE5A955),
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.remove, color: Colors.black, size: 16),
                    onPressed: () => setState(() => logoScale = (logoScale > 0.5) ? logoScale - 0.1 : 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFE5A955),
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.black, size: 16),
                    onPressed: () => setState(() => logoScale = (logoScale < 2.5) ? logoScale + 0.1 : 2.5),
                  ),
                ),
              ],
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(labelText: 'Subtitle Text', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: isTextEnabled,
                  activeThumbColor: const Color(0xFF3B99F5),
                  onChanged: (val) => setState(() => isTextEnabled = val),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Text Size:'),
                Expanded(
                  child: Slider(
                    value: textSize,
                    min: 12,
                    max: 48,
                    onChanged: (val) => setState(() => textSize = val),
                  ),
                ),
              ],
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enable Face/Object Blur', style: TextStyle(fontWeight: FontWeight.bold)),
                Switch(
                  value: isBlurEnabled,
                  activeThumbColor: const Color(0xFF3B99F5),
                  onChanged: (val) => setState(() => isBlurEnabled = val),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Blur Intensity:'),
                Expanded(
                  child: Slider(
                    value: blurSigma,
                    min: 2,
                    max: 25,
                    onChanged: (val) => setState(() => blurSigma = val),
                  ),
                ),
              ],
            ),
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Video Audio & Playback', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Volume:'),
                Expanded(
                  child: Slider(
                    value: isMuted ? 0.0 : videoVolume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) {
                      setState(() {
                        videoVolume = val;
                        isMuted = val == 0.0;
                      });
                      _videoController?.setVolume(val);
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, color: const Color(0xFF3B99F5)),
                  onPressed: () {
                    setState(() {
                      isMuted = !isMuted;
                      _videoController?.setVolume(isMuted ? 0.0 : videoVolume);
                    });
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Speed:'),
                const SizedBox(width: 16),
                for (var speed in [0.5, 1.0, 1.5, 2.0])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('${speed}x'),
                      selected: playbackSpeed == speed,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => playbackSpeed = speed);
                          _videoController?.setPlaybackSpeed(speed);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDraggableElement({
    required Offset position,
    required double containerWidth,
    required double containerHeight,
    required double elementWidth,
    required double elementHeight,
    required ValueChanged<Offset> onChanged,
    required Widget child,
  }) {
    final maxX = (containerWidth - elementWidth).clamp(0.0, containerWidth);
    final maxY = (containerHeight - elementHeight).clamp(0.0, containerHeight);
    final safeX = position.dx.clamp(0.0, maxX);
    final safeY = position.dy.clamp(0.0, maxY);

    return Positioned(
      left: safeX,
      top: safeY,
      child: GestureDetector(
        onPanUpdate: (details) {
          final newX = (position.dx + details.delta.dx).clamp(0.0, maxX);
          final newY = (position.dy + details.delta.dy).clamp(0.0, maxY);
          onChanged(Offset(newX, newY));
        },
        child: child,
      ),
    );
  }

  Widget _buildLogoImage() {
    if (logoBytes != null) {
      return Image.memory(logoBytes!, width: 70, height: 70, fit: BoxFit.contain);
    }
    if (logoPath != null && !kIsWeb) {
      return Image.file(File(logoPath!), width: 70, height: 70, fit: BoxFit.contain);
    }
    return const Icon(Icons.image, color: Colors.blue, size: 50);
  }

  Widget _buildMenuButton(int index, IconData icon, String label, bool isDarkMode) {
    final bool isSelected = selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B99F5) : (isDarkMode ? const Color(0xFF262320) : Colors.white),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87), size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}