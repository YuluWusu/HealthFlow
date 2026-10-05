import 'package:flutter/material.dart';

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
    // Nạp dữ liệu sau khung hình đầu tiên: các hàm nạp đều gọi
    // `notifyListeners`, không nên chạy trong lúc đang dựng giao diện.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  /// Nạp chỉ số sức khỏe, danh mục món ăn và bài tập của người dùng.
  void _loadData() {
    if (!mounted || _dataLoaded) return;

    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    _dataLoaded = true;

    final app = AppScope.of(context);
    app.health.load(user.id);
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
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: _navigateTo,
      ),
      // Nền trắng để phần thân và thanh điều hướng liền mạch.
      backgroundColor: AppTheme.background,
    );
  }
}
