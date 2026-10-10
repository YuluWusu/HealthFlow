// ignore_for_file: unnecessary_underscores

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/health_repository.dart';
import '../data/nutrition_repository.dart';
import '../data/workout_repository.dart';
import '../models/health_metric.dart';
import '../models/nutrition.dart';
import '../models/user.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import 'add_food_screen.dart';

/// Trang chủ (Dashboard) theo bản thiết kế: lời chào, thẻ năng lượng, các chỉ
/// số sức khỏe, hoạt động trong ngày và lối vào nhanh các mục khác.
class HomeScreen extends StatefulWidget {
  /// Gọi khi người dùng bấm vào lối vào nhanh, để chuyển tab ở màn hình chính.
  final ValueChanged<int>? onNavigate;

  const HomeScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  /// Cache ảnh đại diện để tránh giật khi vẽ lại.
  ImageProvider? _cachedAvatarImage;
  String? _lastAvatarPath;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Chuẩn bị và cache sẵn ảnh đại diện cho người dùng.
  ImageProvider _getAvatarImage(User? user) {
    final avatarPath = user?.avatarPath;

    // Trả về cached nếu path không đổi
    if (avatarPath == _lastAvatarPath && _cachedAvatarImage != null) {
      return _cachedAvatarImage!;
    }
    _lastAvatarPath = avatarPath;

    ImageProvider image;
    if (user != null && avatarPath != null && avatarPath.isNotEmpty) {
      image = ResizeImage(FileImage(File(avatarPath)), width: 150);
    } else {
      image = ResizeImage(
        AssetImage(user?.gender == 'female'
            ? 'assets/images/auth/female.jpg'
            : 'assets/images/auth/male.jpg'),
        width: 150,
      );
    }
    _cachedAvatarImage = image;

    // Tiền tải ảnh vào bộ đệm để tránh nhấp nháy.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) precacheImage(image, context);
    });
    return image;
  }

  /// Lời chào theo thời gian trong ngày.
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.currentUser;

    // `AppData` được lấy không theo dõi thay đổi; dữ liệu được vẽ lại nhờ
    // các `ListenableBuilder` bên dưới nên phạm vi vẽ lại hẹp.
    final app = AppScope.of(context);

    return Scaffold(
      endDrawer: _buildNotificationDrawer(context),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            app.health,
            app.nutrition,
            app.workout,
          ]),
          builder: (context, _) {
            return AnimatedBuilder(
              animation: _entranceController,
              builder: (context, _) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _buildAnimatedChild(0, _buildHeader(context, user)),
                    const SizedBox(height: 20),
                    _buildAnimatedChild(1, _buildStatsRow(app, user)),
                    const SizedBox(height: 20),
                    _buildAnimatedChild(
                      2,
                      _CalorieCard(
                        summary: app.nutrition.summary,
                        onTap: () {
                          AudioService().playTap();
                          widget.onNavigate?.call(3);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAnimatedChild(
                      3,
                      _ActivityRow(
                        minutesToday: app.workout.minutesToday,
                        goalPercent: app.workout.goalPercent,
                        caloriesBurned: app.workout.caloriesBurnedToday,
                        onTap: () {
                          AudioService().playTap();
                          widget.onNavigate?.call(2);
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildAnimatedChild(4, _buildHealthSection(app, user)),
                    const SizedBox(height: 22),
                    _buildAnimatedChild(5, _buildMealSection(app)),
                    const SizedBox(height: 22),
                    _buildAnimatedChild(6, _buildMacroSection(app)),
                    const SizedBox(height: 22),
                    _buildAnimatedChild(7, _buildWaterSection(app, user)),
                    const SizedBox(height: 22),
                    _buildAnimatedChild(8, _buildQuickAccess()),
                    const SizedBox(height: 18),
                    _buildAnimatedChild(9, const _DailyTip()),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Hiệu ứng xuất hiện lệch giờ cho từng phần tử.
  Widget _buildAnimatedChild(int index, Widget child) {
    final delay = (index * 0.08).clamp(0.0, 0.6);
    final end = (delay + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(delay, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, User? user) {
    final now = DateTime.now();
    const weekdays = [
      'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm',
      'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
    ];

    final weekday = weekdays[now.weekday - 1];
    final date = '$weekday, ${now.day}/${now.month}/${now.year}';
    final displayName = user?.fullName.trim() ?? 'bạn';
    final avatarImage = _getAvatarImage(user);
    final greeting = _getGreeting();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ngày tháng nằm tách riêng, rõ ràng
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: AppTheme.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        // Header thông tin người dùng với hình nền mờ
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            image: DecorationImage(
              image: const ResizeImage(AssetImage('assets/images/auth/auth_bg.jpg'), height: 400),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.35),
                BlendMode.darken,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting,',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$displayName 👋',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (user != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flag_rounded,
                                    color: Colors.white, size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  user.healthGoal,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      // Ảnh đại diện có viền gradient
                      GestureDetector(
                        onTap: () {
                          AudioService().playTap();
                          widget.onNavigate?.call(4);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.6),
                                Colors.white.withValues(alpha: 0.2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            backgroundImage: avatarImage,
                            onBackgroundImageError: (_, __) {},
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Nút thông báo
                      _GlassButton(
                        icon: Icons.notifications_active_rounded,
                        onTap: () => Scaffold.of(context).openEndDrawer(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Stats Row – 3 chỉ số mini nổi bật ngay dưới header
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow(AppData app, User? user) {
    final summary = app.nutrition.summary;
    final waterMl = app.nutrition.waterMl;
    final waterGoal = NutritionRepository.waterGoalFor(user?.weightKg ?? 55);
    final waterPercent = waterGoal > 0
        ? ((waterMl / waterGoal) * 100).round().clamp(0, 999)
        : 0;

    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            icon: Icons.local_fire_department_rounded,
            label: 'Calo nạp',
            value: '${summary.calories}',
            unit: 'kcal',
            color: AppTheme.orange,
            background: AppTheme.lightOrange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.fitness_center_rounded,
            label: 'Đã đốt',
            value: '${app.workout.caloriesBurnedToday}',
            unit: 'kcal',
            color: AppTheme.pink,
            background: AppTheme.lightPink,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.water_drop_rounded,
            label: 'Nước',
            value: '$waterPercent',
            unit: '%',
            color: AppTheme.blue,
            background: AppTheme.lightBlue,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Health Section
  // ---------------------------------------------------------------------------

  Widget _buildHealthSection(AppData app, User? user) {
    return Column(
      children: [
        _SectionHeading(
          title: 'Chỉ số sức khỏe',
          actionText: 'Xem tất cả',
          onAction: () {
            AudioService().playTap();
            widget.onNavigate?.call(1);
          },
        ),
        const SizedBox(height: 12),
        _HealthOverview(
          health: app.health,
          bmi: user?.bmi ?? 0,
          bmiLabel: user?.bmiLabel ?? 'Chưa có dữ liệu',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Meal Summary Section
  // ---------------------------------------------------------------------------

  Widget _buildMealSection(AppData app) {
    return Column(
      children: [
        _SectionHeading(
          title: 'Thói quen hôm nay',
          actionText: 'Dinh dưỡng',
          onAction: () {
            AudioService().playTap();
            widget.onNavigate?.call(3);
          },
        ),
        const SizedBox(height: 12),
        _MealSummaryCard(nutrition: app.nutrition),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Macro nutrients breakdown
  // ---------------------------------------------------------------------------

  Widget _buildMacroSection(AppData app) {
    final summary = app.nutrition.summary;
    return Column(
      children: [
        const _SectionHeading(
          title: 'Phân bổ chất dinh dưỡng',
          subtitle: 'Tỉ lệ Protein – Carbs – Fat',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppTheme.softShadow(opacity: 0.04),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _MacroRingPainter(
                    proteinPercent: summary.proteinPercent,
                    carbsPercent: summary.carbsPercent,
                    fatPercent: summary.fatPercent,
                  ),
                  child: Center(
                    child: Text(
                      '${summary.calories}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _MacroRow(
                      label: 'Protein',
                      grams: summary.protein,
                      percent: summary.proteinPercent,
                      color: AppTheme.blue,
                    ),
                    const SizedBox(height: 12),
                    _MacroRow(
                      label: 'Carbs',
                      grams: summary.carbs,
                      percent: summary.carbsPercent,
                      color: AppTheme.orange,
                    ),
                    const SizedBox(height: 12),
                    _MacroRow(
                      label: 'Fat',
                      grams: summary.fat,
                      percent: summary.fatPercent,
                      color: AppTheme.pink,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Water Section
  // ---------------------------------------------------------------------------

  Widget _buildWaterSection(AppData app, User? user) {
    final waterMl = app.nutrition.waterMl;
    final weightKg = user?.weightKg ?? 55;
    final waterGoal = NutritionRepository.waterGoalFor(weightKg);
    final waterProgress =
        waterGoal > 0 ? (waterMl / waterGoal).clamp(0.0, 1.0) : 0.0;
    final waterPercent = (waterProgress * 100).round();
    final cups = (waterMl / (app.nutrition.cupMl)).ceil();

    return Column(
      children: [
        _SectionHeading(
          title: 'Nước uống hôm nay',
          actionText: 'Chi tiết',
          onAction: () {
            AudioService().playTap();
            widget.onNavigate?.call(3);
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                AppTheme.blue.withValues(alpha: 0.08),
                AppTheme.lightBlue,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppTheme.blue.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.05);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: waterProgress,
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppTheme.blue.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.blue),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.water_drop_rounded,
                              color: AppTheme.blue, size: 18),
                          const SizedBox(height: 2),
                          Text(
                            '$waterPercent%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$waterMl',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                          TextSpan(
                            text: ' / $waterGoal ml',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: waterProgress,
                        minHeight: 6,
                        backgroundColor: AppTheme.blue.withValues(alpha: 0.12),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppTheme.blue),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Đã uống $cups cốc · Mục tiêu $waterGoal ml',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Quick Access
  // ---------------------------------------------------------------------------

  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Khám phá',
          subtitle: 'Truy cập nhanh các tính năng',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickAccessCard(
                title: 'Sức khỏe',
                subtitle: 'Chỉ số',
                icon: Icons.favorite_rounded,
                color: AppTheme.pink,
                background: AppTheme.lightPink,
                onTap: () {
                  AudioService().playTap();
                  widget.onNavigate?.call(1);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAccessCard(
                title: 'Tập luyện',
                subtitle: 'Bài tập',
                icon: Icons.fitness_center_rounded,
                color: AppTheme.primary,
                background: AppTheme.lightGreen,
                onTap: () {
                  AudioService().playTap();
                  widget.onNavigate?.call(2);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAccessCard(
                title: 'Dinh dưỡng',
                subtitle: 'Thực đơn',
                icon: Icons.restaurant_rounded,
                color: AppTheme.orange,
                background: AppTheme.lightOrange,
                onTap: () {
                  AudioService().playTap();
                  widget.onNavigate?.call(3);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAccessCard(
                title: 'Định lượng',
                subtitle: 'Thức ăn',
                icon: Icons.scale_rounded,
                color: AppTheme.blue,
                background: AppTheme.lightBlue,
                onTap: () {
                  AudioService().playTap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddFoodScreen(initialByGrams: true),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Notification Drawer
  // ---------------------------------------------------------------------------

  Widget _buildNotificationDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_active_rounded,
                        color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Thông báo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: const [
                  _NotificationTile(
                    title: 'Đã đến giờ uống nước!',
                    subtitle:
                        'Hãy uống 1 cốc nước (250ml) để duy trì sự tỉnh táo.',
                    time: '10 phút trước',
                    icon: Icons.local_drink_rounded,
                    color: AppTheme.blue,
                  ),
                  _NotificationTile(
                    title: 'Mục tiêu hoàn thành',
                    subtitle:
                        'Bạn đã đạt 100% mục tiêu calo hôm nay. Tuyệt vời!',
                    time: '2 giờ trước',
                    icon: Icons.emoji_events_rounded,
                    color: AppTheme.orange,
                  ),
                  _NotificationTile(
                    title: 'Nhắc nhở tập luyện',
                    subtitle:
                        'Đừng quên bài tập Cardio 15 phút chiều nay nhé.',
                    time: 'Hôm qua',
                    icon: Icons.fitness_center_rounded,
                    color: AppTheme.pink,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED PRIVATE WIDGETS
// =============================================================================

/// Nút kính mờ trong header.
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Thẻ thống kê nhỏ 3 cột.
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color background;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow(opacity: 0.04),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiêu đề một nhóm nội dung, kèm liên kết hành động bên phải nếu có.
class _SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const _SectionHeading({
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                actionText!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Thẻ năng lượng đã nạp trong ngày, số liệu lấy từ nhật ký ăn uống thật.
class _CalorieCard extends StatelessWidget {
  final NutritionSummary summary;
  final VoidCallback? onTap;

  const _CalorieCard({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    final consumed = summary.calories;
    final target = summary.calorieGoal;
    final progress = summary.calorieProgress;
    final percent = summary.caloriePercent;
    final remaining = summary.remainingCalories;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Background image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/welcome/welcome_food.jpg',
                    fit: BoxFit.cover,
                    
                  ),
                ),
                // Gradient overlay cho phép hình nền hiện rõ hơn
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryDark.withValues(alpha: 0.70),
                          AppTheme.primary.withValues(alpha: 0.40),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.17),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Tổng calo hôm nay',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$percent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatThousands(consumed),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    height: 1.1,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '/ ${_formatThousands(target)} kcal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 82,
                            height: 82,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 8,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.2),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.restaurant_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$percent%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            remaining >= 0
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: Colors.white70,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            remaining >= 0
                                ? 'Còn lại ${_formatThousands(remaining)} kcal'
                                : 'Đã vượt ${_formatThousands(-remaining)} kcal',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Định dạng 1250 thành 1,250 cho dễ đọc, giống bản thiết kế.
  static String _formatThousands(int value) {
    final text = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }
}

/// Hai thẻ nhỏ về vận động và năng lượng đã đốt.
class _ActivityRow extends StatelessWidget {
  final int minutesToday;
  final int goalPercent;
  final int caloriesBurned;
  final VoidCallback? onTap;

  const _ActivityRow({
    required this.minutesToday,
    required this.goalPercent,
    required this.caloriesBurned,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SmallInfoCard(
            icon: Icons.directions_walk_rounded,
            iconColor: AppTheme.primary,
            iconBackground: AppTheme.lightGreen,
            title: 'Vận động hôm nay',
            value: '$minutesToday phút',
            note: 'Mục tiêu ${WorkoutRepository.dailyMinuteGoal} phút',
            progress: (minutesToday / WorkoutRepository.dailyMinuteGoal)
                .clamp(0.0, 1.0),
            progressColor: AppTheme.primary,
            onTap: onTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SmallInfoCard(
            icon: Icons.local_fire_department_outlined,
            iconColor: AppTheme.orange,
            iconBackground: AppTheme.lightOrange,
            title: 'Năng lượng đốt',
            value: '$caloriesBurned kcal',
            note: 'Hoàn thành $goalPercent%',
            progress: (goalPercent / 100.0).clamp(0.0, 1.0),
            progressColor: AppTheme.orange,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _SmallInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String value;
  final String note;
  final double progress;
  final Color progressColor;
  final VoidCallback? onTap;

  const _SmallInfoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.value,
    required this.note,
    required this.progress,
    required this.progressColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: iconBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note,
                style: TextStyle(
                  fontSize: 10.5,
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hai chỉ số nổi bật: cân nặng (kèm xu hướng) và BMI.
class _HealthOverview extends StatelessWidget {
  final HealthRepository health;
  final double bmi;
  final String bmiLabel;

  const _HealthOverview({
    required this.health,
    required this.bmi,
    required this.bmiLabel,
  });

  @override
  Widget build(BuildContext context) {
    final weight = health.latestOf(HealthMetricType.weight);
    final trend = health.trendOf(HealthMetricType.weight);

    return Row(
      children: [
        Expanded(
          child: _HealthMetricCard(
            icon: Icons.monitor_weight_outlined,
            title: 'Cân nặng',
            value: weight == null ? '--' : weight.value.toStringAsFixed(1),
            unit: 'kg',
            note: trend.display,
            noteColor:
                trend.isDecrease ? AppTheme.primary : AppTheme.textSecondary,
            iconColor: AppTheme.blue,
            iconBackground: AppTheme.lightBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HealthMetricCard(
            icon: Icons.accessibility_new_rounded,
            title: 'BMI',
            value: bmi <= 0 ? '--' : bmi.toStringAsFixed(1),
            unit: bmiLabel,
            note: 'Theo chiều cao và cân nặng',
            noteColor: AppTheme.textSecondary,
            iconColor: AppTheme.primary,
            iconBackground: AppTheme.lightGreen,
          ),
        ),
      ],
    );
  }
}

class _HealthMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final String note;
  final Color noteColor;
  final Color iconColor;
  final Color iconBackground;

  const _HealthMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.note,
    required this.noteColor,
    required this.iconColor,
    required this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              color: iconColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: noteColor),
          ),
        ],
      ),
    );
  }
}

/// Tóm tắt các bữa ăn đã ghi trong ngày.
class _MealSummaryCard extends StatelessWidget {
  final NutritionRepository nutrition;

  const _MealSummaryCard({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow(opacity: 0.04),
      ),
      child: Column(
        children: [
          for (final slot in MealSlot.values) ...[
            if (slot != MealSlot.values.first)
              const Divider(height: 1, indent: 60),
            _MealRow(
              title: slot.label,
              description: nutrition.mealDescription(slot),
              calories: nutrition.mealCalories(slot),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final String title;
  final String description;
  final int calories;

  const _MealRow({
    required this.title,
    required this.description,
    required this.calories,
  });

  @override
  Widget build(BuildContext context) {
    final hasFood = calories > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: hasFood ? AppTheme.lightGreen : AppTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasFood
                  ? Icons.check_circle_outline_rounded
                  : Icons.add_circle_outline_rounded,
              size: 19,
              color: hasFood ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasFood ? AppTheme.lightGreen : AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$calories kcal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasFood ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyTip extends StatelessWidget {
  const _DailyTip();

  /// Danh sách lời khuyên, mỗi ngày hiển thị một câu khác nhau.
  static const List<String> _tips = [
    'Uống đủ 2 lít nước mỗi ngày giúp cơ thể tỉnh táo và hỗ trợ trao đổi chất tốt hơn.',
    'Đi bộ nhanh 20 phút sau bữa tối giúp tiêu hóa tốt và ngủ ngon hơn.',
    'Ăn đủ rau xanh trong mỗi bữa để bổ sung chất xơ và vitamin cho cơ thể.',
    'Ngủ đủ 7-8 tiếng mỗi đêm là cách đơn giản nhất để phục hồi năng lượng.',
    'Khởi động kỹ trước khi tập để tránh chấn thương không đáng có.',
    'Hạn chế đồ uống có đường, thay bằng nước lọc hoặc trà xanh.',
    'Chia nhỏ bữa ăn giúp kiểm soát cơn đói và ổn định đường huyết.',
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.08),
            AppTheme.lightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mẹo sức khỏe hôm nay',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tip,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;

  const _NotificationTile({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MACRO RING PAINTER
// =============================================================================

/// Vẽ vòng tròn tỉ lệ chất dinh dưỡng (Protein / Carbs / Fat).
class _MacroRingPainter extends CustomPainter {
  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;

  _MacroRingPainter({
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2;

    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final total = proteinPercent + carbsPercent + fatPercent;
    if (total <= 0) return;

    final segments = [
      (proteinPercent, AppTheme.blue),
      (carbsPercent, AppTheme.orange),
      (fatPercent, AppTheme.pink),
    ];

    double currentAngle = startAngle;
    for (final (percent, color) in segments) {
      if (percent <= 0) continue;
      final sweep = percent * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweep,
        false,
        paint,
      );
      currentAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) {
    return proteinPercent != oldDelegate.proteinPercent ||
        carbsPercent != oldDelegate.carbsPercent ||
        fatPercent != oldDelegate.fatPercent;
  }
}

/// Dòng hiển thị macro: label – progress bar – gram.
class _MacroRow extends StatelessWidget {
  final String label;
  final double grams;
  final double percent;
  final Color color;

  const _MacroRow({
    required this.label,
    required this.grams,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 46,
          child: Text(
            '${grams.toStringAsFixed(0)}g',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
