import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/fitlife_logo.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Màn hình 1 trong bản thiết kế: màn hình chào mừng.
///
/// Trên cùng là phần phong cảnh (vẽ bằng gradien), phía dưới là thẻ trắng
/// chứa lời chào và hai nút Đăng nhập / Đăng ký.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Trên màn hình thấp, phần phong cảnh co lại để nhường chỗ cho nội
          // dung; nếu vẫn không đủ thì phần thẻ trắng tự cuộn được.
          final heroHeight = constraints.maxHeight < 620
              ? constraints.maxHeight * 0.34
              : constraints.maxHeight * 0.45;

          return Column(
            children: [
              SizedBox(height: heroHeight, child: const _HeroBackground()),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: _buildCard(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Thẻ trắng chứa lời chào và hai nút hành động.
  Widget _buildCard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const FitLifeBrand(logoSize: 58, titleSize: 29),
          const SizedBox(height: 24),
          const Text(
            'Chào mừng bạn!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Cùng xây dựng thói quen tốt\nvì một cuộc sống khỏe mạnh hơn',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 26),
          PrimaryButton(
            label: 'Đăng nhập',
            onPressed: () => _openLogin(context),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Đăng ký',
            onPressed: () => _openRegister(context),
          ),
          const SizedBox(height: 18),
          const Text(
            'Bằng cách tiếp tục, bạn đồng ý với Điều khoản sử dụng\nvà Chính sách bảo mật của FitLife.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _openLogin(BuildContext context) {
    // Đăng nhập/đăng ký xong thì chính route đó tự đóng (xem LoginScreen),
    // để lộ ra AuthGate đã chuyển sang màn hình chính.
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _openRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }
}

/// Phần phong cảnh phía trên, vẽ hoàn toàn bằng gradien và hình khối nên
/// không cần tệp ảnh đi kèm.
class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppTheme.heroGradient,
              stops: AppTheme.heroStops,
            ),
          ),
        ),
        // Vầng sáng mặt trời.
        Positioned(
          top: 46,
          right: 58,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE9AE).withValues(alpha: 0.75),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD98A).withValues(alpha: 0.55),
                  blurRadius: 40,
                  spreadRadius: 14,
                ),
              ],
            ),
          ),
        ),
        // Dải đồi phía sau.
        Align(
          alignment: Alignment.bottomCenter,
          child: ClipPath(
            clipper: _HillClipper(),
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8FBF9B), Color(0xFF6FA87F)],
                ),
              ),
            ),
          ),
        ),
        // Khối nội dung thương hiệu đặt trên nền phong cảnh.
      ],
    );
  }
}

/// Cắt dải màu thành hình đồi thoải, tạo cảm giác phong cảnh.
class _HillClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.10,
        size.width * 0.52,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.72,
        size.width,
        size.height * 0.28,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
