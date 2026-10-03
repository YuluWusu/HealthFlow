import 'package:flutter/material.dart';

/// Bảng màu và cấu hình giao diện dùng chung của FitLife.
///
/// Màu chủ đạo lấy theo bản thiết kế: xanh lá đậm cho hành động chính,
/// nền xám xanh rất nhạt cho toàn ứng dụng, các màu phụ dùng cho thẻ chỉ số.
class AppTheme {
  const AppTheme._();

  static const Color primary = Color(0xFF23865B);
  static const Color primaryDark = Color(0xFF176B46);
  static const Color background = Color(0xFFF5F8F6);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1D2B24);
  static const Color textSecondary = Color(0xFF77847C);
  static const Color danger = Color(0xFFE05252);

  static const Color lightGreen = Color(0xFFE5F3EA);
  static const Color blue = Color(0xFF5C9ED6);
  static const Color lightBlue = Color(0xFFEAF3FC);
  static const Color orange = Color(0xFFEAA54B);
  static const Color lightOrange = Color(0xFFFFF3E2);
  static const Color pink = Color(0xFFE77D98);
  static const Color lightPink = Color(0xFFFFEDF1);
  static const Color purple = Color(0xFF8E7CC3);
  static const Color lightPurple = Color(0xFFF1ECFA);

  /// Gradien nền của màn hình chào mừng: bầu trời sáng phía trên chuyển dần
  /// sang nền trắng nơi đặt thẻ nội dung, mô phỏng phong cảnh trong thiết kế.
  static const List<Color> heroGradient = [
    Color(0xFFBFDCEF),
    Color(0xFFD7E9DA),
    Color(0xFFF1E3C8),
    Color(0xFFFDF8F1),
    Color(0xFFFFFFFF),
  ];

  /// Vị trí các mốc màu của [heroGradient].
  static const List<double> heroStops = [0.0, 0.34, 0.55, 0.78, 1.0];

  /// Bóng đổ nhẹ dùng cho thẻ nội dung và thanh điều hướng.
  static List<BoxShadow> softShadow({double opacity = 0.05, double blur = 16}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: blur,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: surface,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(fontSize: 13.5, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
    );
  }
}
