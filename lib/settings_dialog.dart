import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    this.currentApiUrl,
    this.onSaveUrl,
  });

  final String? currentApiUrl;
  final ValueChanged<String>? onSaveUrl;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();

  bool _isDarkTheme = false;
  String _selectedLanguage = 'English';
  bool _playStartupSound = true;
  bool _playDownloadCompleteSound = true;

  @override
  void initState() {
    super.initState();
    _loadSavedApiKey(); // ទាញយក Key ដែលបានរក្សាទុកពេលបើក Dialog
  }

  // មុខងារទាញយក Key មកបង្ហាញវិញ
  Future<void> _loadSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('gemini_api_key') ?? '';
      _apiUrlController.text = widget.currentApiUrl ?? prefs.getString('api_url') ?? '';
      _isDarkTheme = prefs.getBool('settings_dark_theme') ?? false;
      _selectedLanguage = prefs.getString('settings_language') ?? 'English';
      _playStartupSound = prefs.getBool('settings_startup_sound') ?? true;
      _playDownloadCompleteSound = prefs.getBool('settings_download_sound') ?? true;
      languageNotifier.value = localeFromLanguage(_selectedLanguage);
    });
  }

  // មុខងាររក្សាទុក Key ទុកក្នុង SharedPreferences
  Future<void> _saveApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = _apiKeyController.text.trim();
    final apiUrl = _apiUrlController.text.trim();

    await prefs.setString('gemini_api_key', apiKey);
    await prefs.setString('api_url', apiUrl);
    await prefs.setBool('settings_dark_theme', _isDarkTheme);
    await prefs.setString('settings_language', _selectedLanguage);
    await prefs.setBool('settings_startup_sound', _playStartupSound);
    await prefs.setBool('settings_download_sound', _playDownloadCompleteSound);

    await sendDataToServer();

    widget.onSaveUrl?.call(apiUrl);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('បានរក្សាទុកការកំណត់រួចរាល់!')),
    );
    Navigator.pop(context); // បិទ Dialog ក្រោយពេលចុចរក្សាទុក
  }

  Future<void> sendDataToServer() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key');

    debugPrint('API Key ដែលបានរក្សាទុក: $apiKey');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ការកំណត់ (Settings)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _apiUrlController,
            decoration: const InputDecoration(
              labelText: 'Server API URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'Gemini API Key',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('រូបរាង / Theme'),
              Text(_isDarkTheme ? 'ងងឹត (Dark)' : 'ភ្លឺ (Light)'),
            ],
          ),
          SwitchListTile(
            title: const Text('Theme'),
            subtitle: const Text('ភ្លឺ / ងងឹត'),
            value: _isDarkTheme,
            onChanged: (value) async {
              setState(() {
                _isDarkTheme = value;
                themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ភាសា / Language'),
              Text(_selectedLanguage),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedLanguage,
            items: const [
              DropdownMenuItem(value: 'English', child: Text('English')),
              DropdownMenuItem(value: 'ខ្មែរ', child: Text('ខ្មែរ')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedLanguage = value;
                languageNotifier.value = localeFromLanguage(value);
              });
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('សំឡេងពេលបើកកម្មវិធី'),
            value: _playStartupSound,
            onChanged: (value) async {
              setState(() => _playStartupSound = value);
            },
          ),
          SwitchListTile(
            title: const Text('សំឡេងពេលទាញយកចប់'),
            value: _playDownloadCompleteSound,
            onChanged: (value) async {
              setState(() => _playDownloadCompleteSound = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('បិទ'),
        ),
        ElevatedButton(
          onPressed: _saveApiKey,
          child: const Text('រក្សាទុក'),
        ),
      ],
    );
  }
}