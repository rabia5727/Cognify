// ═══════════════════════════════════════════════════════════════════
// FILE: lib/theme_notifier.dart
//
// WHY: A global ValueNotifier that any screen can listen to.
//      SettingsScreen writes to it → main.dart rebuilds the app.
//      No need to pass callbacks through every screen.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// Global singleton — any file can import and use this
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
