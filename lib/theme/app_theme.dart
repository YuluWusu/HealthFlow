import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF4CAF80);
  static const Color background = Color(0xFFF7FAF8);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF24332B);
  static const Color textSecondary = Color(0xFF87948C);
  static const Color lightGreen = Color(0xFFE7F5EC);
  static const Color orange = Color(0xFFFFB45C);
  static const Color blue = Color(0xFF77B7E8);
  static const Color pink = Color(0xFFEF91A8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: card,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}