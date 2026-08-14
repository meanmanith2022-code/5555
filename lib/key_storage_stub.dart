// Browser storage is not available on native platforms yet. This fallback
// keeps the settings UI functional there without persisting sensitive keys.
final Map<String, String> _memoryStore = {};

Future<String?> getStoredString(String key) async => _memoryStore[key];

Future<void> setStoredString(String key, String value) async {
  _memoryStore[key] = value;
}
