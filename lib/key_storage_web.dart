import 'dart:html' as html;

Future<String?> getStoredString(String key) async => html.window.localStorage[key];

Future<void> setStoredString(String key, String value) async {
  html.window.localStorage[key] = value;
}
