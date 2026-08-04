import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// មុខងារសម្រាប់បើកលីង AI Studio App
Future<void> _launchAIStudioApp() async {
  final Uri url = Uri.parse(
    'https://aistudio.google.com/apps/5ffb7163-9565-40e5-bf25-adafe12c6836?fullscreenApplet=true&showPreview=true&showAssistant=true',
  );
  
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}

// ឧទាហរណ៍នៃការដាក់បញ្ចូលប៊ូតុងក្នុង Widget
Widget buildAiDubberButton(BuildContext context) {
  return ElevatedButton.icon(
    onPressed: _launchAIStudioApp,
    icon: const Icon(Icons.auto_awesome),
    label: const Text('AI Dubber Ultimate (Batch Translate)'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
    ),
  );
}