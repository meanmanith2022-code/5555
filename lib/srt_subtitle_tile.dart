import 'package:flutter/material.dart';

class SrtSubtitleTile extends StatelessWidget {
  final String subtitleText;
  final VoidCallback? onTap;

  const SrtSubtitleTile({super.key, required this.subtitleText, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final backgroundColor = isLight ? const Color(0xFFF7F5FC) : const Color(0xFF1B1E2A);
    final iconBackground = isLight ? const Color(0xFFE8E3F5) : const Color(0xFF2E3343);
    final iconColor = isLight ? const Color(0xFF5C527F) : Colors.cyanAccent;
    final titleColor = isLight ? const Color(0xFF2D2640) : Colors.white;
    final subtitleColor = isLight ? const Color(0xFF9E95B0) : Colors.white70;
    final arrowColor = isLight ? const Color(0xFFB8B0C8) : Colors.white54;
    final cardShadow = isLight
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  Icons.subtitles_outlined,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ឯកសារអក្សររត់ (SRT Subtitles)',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: arrowColor,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
