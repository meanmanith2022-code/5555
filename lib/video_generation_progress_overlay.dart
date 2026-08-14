import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // សម្រាប់ ValueNotifier និង ValueListenable

class VideoGenerationProgressOverlay extends StatelessWidget {
  // 1. Change from 'double progress' to 'ValueListenable<double>'
  final ValueListenable<double> progressNotifier;
  final int currentVoiceStep;
  final int totalVoiceSteps;
  final String speakerName;
  final String videoTitle;
  final VoidCallback onCancel;

  const VideoGenerationProgressOverlay({
    super.key,
    required this.progressNotifier,
    required this.currentVoiceStep,
    required this.totalVoiceSteps,
    required this.speakerName,
    required this.videoTitle,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    // 2. Wrap the contents in ValueListenableBuilder
    return ValueListenableBuilder<double>(
      valueListenable: progressNotifier,
      builder: (context, progress, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ... (Keep your existing Header Column here)

                // Example of updating the CircularProgressIndicator with the 'progress' value
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: progress, // Now reactive
                        strokeWidth: 6,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.cyanAccent,
                        ),
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    // ... (Keep the inner icon/container)
                  ],
                ),

                // ... (Keep the rest of your UI using 'progress')
              ],
            ),
          ),
        );
      },
    );
  }
}
