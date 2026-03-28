// ═══════════════════════════════════════════════════════════════════
// FILE: test/widget_test.dart
// PURPOSE: Basic widget tests for the CoTasker app
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/theme_notifier.dart';

void main() {
  setUp(() {
    // Reset theme before each test
    themeNotifier.value = ThemeMode.light;
  });

  testWidgets('App starts without crashing', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const CoTaskerApp());
    await tester.pump();

    // Verify app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App responds to theme changes', (WidgetTester tester) async {
    // Build app in light mode
    await tester.pumpWidget(const CoTaskerApp());
    await tester.pump();

    // Change to dark mode via notifier
    themeNotifier.value = ThemeMode.dark;
    await tester.pump();

    // Verify app still builds
    expect(find.byType(MaterialApp), findsOneWidget);

    // Change back to light mode
    themeNotifier.value = ThemeMode.light;
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
