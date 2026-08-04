import 'package:shared_preferences/shared_preferences.dart';

Future<String?> getStoredString(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<void> setStoredString(String key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<void> saveApiKey(String apiKey) async {
  final prefs = await SharedPreferences.getInstance();
  List<String> keys = prefs.getStringList('saved_api_keys') ?? [];
  if (!keys.contains(apiKey)) {
    keys.add(apiKey);
    await prefs.setStringList('saved_api_keys', keys);
  }
}

Future<List<String>> getApiKeys() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('saved_api_keys') ?? [];
}

Future<String?> getApiUrl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('saved_api_url');
}

Future<void> saveApiUrl(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('saved_api_url', url);
}
