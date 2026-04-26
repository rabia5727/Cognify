// ═══════════════════════════════════════════════════════════════════
// FILE: lib/theme/app_theme.dart
// PURPOSE: Centralized theme configuration for light and dark modes
//          Use AppTheme.lightTheme or AppTheme.darkTheme in MaterialApp
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// =============================================================
// COLOR DEFINITIONS
// =============================================================

class AppColors {
  // Brand colors (consistent across both modes)
  static const Color primaryBlue = Color(0xFF1360E2);
  static const Color primaryBlueDark = Color(0xFF072AC8);
  static const Color primaryBlueLight = Color(0xFF1E96FC);
  static const Color purple = Color(0xFFB272EB);
  static const Color orange = Color(0xFFEFA535);

  // Light mode colors
  static const Color darkText = Color(0xFF000000);
  static const Color grayText = Color(0xFF64748B);
  static const Color lightGray = Color(0xFFE2DCDC);
  static const Color inputBg = Color(0xFFF0F4FF);
  static const Color scaffoldBg = Color(0xFFFFFFFF);
  static const Color tabBarBg = Color(0xFFE8F0FE);

  // Dark mode colors
  static const Color darkScaffoldBg = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF1C1E27);
  static const Color darkSurface2 = Color(0xFF252836);
  static const Color darkBorder = Color(0xFF2E3147);
  static const Color darkText_ = Color(0xFFF1F1F3);
  static const Color darkGrayText = Color(0xFF9EA3B8);
  static const Color darkInputBg = Color(0xFF1E2130);
}

// =============================================================
// THEME DEFINITIONS
// =============================================================

class AppTheme {
  /// Light theme configuration
  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          brightness: Brightness.light,
        ),
        cardColor: Colors.white,
        dividerColor: AppColors.lightGray,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide:
                const BorderSide(color: AppColors.lightGray, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide:
                const BorderSide(color: AppColors.lightGray, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          ),
          hintStyle: const TextStyle(color: AppColors.grayText, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            elevation: 0,
          ),
        ),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Colors.white,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue;
            }
            return AppColors.grayText;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue.withOpacity(0.5);
            }
            return AppColors.lightGray;
          }),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.black87,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      );

  /// Dark theme configuration
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.darkScaffoldBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          brightness: Brightness.dark,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkText_,
        ),
        cardColor: AppColors.darkSurface,
        dividerColor: AppColors.darkBorder,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkInputBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide:
                const BorderSide(color: AppColors.darkBorder, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide:
                const BorderSide(color: AppColors.darkBorder, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          ),
          hintStyle:
              const TextStyle(color: AppColors.darkGrayText, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            elevation: 0,
          ),
        ),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Colors.white,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue;
            }
            return AppColors.darkGrayText;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlue.withOpacity(0.5);
            }
            return AppColors.darkBorder;
          }),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.darkSurface2,
          contentTextStyle: TextStyle(color: AppColors.darkText_),
        ),
      );

  /// Default theme (light) for backward compatibility
  static ThemeData get theme => lightTheme;
}
