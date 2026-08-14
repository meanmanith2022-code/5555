import 'package:flutter/material.dart';

// បង្កើត Notifiers សម្រាប់គ្រប់គ្រង Theme និង ភាសា ទូទាំងអប
ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
ValueNotifier<Locale> languageNotifier = ValueNotifier(const Locale('en'));

Locale localeFromLanguage(String language) {
  return language == 'ខ្មែរ' ? const Locale('km') : const Locale('en');
}