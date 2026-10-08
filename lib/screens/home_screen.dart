import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/health_repository.dart';
import '../data/nutrition_repository.dart';
import '../data/workout_repository.dart';
import '../models/health_metric.dart';
import '../models/nutrition.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

/// Trang chủ (Dashboard) theo bản thiết kế: lời chào, thẻ năng lượng, các chỉ
/// số sức khỏe, hoạt động trong ngày và lối vào nhanh các mục khác.
class HomeScreen extends StatelessWidget {
  /// Gọi khi người dùng bấm vào lối vào nhanh, để chuyển tab ở màn hình chính.
  final ValueChanged<int>? onNavigate;

  const HomeScreen({
    super.key,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.currentUser;

    // `AppScope` được lấy không theo dõi thay đổi; dữ liệu được vẽ lại nhờ
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
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                _buildHeader(context, user),
                const SizedBox(height: 22),
                _CalorieCard(
                  summary: app.nutrition.summary,
                  onTap: () => onNavigate?.call(3),
                ),
                const SizedBox(height: 18),
                _ActivityRow(
                  minutesToday: app.workout.minutesToday,
                  goalPercent: app.workout.goalPercent,
                  caloriesBurned: app.workout.caloriesBurnedToday,
                  onTap: () => onNavigate?.call(2),
                ),
                const SizedBox(height: 24),
                _SectionHeading(
                  title: 'Chỉ số sức khỏe',
                  actionText: 'Xem tất cả',
                  onAction: () => onNavigate?.call(1),
                ),
                const SizedBox(height: 12),
                _HealthOverview(
                  health: app.health,
                  bmi: user?.bmi ?? 0,
                  bmiLabel: user?.bmiLabel ?? 'Chưa có dữ liệu',
                ),
                const SizedBox(height: 24),
                _SectionHeading(
                  title: 'Thói quen hôm nay',
                  actionText: 'Dinh dưỡng',
                  onAction: () => onNavigate?.call(3),
                ),
                const SizedBox(height: 12),
                _MealSummaryCard(nutrition: app.nutrition),
                const SizedBox(height: 24),
                _buildQuickAccess(),
                const SizedBox(height: 20),
                const _DailyTip(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user) {
    final now = DateTime.now();
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];

    final weekday = weekdays[now.weekday - 1];
    final date = '$weekday, ${now.day}/${now.month}/${now.year}';

    // Lời chào dùng đầy đủ họ tên như bản thiết kế ("Xin chào, Minh Anh").
    final displayName = user?.fullName.trim() ?? 'bạn';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Xin chào, $displayName 👋',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Chúc bạn một ngày khỏe mạnh!',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Nút thông báo
        Container(
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
            boxShadow: AppTheme.softShadow(opacity: 0.04),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary, size: 22),
            onPressed: () {
               Scaffold.of(context).openEndDrawer();
            },
          ),
        ),
        // Ảnh đại diện: tải từ assets, nếu lỗi thì hiện chữ cái đầu.
        InkWell(
          onTap: () => onNavigate?.call(4),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(2), // Viền mỏng
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.lightGreen,
              backgroundImage: const AssetImage('assets/images/avatar.jpg'),
              onBackgroundImageError: (_, __) {}, // Bỏ qua lỗi nếu chưa có ảnh
            ),
          ),
        ),
      ],
    );
  }

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
                icon: Icons.favorite_rounded,
                color: AppTheme.pink,
                background: AppTheme.lightPink,
                onTap: () => onNavigate?.call(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAccessCard(
                title: 'Tập luyện',
                icon: Icons.fitness_center_rounded,
                color: AppTheme.primary,
                background: AppTheme.lightGreen,
                onTap: () => onNavigate?.call(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAccessCard(
                title: 'Dinh dưỡng',
                icon: Icons.restaurant_rounded,
                color: AppTheme.orange,
                background: AppTheme.lightOrange,
                onTap: () => onNavigate?.call(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppTheme.primary),
                  const SizedBox(width: 10),
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
                    subtitle: 'Hãy uống 1 cốc nước (250ml) để duy trì sự tỉnh táo.',
                    time: '10 phút trước',
                    icon: Icons.local_drink_rounded,
                    color: AppTheme.blue,
                  ),
                  _NotificationTile(
                    title: 'Mục tiêu hoàn thành',
                    subtitle: 'Bạn đã đạt 100% mục tiêu calo hôm nay. Tuyệt vời!',
                    time: '2 giờ trước',
                    icon: Icons.emoji_events_rounded,
                    color: AppTheme.orange,
                  ),
                  _NotificationTile(
                    title: 'Nhắc nhở tập luyện',
                    subtitle: 'Đừng quên bài tập Cardio 15 phút chiều nay nhé.',
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
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                actionText!,
                style: const TextStyle(
                  fontSize: 12.5,
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
                color: AppTheme.primary.withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            image: const DecorationImage(
              image: AssetImage('assets/images/calorie_bg.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryDark.withValues(alpha: 0.85),
                  AppTheme.primary.withValues(alpha: 0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
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
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
                            fontSize: 34,
                            height: 1.1,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '/ ${_formatThousands(target)} kcal',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    height: 78,
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
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 24,
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
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 10),
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
  final VoidCallback? onTap;

  const _SmallInfoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.value,
    required this.note,
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
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
              const SizedBox(height: 3),
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
            value: weight == null
                ? '--'
                : weight.value.toStringAsFixed(1),
            unit: 'kg',
            note: trend.display,
            noteColor: trend.isDecrease ? AppTheme.primary : AppTheme.textSecondary,
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
          Text(
            '$calories kcal',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: hasFood ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 5),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppTheme.primary,
            size: 23,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Một lời nhắc nhỏ',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tip,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
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
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.3),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(fontSize: 11, color: AppTheme.primary.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
      onTap: () {},
      isThreeLine: true,
    );
  }
}

