import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'app_theme.dart';

// Global ValueNotifiers for progress/status
final ValueNotifier<bool> isGeneratingNotifier = ValueNotifier<bool>(false);
final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
final ValueNotifier<int> currentVoiceStepNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> totalVoiceStepsNotifier = ValueNotifier<int>(0);
final ValueNotifier<String> currentVideoTitleNotifier = ValueNotifier<String>("");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isDarkTheme = prefs.getBool('settings_dark_theme') ?? false;
  final playStartupSound = prefs.getBool('settings_startup_sound') ?? true;
  final savedLanguage = prefs.getString('settings_language') ?? 'English';

  themeNotifier.value = isDarkTheme ? ThemeMode.dark : ThemeMode.light;
  languageNotifier.value = localeFromLanguage(savedLanguage);
  runApp(MyApp(playStartupSound: playStartupSound));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.playStartupSound});

  final bool playStartupSound;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasRequestedAudio = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && widget.playStartupSound) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _playWelcomeSound();
        }
      });
    }
  }

  Future<void> _playWelcomeSound() async {
    if (_hasRequestedAudio || !mounted) {
      return;
    }
    _hasRequestedAudio = true;

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.play(AssetSource('sounds/welcome.mp3'));
    } catch (e) {
      debugPrint('Startup sound skipped: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeMode, child) {
        return ValueListenableBuilder<Locale>(
          valueListenable: languageNotifier,
          builder: (context, currentLocale, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'MeanNey AI',
              themeMode: currentThemeMode,
              locale: currentLocale,
              supportedLocales: const [
                Locale('en'),
                Locale('km'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF7F5EF),
                primarySwatch: Colors.indigo,
                cardColor: Colors.white,
                fontFamily: 'NotoSerifKhmer',
                colorScheme: const ColorScheme.light(
                  primary: Colors.indigo,
                  surface: Colors.white,
                  onSurface: Colors.black87,
                ),
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(color: Colors.black87),
                  bodyMedium: TextStyle(color: Colors.black54),
                ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF2F1F19),
                cardColor: const Color(0xFF3D2922),
                fontFamily: 'NotoSerifKhmer',
                colorScheme: const ColorScheme.dark(
                  primary: Colors.deepOrangeAccent,
                  surface: Color(0xFF2F1F19),
                  onSurface: Colors.white,
                ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF2F1F19)),
              ),
              home: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: kIsWeb && widget.playStartupSound
                    ? () async {
                        await _playWelcomeSound();
                      }
                    : null,
                child: const LightDashboardHome(),
              ),
            );
          },
        );
      },
    );
  }
}

class MainContainer extends StatelessWidget {
  const MainContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          LightDashboardHome(),
        ],
      ),
    );
  }
}
