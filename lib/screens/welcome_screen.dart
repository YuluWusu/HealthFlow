import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Thấu Hiểu Cơ Thể',
      'subtitle':
          'Theo dõi chỉ số sức khoẻ mỗi ngày.',
      'image': 'assets/images/welcome_health.jpg',
    },
    {
      'title': 'Bứt Phá Giới Hạn',
      'subtitle':
          'Thiết lập mục tiêu, theo dõi tiến độ vận động.',
      'image': 'assets/images/welcome_workout.jpg',
    },
    {
      'title': 'Quản lý ăn uống',
      'subtitle':
          'Thiết kế thực đơn khoa học chỉ với vài cú chạm.',
      'image': 'assets/images/welcome_food.jpg',
    },
    {
      'title': 'Chào mừng đến với HealthFlow',
      'subtitle':
          'Trợ lý chăm sóc sức khỏe toàn diện nằm gọn trong túi bạn. Hãy cùng kiến tạo một phiên bản hoàn hảo hơn của chính mình ngay hôm nay!',
      'image': 'assets/images/welcome_healthflow.png',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _openRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // Để ảnh tròn ăn lên sát mép trên
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final circleSize = MediaQuery.of(context).size.width * 0.75;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hình tròn căn giữa
                      Container(
                        width: circleSize,
                        height: circleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                          image: DecorationImage(
                            image: AssetImage(page['image']!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Tiêu đề & phụ đề nằm dưới hình tròn
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            Text(
                              page['title']!,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                color: Colors.black,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page['subtitle']!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Bottom bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nút Đăng nhập
                  TextButton(
                    onPressed: () => _openLogin(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('ĐĂNG NHẬP'),
                  ),
                  // Dấu chấm điều hướng
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_pages.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? AppTheme.primary
                              : Colors.grey.withValues(alpha: 0.5),
                        ),
                      );
                    }),
                  ),
                  // Nút Đăng ký
                  ElevatedButton(
                    onPressed: () => _openRegister(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'ĐĂNG KÝ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Điều khoản sử dụng ở dưới cùng
            const Padding(
              padding: EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: Text(
                'Bằng cách tiếp tục, bạn đồng ý với Điều khoản sử dụng\nvà Chính sách bảo mật của HealthFlow.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
