import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'health_screen.dart';
import 'home_screen.dart';
import 'nutrition_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

/// Khung chính của ứng dụng sau khi đăng nhập: 5 tab theo bản thiết kế
/// (Trang chủ, Sức khỏe, Tập luyện, Dinh dưỡng, Cài đặt).
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  /// Đánh dấu dữ liệu đã được nạp hay chưa, tránh nạp lặp lại mỗi lần vẽ.
  bool _dataLoaded = false;

  late final List<Widget> _screens = [
    HomeScreen(onNavigate: _navigateTo),
    const HealthScreen(),
    const WorkoutScreen(),
    const NutritionScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    // Nạp dữ liệu sau khung hình đầu tiên: các hàm nạp đều gọi
    // `notifyListeners`, không nên chạy trong lúc đang dựng giao diện.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Nạp chỉ số sức khỏe, danh mục món ăn và bài tập của người dùng.
  void _loadData() {
    if (!mounted || _dataLoaded) return;

    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    _dataLoaded = true;

    final app = AppScope.of(context);
    app.health.load(user.id, heightCm: user.heightCm);
    app.nutrition.loadCatalog();
    app.workout.loadCatalog();
    app.nutrition.loadDay(
      userId: user.id,
      calorieGoal: user.dailyCalorieGoal,
    );
    app.workout.loadDay(user.id);
  }

  void _navigateTo(int index) {
    if (index < 0 || index >= _screens.length) return;
    if (index == _selectedIndex) return;
    
    if ((index - _selectedIndex).abs() > 1) {
      // Jump directly if distance is > 1
      _pageController.jumpToPage(index);
    } else {
      // Animate if next to each other
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    setState(() => _selectedIndex = index);
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thoát ứng dụng'),
            content: const Text('Bạn có chắc chắn muốn thoát HealthFlow?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Không'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Có'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const ClampingScrollPhysics(), // Đảm bảo vuốt mượt mà khi có danh sách cuộn ngang bên trong
          children: _screens,
        ),
        bottomNavigationBar: AppBottomNav(
          selectedIndex: _selectedIndex,
          onItemTapped: _navigateTo,
        ),
        // Nền trắng để phần thân và thanh điều hướng liền mạch.
        backgroundColor: AppTheme.background,
      ),
    );
  }
}
