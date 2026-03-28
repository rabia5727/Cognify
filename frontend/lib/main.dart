// ═══════════════════════════════════════════════════════════════════
// FILE: lib/main.dart
// FIX: Uses global themeNotifier (ValueNotifier) so SettingsScreen
//      can change the theme without needing context tricks.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'theme_notifier.dart';
import 'screens/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved preference and set notifier before app starts
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const CoTaskerApp());
}

class CoTaskerApp extends StatelessWidget {
  const CoTaskerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder rebuilds ONLY when themeNotifier changes
    // No setState, no context tricks needed
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Co-Tasker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode, // changes instantly when notifier updates
          home: const SplashScreen(),
        );
      },
    );
  }
}
