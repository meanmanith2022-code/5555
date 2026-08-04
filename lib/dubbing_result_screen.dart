import 'dart:io';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class DubbingResultScreen extends StatefulWidget {
  final String videoPath;
  final String fileSize;

  const DubbingResultScreen({
    super.key,
    required this.videoPath,
    required this.fileSize,
  });

  @override
  State<DubbingResultScreen> createState() => _DubbingResultScreenState();
}

class _DubbingResultScreenState extends State<DubbingResultScreen> {
  VideoPlayerController? _videoController;
  bool _isLoadingVideo = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  void _videoListener() {
    if (!mounted || _videoController == null) return;
    if (_videoController!.value.isInitialized) {
      setState(() {});
    }
  }

  Future<void> _initializePlayer() async {
    final videoPath = widget.videoPath;
    try {
      if (videoPath.toLowerCase().startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else if (videoPath.toLowerCase().startsWith('file://')) {
        _videoController = VideoPlayerController.file(File(videoPath));
      } else {
        _videoController = VideoPlayerController.file(File(videoPath));
      }

      await _videoController!.initialize();
      _videoController!.addListener(_videoListener);
      await _videoController!.setLooping(false);
      await _videoController!.play();
    } catch (_) {
      // ignore errors and show fallback UI.
    }

    if (mounted) {
      setState(() {
        _isLoadingVideo = false;
      });
    }
  }

  Color _bgColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF7F8FC)
        : const Color(0xFF0B1120);
  }

  Color _surfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1E293B);
  }

  Color _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF182234)
        : Colors.white;
  }

  Future<void> _saveToGallery() async {
    try {
      final videoPath = widget.videoPath;
      final bytes = videoPath.toLowerCase().startsWith('http')
          ? (await http.get(Uri.parse(videoPath))).bodyBytes
          : await File(videoPath).readAsBytes();

      await FileSaver.instance.saveFile(
        name: 'dubbed_output',
        bytes: bytes,
        fileExtension: 'mp4',
        mimeType: MimeType.other,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('វីដេអូត្រូវបានរក្សាទុក។')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _bgColor(context);
    final surfaceColor = _surfaceColor(context);
    final textColor = _textColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'វីដេអូបកប្រែរួចរាល់ (Dubbed Output)',
          style: TextStyle(color: textColor, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.cyan),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  color: surfaceColor,
                  child: _isLoadingVideo
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.cyan),
                        )
                      : (_videoController != null && _videoController!.value.isInitialized)
                          ? Stack(
                              children: [
                                Center(
                                  child: AspectRatio(
                                    aspectRatio: _videoController!.value.aspectRatio > 0
                                        ? _videoController!.value.aspectRatio
                                        : 16 / 9,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (_videoController == null) return;
                                      if (_videoController!.value.isPlaying) {
                                        await _videoController!.pause();
                                      } else {
                                        await _videoController!.play();
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black45,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        _videoController!.value.isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_fill,
                                        color: Colors.cyan,
                                        size: 60,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.cyan,
                                size: 60,
                              ),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ព័ត៌មានឯកសារ (File Information)',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.sd_storage,
                        color: Colors.cyan,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ទំហំឯកសារ (Size): ${widget.fileSize}',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.cyan,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ទីតាំងរក្សាទុក (Path): ${widget.videoPath}',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.54),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveToGallery,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.download, color: Colors.black),
              label: const Text(
                'រក្សាទុកក្នុងទូរស័ព្ទ (Save to Gallery)',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.cyan),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.share, color: Colors.cyan),
                    label: const Text(
                      'ចែករំលែកវីដេអូ',
                      style: TextStyle(color: Colors.cyan),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'បកប្រែថ្មី (New Dub)',
                      style: TextStyle(color: Colors.white),
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
}
