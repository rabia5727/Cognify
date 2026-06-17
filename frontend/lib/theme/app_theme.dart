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

  // STEP 1: Updated dark mode colors (navy-tinted, layered)
  static const Color darkScaffoldBg = Color(0xFF0E1117);
  static const Color darkSurface = Color(0xFF161B27);
  static const Color darkSurface2 = Color(0xFF1E2438);
  static const Color darkSurface3 = Color(0xFF252C42);
  static const Color darkBorder = Color(0xFF2A3050);
  static const Color darkText_ = Color(0xFFE8EAF2);
  static const Color darkGrayText = Color(0xFFA8B0C8);
  static const Color darkInputBg = Color(0xFF1C2238);

  // Status badge colors
  static const Color highBadgeBg = Color(0x30EF4444);
  static const Color mediumBadgeBg = Color(0x30F59E0B);
  static const Color lowBadgeBg = Color(0x3022C55E);
  static const Color highBadgeText = Color(0xFFFCA5A5);
  static const Color mediumBadgeText = Color(0xFFFCD34D);
  static const Color lowBadgeText = Color(0xFF86EFAC);
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

        // STEP 3: AppBar light
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
          ),
        ),

        // STEP 4: Text theme light
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.darkText),
          bodyMedium: TextStyle(color: AppColors.darkText),
          bodySmall: TextStyle(color: AppColors.grayText),
          labelSmall: TextStyle(color: AppColors.grayText),
          titleMedium: TextStyle(color: AppColors.darkText),
          titleLarge: TextStyle(color: AppColors.darkText),
        ),

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

        // STEP 6: Bottom nav light
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Colors.white,
          elevation: 8,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue);
            }
            return const TextStyle(fontSize: 11, color: AppColors.grayText);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                  color: AppColors.primaryBlue, size: 24);
            }
            return const IconThemeData(color: AppColors.grayText, size: 24);
          }),
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

        // STEP 7: Tab bar light
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.grayText,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: AppColors.primaryBlue,
          ),
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

        // STEP 2: Updated colorScheme dark
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          brightness: Brightness.dark,
          surface: AppColors.darkSurface2,
          onSurface: AppColors.darkText_,
          surfaceContainerHighest: AppColors.darkSurface3,
          surfaceContainer: AppColors.darkSurface,
          outline: AppColors.darkBorder,
        ),

        cardColor: AppColors.darkSurface2,
        dividerColor: AppColors.darkBorder,

        // STEP 3: AppBar dark
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkScaffoldBg,
          foregroundColor: AppColors.darkText_,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText_,
          ),
        ),

        // STEP 4: Text theme dark
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.darkText_),
          bodyMedium: TextStyle(color: AppColors.darkText_),
          bodySmall: TextStyle(color: AppColors.darkGrayText),
          labelSmall: TextStyle(color: AppColors.darkGrayText),
          titleMedium: TextStyle(color: AppColors.darkText_),
          titleLarge: TextStyle(color: AppColors.darkText_),
        ),

        // STEP 5: Icon themes dark
        iconTheme: const IconThemeData(color: AppColors.darkGrayText),
        primaryIconTheme: const IconThemeData(color: AppColors.darkText_),

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

        // STEP 6: Bottom nav dark
        bottomAppBarTheme: const BottomAppBarTheme(
          color: AppColors.darkSurface,
          elevation: 8,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue);
            }
            return const TextStyle(fontSize: 11, color: AppColors.darkGrayText);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                  color: AppColors.primaryBlue, size: 24);
            }
            return const IconThemeData(color: AppColors.darkGrayText, size: 24);
          }),
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

        // STEP 7: Tab bar dark
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.darkGrayText,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: AppColors.primaryBlue,
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkSurface2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.darkSurface3,
          contentTextStyle: TextStyle(color: AppColors.darkText_),
        ),
      );

  /// Default theme (light) for backward compatibility
  static ThemeData get theme => lightTheme;
}
