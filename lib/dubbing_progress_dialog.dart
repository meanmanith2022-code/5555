import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DubbingProgressDialog extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final int currentStep;
  final int totalSteps;
  final String speakerName;
  final String previewText;
  final VoidCallback onCancel;
  final VoidCallback? onClose;
  final ValueListenable<Map<String, dynamic>>? statusNotifier;

  const DubbingProgressDialog({
    super.key,
    required this.progress,
    required this.currentStep,
    required this.totalSteps,
    required this.speakerName,
    required this.previewText,
    required this.onCancel,
    this.onClose,
    this.statusNotifier,
  });

  @override
  Widget build(BuildContext context) {
    if (statusNotifier != null) {
      return ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: statusNotifier!,
        builder: (context, status, child) {
          final percent = (status['percent'] as num?)?.toDouble() ?? progress;
          final current = (status['current_step'] as num?)?.toInt() ?? currentStep;
          final total = (status['total_steps'] as num?)?.toInt() ?? totalSteps;
          final speaker = status['speaker'] as String? ?? speakerName;
          final preview = status['previewText'] as String? ?? previewText;
          return _buildDialog(context, percent, current, total, speaker, preview);
        },
      );
    }

    return _buildDialog(context, progress, currentStep, totalSteps, speakerName, previewText);
  }

  Color _surfaceColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFF0F3F8)
        : const Color(0xFF0F172A);
  }

  Color _infoBoxColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1E293B);
  }

  Color _textPrimary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFF182234)
        : Colors.white;
  }

  Color _textSecondary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFF667085)
        : Colors.white60;
  }

  Widget _buildDialog(
    BuildContext context,
    double progress,
    int currentStep,
    int totalSteps,
    String speakerName,
    String previewText,
  ) {
    // When no work has started yet, show 0% — not the old 10% floor.
    final scaledProgress = (currentStep / (totalSteps > 0 ? totalSteps : 1))
        .clamp(0.0, 1.0);
    final calculatedProgress = scaledProgress * 100;
    final progressPercentage = (progress > 0.0)
        ? (progress * 100).clamp(0.0, 100.0)
        : calculatedProgress.clamp(0.0, 100.0);

    final bgColor = _surfaceColor(context);
    final infoColor = _infoBoxColor(context);
    final textColor = _textPrimary(context);
    final mutedColor = _textSecondary(context);
    final accent = Colors.cyan;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Processing
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 3),
              ),
              child: Icon(Icons.psychology, color: accent, size: 40),
            ),
            const SizedBox(height: 20),

            // Progress Text & Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'កំពុងបង្កើតវីដេអូបកប្រែ...',
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${progressPercentage.toInt()}%',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressPercentage / 100,
                minHeight: 10,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 16),

            // Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: infoColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ជំហានសំឡេង (Voice Step):',
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                      Text(
                        '$currentStep / $totalSteps',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'អ្នកបញ្ចេញសំឡេង (Speaker):',
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          speakerName,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notice
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  'សូមកុំចាកចេញពីកម្មវិធី រហូតដល់ដំណើរការចប់!',
                  style: TextStyle(color: mutedColor, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cancel Button
            OutlinedButton.icon(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(double.infinity, 45),
              ),
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
              label: const Text(
                'បោះបង់ការបង្កើត (Cancel Generation)',
                style: TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
