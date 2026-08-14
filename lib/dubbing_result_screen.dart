import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class DubbingResultScreen extends StatefulWidget {
  final String? videoPath;
  final String? fileSize; 

  const DubbingResultScreen({
    super.key, 
    this.videoPath, 
    this.fileSize,
  });

  @override
  State<DubbingResultScreen> createState() => _DubbingResultScreenState();
}

class _DubbingResultScreenState extends State<DubbingResultScreen> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoPath != null && widget.videoPath!.isNotEmpty) {
      if (widget.videoPath!.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath!));
      } else {
        _controller = VideoPlayerController.file(File(widget.videoPath!));
      }
      _controller?.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
      _controller?.addListener(() {
        if (_controller != null && mounted) {
          final isPlayingNow = _controller!.value.isPlaying;
          if (isPlayingNow != _isPlaying) {
            setState(() {
              _isPlaying = isPlayingNow;
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller != null) {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      }
    });
  }

  Future<void> _downloadVideo() async {
    if (widget.videoPath == null || widget.videoPath!.isEmpty) return;
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('កំពុងទាញយកវីដេអូ... (Downloading video...)')),
    );

    try {
      final fileName = 'dubbed_output_${DateTime.now().millisecondsSinceEpoch}';

      if (widget.videoPath!.startsWith('http')) {
        final response = await http.get(Uri.parse(widget.videoPath!));
        if (response.statusCode == 200) {
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: response.bodyBytes,
            ext: 'mp4',
            mimeType: MimeType.other,
          );
        }
      } else {
        final file = File(widget.videoPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: bytes,
            ext: 'mp4',
            mimeType: MimeType.other,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('បានរក្សាទុកវីដេអូដោយជោគជ័យ!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('បរាជ័យក្នុងការទាញយក: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('វីដេអូដែលបានប្រែជាភាសាខ្មែរ (Dubbed Output)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 450),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            color: Colors.transparent,
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.black.withValues(alpha: 0.5),
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(50.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 5,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ព័ត៌មានឯកសារ (File Information)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.folder_open, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text('ទំហំឯកសារ (Size): ${widget.fileSize ?? "Unknown"}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ទីតាំងឯកសារ (Path): ${widget.videoPath ?? "N/A"}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF33B5E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text(
                  'រក្សាទុកក្នុងទូរស័ព្ទ (Save to Gallery)',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onPressed: _downloadVideo,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF33B5E5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.share, color: Color(0xFF33B5E5)),
                    label: const Text(
                      'ចែករំលែកតំណភ្ជាប់',
                      style: TextStyle(color: Color(0xFF33B5E5)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('មុខងារចែករំលែកតំណភ្ជាប់')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C54ED),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'បកប្រែថ្មី (New Dub)',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
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