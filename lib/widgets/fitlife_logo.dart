import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Biểu trưng FitLife: trái tim xanh có dấu tích trắng bên trong,
/// dùng ở màn hình chào mừng và màn hình đăng nhập.
class FitLifeLogo extends StatelessWidget {
  final double size;

  const FitLifeLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.28),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Icon(
        Icons.favorite_rounded,
        size: size * 0.62,
        color: Colors.white,
      ),
    );
  }
}

/// Cụm biểu trưng kèm tên ứng dụng và khẩu hiệu.
class FitLifeBrand extends StatelessWidget {
  final double logoSize;
  final double titleSize;
  final bool showTagline;

  const FitLifeBrand({
    super.key,
    this.logoSize = 64,
    this.titleSize = 30,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FitLifeLogo(size: logoSize),
        SizedBox(height: logoSize * 0.24),
        Text(
          'FitLife',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          const Text(
            'Sống khỏe mỗi ngày',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
