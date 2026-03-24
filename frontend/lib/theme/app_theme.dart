import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF1360E2);
  static const Color primaryBlueDark = Color(0xFF072AC8);
  static const Color primaryBlueLight = Color(0xFF1E96FC);
  static const Color purple = Color(0xFFB272EB);
  static const Color orange = Color(0xFFEFA535);
  static const Color darkText = Color(0xFF000000);
  static const Color grayText = Color(0xFF64748B);
  static const Color lightGray = Color(0xFFE2DCDC);
  static const Color inputBg = Color(0xFFF0F4FF);
  static const Color scaffoldBg = Color(0xFFFFFFFF);
  static const Color tabBarBg = Color(0xFFE8F0FE);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.scaffoldBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      primary: AppColors.primaryBlue,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: AppColors.lightGray, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: AppColors.lightGray, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
      hintStyle: TextStyle(color: AppColors.grayText, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        elevation: 0,
      ),
    ),
  );
}
