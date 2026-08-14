import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../dashboard_screen.dart';
import '../dashboard_screen.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    // 1. លេងសំឡេង Welcome Sound
    _playWelcomeSound();

    // 2. រង់ចាំ 3 វិនាទី រួចរត់ចូល App
    Timer(const Duration(milliseconds: 3000), () {
      _navigateToHomeScreen();
    });
  }

  Future<void> _playWelcomeSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/welcome.mp3'));
    } catch (e) {
      debugPrint("Audio play error: $e");
    }
  }

  void _navigateToHomeScreen() {
    if (!mounted) return;

    // ✅ 2. ប្តូរពី MainHomeScreen() ទៅជា LightDashboardHome()
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            LightDashboardHome(), // អេក្រង់ Dashboard ពេញលេញ
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1221),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // LOGO
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 32),

                // TITLE
                const Text(
                  'MeanNey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'កម្មវិធីបកប្រែរឿង',
                  style: TextStyle(
                    color: Color(0xFF8B9BB4),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'បង្កើតឡើងដោយ : ម៉ៅ មាន',
                  style: TextStyle(
                    color: Color(0xFF6C7A9C),
                    fontSize: 14,
                  ),
                ),

                const Spacer(),

                // PROGRESS BAR
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 6,
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4A80F0),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'កំពុងត្រួតពិនិត្យគណនីរបស់អ្នក...',
                  style: TextStyle(
                    color: Color(0xFF6C7A9C),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}