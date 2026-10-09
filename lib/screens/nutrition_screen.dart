// ignore_for_file: unnecessary_underscores

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, HapticFeedback, SystemUiOverlayStyle;

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../data/usda_food_service.dart';
import '../data/vietnam_food_source.dart';
import '../models/meal_combo.dart';
import '../models/nutrition.dart';
import '../theme/app_theme.dart';
import '../theme/food_images.dart';
import 'add_food_screen.dart';
import 'water_screen.dart';

/// Màn hình Dinh dưỡng.
///
/// Ba thẻ: Hôm nay (vòng năng lượng và các bữa), Thực đơn (tìm món Việt Nam
/// từ Excel + món quốc tế từ USDA), Thống kê (tỉ lệ chất và phân bố theo bữa).
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return DefaultTabController(
      length: 3,
      child: _NutritionBackdrop(
        child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text(
            'Dinh dưỡng',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TabBar(
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
                indicator: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13.5),
                tabs: const [
                  Tab(text: 'Hôm nay'),
                  Tab(text: 'Thực đơn'),
                  Tab(text: 'Thống kê'),
                ],
              ),
            ),
          ),
        ),
        body: ListenableBuilder(
          listenable: app.nutrition,
          builder: (context, _) {
            return TabBarView(
              children: [
                _TodayTab(nutrition: app.nutrition),
                _MenuTab(nutrition: app.nutrition),
                _StatsTab(nutrition: app.nutrition),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

/// Nền ảnh toàn màn hình của màn hình Dinh dưỡng.
///
/// Mỗi tab có một ảnh riêng (chuyển mờ khi đổi tab), phủ thêm lớp tối để chữ
/// trắng và các thẻ kính mờ phía trên luôn đọc rõ dù sau này thay bằng ảnh
/// chụp thật.
class _NutritionBackdrop extends StatelessWidget {
  const _NutritionBackdrop({required this.child});

  final Widget child;

  static const List<String> _assets = [
    'assets/images/home/bg_today.jpg',
    'assets/images/home/bg_menu.jpg',
    'assets/images/home/bg_stats.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final animation = DefaultTabController.of(context).animation!;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final index = animation.value.round().clamp(0, _assets.length - 1);
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: SizedBox.expand(
                key: ValueKey(index),
                child: Image.asset(
                  _assets[index],
                  fit: BoxFit.cover,
                  cacheWidth: 720,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF1B3A2A)),
                ),
              ),
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x99000000)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Màu sắc và kiểu dùng chung
// ---------------------------------------------------------------------------

const Color _purple = Color(0xFF8E6CEF);
const Color _lightPurple = Color(0xFFF0EAFE);
const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 8)),
];

Color _slotColor(MealSlot slot) {
  switch (slot) {
    case MealSlot.breakfast:
      return AppTheme.orange;
    case MealSlot.lunch:
      return AppTheme.primary;
    case MealSlot.dinner:
      return AppTheme.blue;
    case MealSlot.snack:
      return _purple;
  }
}

Color _slotTint(MealSlot slot) {
  switch (slot) {
    case MealSlot.breakfast:
      return AppTheme.lightOrange;
    case MealSlot.lunch:
      return AppTheme.lightGreen;
    case MealSlot.dinner:
      return AppTheme.lightBlue;
    case MealSlot.snack:
      return _lightPurple;
  }
}

IconData _slotIcon(MealSlot slot) {
  switch (slot) {
    case MealSlot.breakfast:
      return Icons.free_breakfast_rounded;
    case MealSlot.lunch:
      return Icons.lunch_dining_rounded;
    case MealSlot.dinner:
      return Icons.dinner_dining_rounded;
    case MealSlot.snack:
      return Icons.icecream_rounded;
  }
}

IconData _foodIcon(FoodItem food) {
  if (food is CatalogFood) {
    switch (food.group) {
      case 'Món nước':
        return Icons.ramen_dining_rounded;
      case 'Món bánh':
        return Icons.bakery_dining_rounded;
      case 'Món kho/xào':
        return Icons.set_meal_rounded;
      case 'Món chiên/nướng':
        return Icons.outdoor_grill_rounded;
      case 'Món cơm/xôi':
        return Icons.rice_bowl_rounded;
      case 'Món canh/lẩu':
        return Icons.soup_kitchen_rounded;
      case 'Món tráng miệng/chè':
        return Icons.icecream_rounded;
      case 'Món gỏi/nộm':
        return Icons.eco_rounded;
      case 'Món luộc':
        return Icons.egg_alt_rounded;
    }
  }
  if (food.category == FoodCategory.drink) return Icons.local_cafe_rounded;
  return Icons.restaurant_rounded;
}

bool _isUsda(FoodItem food) =>
    food is CatalogFood && food.source == FoodSource.usda;

Color _foodColor(FoodItem food) {
  if (_isUsda(food)) return AppTheme.blue;
  if (food.category == FoodCategory.vietnamese) return AppTheme.orange;
  return AppTheme.primary;
}

Color _foodTint(FoodItem food) {
  if (_isUsda(food)) return AppTheme.lightBlue;
  if (food.category == FoodCategory.vietnamese) return AppTheme.lightOrange;
  return AppTheme.lightGreen;
}

String _formatDay(DateTime d) {
  const days = [
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
    'Chủ nhật',
  ];
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '${days[d.weekday - 1]}, $dd/$mm';
}

String _shortDay(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm';
}

String _grams(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

MealSlot _slotForNow() {
  final hour = DateTime.now().hour;
  if (hour < 10) return MealSlot.breakfast;
  if (hour < 14) return MealSlot.lunch;
  if (hour < 17) return MealSlot.snack;
  return MealSlot.dinner;
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _cardShadow,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(action!),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Hôm nay
// ---------------------------------------------------------------------------

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.nutrition});

  final NutritionRepository nutrition;

  @override
  Widget build(BuildContext context) {
    final summary = nutrition.summary;

    return _ScrollTopView(
      builder: (scroll) => CustomScrollView(
        controller: scroll,
        slivers: [
          // Thanh chọn ngày được ghim ở mép trên khi cuộn qua các bữa ăn.
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedDayBarDelegate(
              child: _DayNavigator(nutrition: nutrition),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _EnergyCard(
                  summary: summary,
                  title: nutrition.isToday
                      ? 'Tổng calo hôm nay'
                      : nutrition.isFutureDay
                          ? 'Calo dự kiến ${_shortDay(nutrition.selectedDay)}'
                          : 'Tổng calo ${_shortDay(nutrition.selectedDay)}',
                ),
                const SizedBox(height: 14),
                _WaterCard(nutrition: nutrition),
                const SizedBox(height: 24),
                _SectionTitle(
                  'Bữa ăn trong ngày',
                  action: 'Thêm món',
                  onAction: () => _openAddFood(context),
                ),
                const SizedBox(height: 8),
                for (final slot in MealSlot.values)
                  _MealCard(
                    slot: slot,
                    description: nutrition.mealDescription(slot),
                    calories: nutrition.mealCalories(slot),
                    totalCalories: summary.calories,
                    entries: nutrition.todayEntries
                        .where((entry) => entry.slot == slot)
                        .toList(),
                    nutrition: nutrition,
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Giữ thanh chọn ngày lơ lửng ở mép trên (nền kính mờ) để luôn biết đang xem
/// ngày nào.
class _PinnedDayBarDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedDayBarDelegate({required this.child});

  final Widget child;

  static const double _height = 60;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: Colors.black.withValues(alpha: overlapsContent ? 0.38 : 0.1),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedDayBarDelegate oldDelegate) => true;
}

/// Thanh chọn ngày: ‹ Thứ hai, 05/10 › + chọn nhanh bằng lịch.
class _DayNavigator extends StatelessWidget {
  const _DayNavigator({required this.nutrition});

  final NutritionRepository nutrition;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: nutrition.selectedDay,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Chọn ngày xem',
      cancelText: 'Hủy',
      confirmText: 'Xem',
    );
    if (picked != null) await nutrition.selectDay(picked);
  }

  void _shift(int days) {
    final d = nutrition.selectedDay;
    nutrition.selectDay(DateTime(d.year, d.month, d.day + days));
  }

  @override
  Widget build(BuildContext context) {
    final day = nutrition.selectedDay;
    final label = nutrition.isToday
        ? 'Hôm nay'
        : nutrition.isFutureDay
            ? 'Kế hoạch'
            : 'Đã qua';

    return Row(
      children: [
        IconButton(
          tooltip: 'Ngày trước',
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          color: Colors.white,
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _pick(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDay(day),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!nutrition.isToday)
          TextButton(
            onPressed: () => nutrition.selectDay(DateTime.now()),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Hôm nay'),
          ),
        IconButton(
          tooltip: 'Ngày sau',
          onPressed: () => _shift(1),
          icon: const Icon(Icons.chevron_right_rounded),
          color: Colors.white,
        ),
      ],
    );
  }
}

/// Thẻ gradient: vòng tiến độ calo + ba chất dinh dưỡng chính.
class _EnergyCard extends StatelessWidget {
  const _EnergyCard({
    required this.summary,
    this.title = 'Tổng calo hôm nay',
  });

  final NutritionSummary summary;
  final String title;

  @override
  Widget build(BuildContext context) {
    final remaining = summary.remainingCalories;
    final over = remaining < 0;
    final dark = Color.lerp(AppTheme.primary, Colors.black, 0.22)!;
    final ringColor = _ringColorFor(summary.rawPercent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, dark],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFFFD36A),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AnimatedNumber(
                      value: summary.calories,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'trên ${summary.calorieGoal} kcal mục tiêu',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: over
                            ? ringColor.withValues(alpha: 0.32)
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        over ? 'Vượt ${-remaining} kcal' : 'Còn $remaining kcal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                height: 104,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: ringColor),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, color, _) =>
                      TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: summary.calorieProgress,
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(104, 104),
                            painter: _RingPainter(
                              progress: value,
                              color: color ?? Colors.white,
                            ),
                          ),
                          _AnimatedNumber(
                            value: summary.rawPercent,
                            suffix: '%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _MiniMacro(
                  label: 'Protein',
                  grams: summary.protein,
                  dot: const Color(0xFFFFD36A),
                ),
                _MiniMacro(
                  label: 'Carb',
                  grams: summary.carbs,
                  dot: const Color(0xFF9CD5FF),
                ),
                _MiniMacro(
                  label: 'Fat',
                  grams: summary.fat,
                  dot: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMacro extends StatelessWidget {
  const _MiniMacro({
    required this.label,
    required this.grams,
    required this.dot,
  });

  final String label;
  final double grams;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '${grams.toStringAsFixed(0)} g',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, this.color = Colors.white});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.22);
    canvas.drawArc(arcRect, 0, 6.28319, false, track);

    final bar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, -1.5708, 6.28319 * progress.clamp(0.0, 1.0), false, bar);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}

/// Dải ảnh đầu mỗi thẻ bữa ăn (mỗi bữa một ảnh).
///
/// Ảnh đặt tại assets/images/food/meal_breakfast.jpg, meal_lunch.jpg,
/// meal_dinner.jpg và meal_snack.jpg. Nếu thiếu ảnh thì hiện dải gradient
/// theo màu của bữa để giao diện không bị trống.
class _MealBanner extends StatelessWidget {
  const _MealBanner({required this.slot});

  final MealSlot slot;

  String get _asset {
    switch (slot) {
      case MealSlot.breakfast:
        return 'assets/images/food/meal_breakfast.jpg';
      case MealSlot.lunch:
        return 'assets/images/food/meal_lunch.jpg';
      case MealSlot.dinner:
        return 'assets/images/food/meal_dinner.jpg';
      case MealSlot.snack:
        return 'assets/images/food/meal_snack.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _slotColor(slot);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 76,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _asset,
              fit: BoxFit.cover,
              cacheWidth: 900,
              errorBuilder: (_, __, ___) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [color, color.withValues(alpha: 0.55)],
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x55000000)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ một bữa ăn kèm danh sách món đã thêm.
class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.slot,
    required this.description,
    required this.calories,
    required this.totalCalories,
    required this.entries,
    required this.nutrition,
  });

  final MealSlot slot;
  final String description;
  final int calories;
  final int totalCalories;
  final List<MealEntry> entries;
  final NutritionRepository nutrition;

  @override
  Widget build(BuildContext context) {
    final color = _slotColor(slot);
    final share = totalCalories > 0 ? calories / totalCalories : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _SoftCard(
        padding: const EdgeInsets.all(14),
        radius: 20,
        child: Column(
          children: [
            _MealBanner(slot: slot),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _slotTint(slot),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(_slotIcon(slot), color: color, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _slotTint(slot),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$calories kcal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 5,
                  backgroundColor: _slotTint(slot),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 4),
              for (final entry in entries)
                _SwipeEntryRow(
                  entry: entry,
                  color: color,
                  nutrition: nutrition,
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _saveAsCombo(context),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Lưu thành combo'),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            if (entries.isEmpty) _EmptyMealHint(slot: slot),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: () => _openAddFood(context, slot: slot),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Thêm món vào ${slot.label.toLowerCase()}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lưu các món của buổi này thành một combo để lần sau chọn một chạm.
  Future<void> _saveAsCombo(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: slot.label),
    );
    if (name == null) return;
    await nutrition.saveCombo(
      userId: entries.first.userId,
      name: name,
      items: [
        for (final e in entries)
          PortionedFood(nutrition.foodFromEntry(e), e.portion),
      ],
    );
    _showToast(messenger, 'Đã lưu combo "${name.isEmpty ? 'Combo của tôi' : name}".');
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Thực đơn (tìm món Việt Nam từ Excel + quốc tế từ USDA)
// ---------------------------------------------------------------------------

enum _Source { all, vietnam, world, drink }

class _MenuTab extends StatefulWidget {
  const _MenuTab({required this.nutrition});

  final NutritionRepository nutrition;

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  static const _worldExamples = [
    'chicken breast',
    'salmon',
    'oatmeal',
    'banana',
    'greek yogurt',
    'avocado',
  ];

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  bool _showTop = false;

  _Source _source = _Source.all;
  String? _group;
  bool? _vegetarian;
  MealSlot _slot = _slotForNow();

  List<CatalogFood> _usda = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.offset > 400;
    if (show != _showTop) setState(() => _showTop = show);
  }

  void _scrollToTop() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  String get _query => _controller.text.trim();
  bool get _wantsUsda =>
      (_source == _Source.all || _source == _Source.world) && _query.length >= 2;

  void _onQueryChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _runUsda);
  }

  Future<void> _runUsda() async {
    final q = _query;
    if (!_wantsUsda) {
      if (mounted) {
        setState(() {
          _usda = const [];
          _loading = false;
          _error = null;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.nutrition.searchUsda(q);
      if (!mounted || _query != q) return;
      setState(() {
        _usda = result;
        _loading = false;
      });
    } on UsdaException catch (e) {
      if (!mounted || _query != q) return;
      setState(() {
        _usda = const [];
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted || _query != q) return;
      setState(() {
        _usda = const [];
        _loading = false;
        _error = 'Có lỗi khi tra cứu USDA.';
      });
    }
  }

  void _setSource(_Source source) {
    setState(() {
      _source = source;
      if (source == _Source.world || source == _Source.drink) {
        _group = null;
        _vegetarian = null;
      }
    });
    _runUsda();
  }

  List<String> get _groups {
    final seen = <String>[];
    for (final food in widget.nutrition.catalog) {
      if (food is CatalogFood &&
          food.source == FoodSource.vietnam &&
          food.group.isNotEmpty &&
          !seen.contains(food.group)) {
        seen.add(food.group);
      }
    }
    return seen;
  }

  List<FoodItem> get _vietnamese {
    final list = widget.nutrition.search(
      keyword: _query,
      category: FoodCategory.vietnamese,
    );
    return list.where((food) {
      if (food is! CatalogFood) return _group == null && _vegetarian == null;
      if (_group != null && food.group != _group) return false;
      if (_vegetarian != null && food.vegetarian != _vegetarian) return false;
      return true;
    }).toList();
  }

  List<FoodItem> get _world {
    final offline = widget.nutrition
        .search(keyword: _query)
        .where((food) => food.category != FoodCategory.vietnamese)
        .where((food) {
      if (_source == _Source.drink) return food.category == FoodCategory.drink;
      if (_source == _Source.world) return food.category != FoodCategory.drink;
      return true;
    });
    final names = offline.map((f) => f.name.toLowerCase()).toSet();
    return [
      ...offline,
      ..._usda.where((f) => !names.contains(f.name.toLowerCase())),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final showVietnam = _source == _Source.all || _source == _Source.vietnam;
    final showWorld = _source != _Source.vietnam;
    final vietnamese = showVietnam ? _vietnamese : const <FoodItem>[];
    final world = showWorld ? _world : const <FoodItem>[];
    final groups = _groups;
    final hasCart = widget.nutrition.cartCount > 0;

    final list = ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(20, 8, 20, hasCart ? 110 : 28),
      children: [
        _SearchField(
          controller: _controller,
          onChanged: _onQueryChanged,
          onClear: () {
            _controller.clear();
            _onQueryChanged('');
          },
        ),
        const SizedBox(height: 12),
        _CategoryTiles(
          selected: _source,
          onTap: (source) =>
              _setSource(_source == source ? _Source.all : source),
        ),
        const SizedBox(height: 14),
        _ChipRow(
          children: [
            for (final slot in MealSlot.values)
              _FilterPill(
                label: slot.label,
                icon: _slotIcon(slot),
                selected: _slot == slot,
                color: _slotColor(slot),
                onTap: () => setState(() => _slot = slot),
              ),
          ],
        ),
        if (_query.isEmpty) ..._quickSection(),
        if (showVietnam && groups.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ChipRow(
            children: [
              _FilterPill(
                label: 'Chay',
                icon: Icons.spa_rounded,
                selected: _vegetarian == true,
                color: AppTheme.primary,
                onTap: () => setState(
                  () => _vegetarian = _vegetarian == true ? null : true,
                ),
              ),
              _FilterPill(
                label: 'Mặn',
                icon: Icons.kebab_dining_rounded,
                selected: _vegetarian == false,
                color: AppTheme.orange,
                onTap: () => setState(
                  () => _vegetarian = _vegetarian == false ? null : false,
                ),
              ),
              for (final group in groups)
                _FilterPill(
                  label: group.replaceFirst('Món ', ''),
                  selected: _group == group,
                  color: AppTheme.textPrimary,
                  onTap: () => setState(
                    () => _group = _group == group ? null : group,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        if (showVietnam) ...[
          _ListHeader(
            icon: Icons.ramen_dining_rounded,
            title: 'Món Việt',
            count: vietnamese.length,
            color: AppTheme.orange,
          ),
          if (vietnamese.isEmpty)
            const _InfoBox(
              icon: Icons.search_off_rounded,
              text: 'Không tìm thấy món Việt phù hợp.',
            ),
          for (final food in vietnamese)
            _FoodRow(
              food: food,
              onTap: () => _openFoodSheet(context, food, _slot),
              inCart: widget.nutrition.cartPortionOf(food.id),
              onAdd: () => _addToCart(food),
            ),
        ],
        if (showWorld) ...[
          const SizedBox(height: 10),
          _ListHeader(
            icon: _source == _Source.drink
                ? Icons.local_cafe_rounded
                : Icons.public_rounded,
            title: _source == _Source.drink
                ? 'Đồ uống'
                : 'Món Tây & nguyên liệu · USDA',
            count: _wantsUsda || world.isNotEmpty ? world.length : null,
            color: AppTheme.blue,
            loading: _loading,
          ),
          if (_error != null)
            _InfoBox(
              icon: Icons.cloud_off_rounded,
              text: _error!,
              actionLabel: 'Thử lại',
              onAction: _runUsda,
            )
          else if (_query.length < 2 && _source != _Source.drink)
            _WorldHint(
              examples: _worldExamples,
              demoKey: widget.nutrition.usdaUsesDemoKey,
              onPick: (text) {
                _controller.text = text;
                _controller.selection =
                    TextSelection.collapsed(offset: text.length);
                _onQueryChanged(text);
              },
            ),
          if (_source == _Source.drink && world.isEmpty)
            const _InfoBox(
              icon: Icons.search_off_rounded,
              text: 'Không tìm thấy đồ uống phù hợp.',
            ),
          if (_wantsUsda && !_loading && _error == null && world.isEmpty)
            const _InfoBox(
              icon: Icons.search_off_rounded,
              text:
                  'USDA không có kết quả. Thử tên món bằng tiếng Anh, ví dụ "chicken breast".',
            ),
          for (final food in world)
            _FoodRow(
              food: food,
              onTap: () => _openFoodSheet(context, food, _slot),
              inCart: widget.nutrition.cartPortionOf(food.id),
              onAdd: () => _addToCart(food),
            ),
        ],
      ],
    );

    return Stack(
      children: [
        list,
        Positioned(
          right: 16,
          bottom: hasCart ? 88 : 16,
          child: IgnorePointer(
            ignoring: !_showTop,
            child: AnimatedScale(
              scale: _showTop ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: FloatingActionButton.small(
                heroTag: 'menu-back-to-top',
                tooltip: 'Lên đầu trang',
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                onPressed: _scrollToTop,
                child: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            ),
          ),
        ),
        if (hasCart)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: _CartBar(
              count: widget.nutrition.cartCount,
              calories: widget.nutrition.cartCalories,
              slot: _slot,
              onOpen: _openCart,
              onCommit: () => _commitCart(_slot),
            ),
          ),
      ],
    );
  }

  String _addedMessage(String what, MealSlot slot) {
    final base = 'Đã thêm $what vào ${slot.label.toLowerCase()}';
    if (widget.nutrition.isToday) return '$base.';
    return '$base · ${_formatDay(widget.nutrition.selectedDay)}.';
  }

  void _addToCart(FoodItem food) {
    HapticFeedback.selectionClick();
    widget.nutrition.addToCart(food);
  }

  Future<void> _commitCart(MealSlot slot) async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final n = widget.nutrition;
    final count = n.cartCount;
    await n.commitCart(
      userId: user.id,
      slot: slot,
      calorieGoal: user.dailyCalorieGoal,
    );
    _showToast(messenger, _addedMessage('$count món', slot));
  }

  Future<void> _openCart() async {
    final picked = await showModalBottomSheet<MealSlot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(
        nutrition: widget.nutrition,
        initialSlot: _slot,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _slot = picked);
    await _commitCart(picked);
  }

  Future<void> _repeatPrevious() async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final slot = _slot;
    final count = await widget.nutrition.repeatPreviousDay(
      userId: user.id,
      slot: slot,
      calorieGoal: user.dailyCalorieGoal,
    );
    if (count > 0) _showToast(messenger, _addedMessage('$count món', slot));
  }

  Future<void> _addCombo(MealCombo combo) async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final slot = _slot;
    await widget.nutrition.addCombo(
      userId: user.id,
      combo: combo,
      slot: slot,
      calorieGoal: user.dailyCalorieGoal,
    );
    _showToast(messenger, _addedMessage('combo ${combo.name}', slot));
  }

  Future<void> _confirmDeleteCombo(MealCombo combo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Xóa combo'),
        content: Text('Xóa combo "${combo.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.nutrition.deleteCombo(userId: combo.userId, comboId: combo.id);
  }

  /// Hàng gợi ý nhập nhanh: ăn lại bữa hôm trước, combo, món hay ăn.
  List<Widget> _quickSection() {
    final n = widget.nutrition;
    final prev = n.previousDayMeal(_slot);
    final slotDone = n.todayEntries.any((e) => e.slot == _slot);
    final showPrev = prev.isNotEmpty && !slotDone;
    final combos = n.combos;
    final frequent = n.frequentFoods;
    if (!showPrev && combos.isEmpty && frequent.isEmpty) return const [];

    return [
      const SizedBox(height: 14),
      if (showPrev)
        _RepeatMealCard(
          title: '${_slot.label} ${n.isToday ? 'hôm qua' : 'ngày trước'}',
          description: prev.map((e) => e.foodName).join(' + '),
          calories: prev.fold<int>(0, (sum, e) => sum + e.calories),
          color: _slotColor(_slot),
          onRepeat: _repeatPrevious,
        ),
      if (combos.isNotEmpty) ...[
        const SizedBox(height: 12),
        const _QuickLabel(
          icon: Icons.bookmark_rounded,
          text: 'Combo của tôi · chạm để thêm, giữ để xóa',
        ),
        const SizedBox(height: 8),
        _ChipRow(
          children: [
            for (final combo in combos)
              _QuickChip(
                label: combo.name,
                trailing: '${combo.calories} kcal',
                icon: Icons.bookmark_rounded,
                color: AppTheme.primary,
                onTap: () => _addCombo(combo),
                onLongPress: () => _confirmDeleteCombo(combo),
              ),
          ],
        ),
      ],
      if (frequent.isNotEmpty) ...[
        const SizedBox(height: 12),
        const _QuickLabel(icon: Icons.history_rounded, text: 'Hay ăn'),
        const SizedBox(height: 8),
        _ChipRow(
          children: [
            for (final food in frequent)
              _QuickChip(
                label: food.name,
                trailing: '${food.calories} kcal',
                icon: Icons.add_rounded,
                color: AppTheme.orange,
                onTap: () => _addToCart(food),
              ),
          ],
        ),
      ],
    ];
  }

  Future<void> _openFoodSheet(
    BuildContext context,
    FoodItem food,
    MealSlot slot,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FoodSheet(
        food: food,
        initialSlot: slot,
        nutrition: widget.nutrition,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _cardShadow,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Tìm món: phở, bún chả, chicken breast...',
          hintStyle: const TextStyle(
            fontSize: 13.5,
            color: AppTheme.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _SegmentedPills extends StatelessWidget {
  const _SegmentedPills({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: i == selected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(color.withValues(alpha: 0.16), Colors.white)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : const Color(0x14000000),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? color : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.count,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final Color color;
  final int? count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.white70,
              ),
            ),
          ],
          const Spacer(),
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _WorldHint extends StatelessWidget {
  const _WorldHint({
    required this.examples,
    required this.demoKey,
    required this.onPick,
  });

  final List<String> examples;
  final bool demoKey;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gõ tên món tiếng Anh để tra cứu USDA (giá trị trên 100g).',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in examples)
                GestureDetector(
                  onTap: () => onPick(e),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      e,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (demoKey) ...[
            const SizedBox(height: 10),
            const Text(
              'Đang dùng DEMO_KEY (giới hạn lượt gọi). Chạy app với --dart-define=USDA_API_KEY=... để dùng key riêng.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Một dòng món ăn.
class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.food,
    required this.onTap,
    required this.onAdd,
    this.inCart = 0,
  });

  final FoodItem food;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  /// Số phần của món này đang nằm trong giỏ (0 = chưa có).
  final double inCart;

  @override
  Widget build(BuildContext context) {
    final extra = food is CatalogFood ? food as CatalogFood : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: _cardShadow,
            ),
            child: Row(
              children: [
                FoodThumb(
                  food: food,
                  size: 52,
                  radius: 16,
                  background: _foodTint(food),
                  fallback: Icon(
                    _foodIcon(food),
                    color: _foodColor(food),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${food.calories} kcal · ${food.servingLabel}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _MacroTag('P', food.protein, AppTheme.primary),
                          const SizedBox(width: 6),
                          _MacroTag('C', food.carbs, AppTheme.blue),
                          const SizedBox(width: 6),
                          _MacroTag('F', food.fat, AppTheme.orange),
                          if (extra != null && extra.vegetarian) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.spa_rounded,
                              size: 14,
                              color: AppTheme.primary,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: inCart > 0 ? AppTheme.primary : AppTheme.lightGreen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAdd,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: Center(
                          child: inCart > 0
                              ? Text(
                                  _portionNumber(inCart),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_rounded,
                                  color: AppTheme.primary,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MacroTag extends StatelessWidget {
  const _MacroTag(this.letter, this.grams, this.color);

  final String letter;
  final num grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$letter ${_grams(grams.toDouble())}g',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet chi tiết món: chọn khẩu phần, bữa ăn rồi thêm vào nhật ký
// ---------------------------------------------------------------------------

class _FoodSheet extends StatefulWidget {
  const _FoodSheet({
    required this.food,
    required this.initialSlot,
    required this.nutrition,
  });

  final FoodItem food;
  final MealSlot initialSlot;
  final NutritionRepository nutrition;

  @override
  State<_FoodSheet> createState() => _FoodSheetState();
}

class _FoodSheetState extends State<_FoodSheet> {
  static const _portions = [0.5, 1.0, 1.5, 2.0];

  late MealSlot _slot = widget.initialSlot;
  double _portion = 1;
  bool _saving = false;

  /// Calo do người dùng tự nhập (null = tính theo khẩu phần).
  int? _customKcal;

  /// Ngày ăn. Mặc định là ngày đang xem; chọn ngày khác để lên lịch trước.
  late DateTime _day = widget.nutrition.selectedDay;

  FoodItem get food => widget.food;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isTodaySel => _dayOnly(_day) == _dayOnly(DateTime.now());
  bool get _isTomorrowSel =>
      _dayOnly(_day) == _dayOnly(DateTime.now().add(const Duration(days: 1)));

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Chọn ngày ăn',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null && mounted) setState(() => _day = _dayOnly(picked));
  }

  Future<void> _editKcal(int baseKcal) async {
    final v = await showDialog<int>(
      context: context,
      builder: (_) => _KcalDialog(initial: _customKcal ?? baseKcal),
    );
    if (v == null || !mounted) return;
    setState(() => _customKcal = v == baseKcal ? null : v);
  }

  String _portionLabel(double p) {
    final grams = food is CatalogFood ? (food as CatalogFood).servingGrams : null;
    if (_isUsda(food) && grams != null) return '${(grams * p).round()}g';
    switch (p) {
      case 0.5:
        return '½ phần';
      case 1.5:
        return '1½ phần';
      default:
        return '${p.toStringAsFixed(0)} phần';
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = food is CatalogFood ? food as CatalogFood : null;
    final baseKcal = (food.calories * _portion).round();
    final kcal = _customKcal ?? baseKcal;
    // Tự nhập calo thì protein/carb/fat/vi chất co giãn theo cùng tỉ lệ.
    final k = (_customKcal != null && food.calories * _portion > 0)
        ? _customKcal! / (food.calories * _portion)
        : 1.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x26000000),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: FoodThumb(
                        food: food,
                        size: 170,
                        width: double.infinity,
                        radius: 22,
                        cacheWidth: 900,
                        background: _foodTint(food),
                        fallback: Icon(
                          _foodIcon(food),
                          color: _foodColor(food),
                          size: 56,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (extra != null &&
                                      extra.source == FoodSource.vietnam)
                                    _Badge(
                                      extra.vegetarian ? 'Món chay' : 'Món mặn',
                                      extra.vegetarian
                                          ? AppTheme.primary
                                          : AppTheme.orange,
                                    ),
                                  if (extra != null && extra.group.isNotEmpty)
                                    _Badge(extra.group, AppTheme.textSecondary),
                                  if (_isUsda(food))
                                    _Badge('USDA · 100g', AppTheme.blue),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SoftCard(
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$kcal',
                                style: const TextStyle(
                                  fontSize: 38,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(left: 6, bottom: 4),
                                child: Text(
                                  'kcal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkResponse(
                                onTap: () => _editKcal(baseKcal),
                                radius: 20,
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_customKcal != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Đã chỉnh tay · gốc $baseKcal kcal',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _customKcal = null),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    visualDensity: VisualDensity.compact,
                                    textStyle: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: const Text('Đặt lại'),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _SheetMacro(
                                'Protein',
                                food.protein * _portion * k,
                                AppTheme.primary,
                                AppTheme.lightGreen,
                              ),
                              const SizedBox(width: 10),
                              _SheetMacro(
                                'Carb',
                                food.carbs * _portion * k,
                                AppTheme.blue,
                                AppTheme.lightBlue,
                              ),
                              const SizedBox(width: 10),
                              _SheetMacro(
                                'Fat',
                                food.fat * _portion * k,
                                AppTheme.orange,
                                AppTheme.lightOrange,
                              ),
                            ],
                          ),
                          if (extra != null &&
                              (extra.fiber != null ||
                                  extra.calcium != null ||
                                  extra.iron != null)) ...[
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                if (extra.fiber != null)
                                  _Micro('Chất xơ',
                                      '${_grams(extra.fiber! * _portion * k)} g'),
                                if (extra.calcium != null)
                                  _Micro('Canxi',
                                      '${(extra.calcium! * _portion * k).round()} mg'),
                                if (extra.iron != null)
                                  _Micro('Sắt',
                                      '${_grams(extra.iron! * _portion * k)} mg'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Khẩu phần',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final p in _portions) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _portion = p;
                                _customKcal = null;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: _portion == p
                                      ? AppTheme.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: _portion == p
                                        ? AppTheme.primary
                                        : const Color(0x14000000),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _portionLabel(p),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _portion == p
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (p != _portions.last) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Thêm vào bữa',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ChipRow(
                      children: [
                        for (final slot in MealSlot.values)
                          _FilterPill(
                            label: slot.label,
                            icon: _slotIcon(slot),
                            selected: _slot == slot,
                            color: _slotColor(slot),
                            onTap: () => setState(() => _slot = slot),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Ngày ăn',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mặc định là ngày đang xem. Chọn ngày khác nếu muốn lên lịch trước (không bắt buộc).',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ChipRow(
                      children: [
                        _FilterPill(
                          label: 'Hôm nay',
                          icon: Icons.today_rounded,
                          selected: _isTodaySel,
                          color: AppTheme.primary,
                          onTap: () =>
                              setState(() => _day = _dayOnly(DateTime.now())),
                        ),
                        _FilterPill(
                          label: 'Ngày mai',
                          icon: Icons.event_rounded,
                          selected: _isTomorrowSel,
                          color: AppTheme.primary,
                          onTap: () => setState(
                            () => _day = _dayOnly(
                              DateTime.now().add(const Duration(days: 1)),
                            ),
                          ),
                        ),
                        _FilterPill(
                          label: (_isTodaySel || _isTomorrowSel)
                              ? 'Chọn ngày…'
                              : _formatDay(_day),
                          icon: Icons.calendar_month_rounded,
                          selected: !_isTodaySel && !_isTomorrowSel,
                          color: AppTheme.primary,
                          onTap: _pickDay,
                        ),
                      ],
                    ),
                    if (extra != null && extra.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Thành phần',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in extra.ingredients)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0x14000000),
                                ),
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (_isUsda(food)) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Nguồn: USDA FoodData Central. Giá trị tham khảo cho thực phẩm chưa chế biến thêm.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded),
                      label: Text(
                        '${_isTodaySel ? 'Thêm vào' : 'Lên lịch'} ${_slot.label.toLowerCase()} · $kcal kcal',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final now = DateTime.now();
    final day = _dayOnly(_day);
    final isToday = day == _dayOnly(now);
    await widget.nutrition.addFood(
      userId: user.id,
      food: food,
      slot: _slot,
      calorieGoal: user.dailyCalorieGoal,
      portion: _portion,
      customCalories: _customKcal,
      eatenAt: DateTime(day.year, day.month, day.day, now.hour, now.minute),
    );

    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            isToday
                ? 'Đã thêm ${food.name} (${_portionLabel(_portion)}) vào ${_slot.label.toLowerCase()}.'
                : 'Đã lên lịch ${food.name} vào ${_slot.label.toLowerCase()} · ${_formatDay(day)}.',
          ),
          action: isToday
              ? null
              : SnackBarAction(
                  label: 'Xem ngày',
                  onPressed: () => widget.nutrition.selectDay(day),
                ),
        ),
      );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SheetMacro extends StatelessWidget {
  const _SheetMacro(this.label, this.grams, this.color, this.background);

  final String label;
  final num grams;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '${_grams(grams.toDouble())} g',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Micro extends StatelessWidget {
  const _Micro(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Thống kê
// ---------------------------------------------------------------------------

class _StatsTab extends StatefulWidget {
  const _StatsTab({required this.nutrition});

  final NutritionRepository nutrition;

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab>
    with AutomaticKeepAliveClientMixin {
  /// 0 = Ngày, 1 = Tuần, 2 = Tháng.
  int _range = 0;

  NutritionRepository get nutrition => widget.nutrition;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final summary = nutrition.summary;

    return _ScrollTopView(
      builder: (scroll) => ListView(
        controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            _range != 0
                ? 'Kết thúc ngày ${_formatDay(nutrition.selectedDay)}'
                : nutrition.isToday
                    ? 'Thống kê hôm nay'
                    : 'Thống kê ${_formatDay(nutrition.selectedDay)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),
        _SegmentedPills(
          labels: const ['Ngày', 'Tuần', 'Tháng'],
          selected: _range,
          onChanged: (i) => setState(() => _range = i),
        ),
        const SizedBox(height: 14),
        if (_range != 0) ...[
          _WeekChartCard(
            key: ValueKey(_range),
            nutrition: nutrition,
            days: _range == 1 ? 7 : 30,
          ),
          const SizedBox(height: 16),
          _WaterChartCard(
            key: ValueKey('water$_range'),
            nutrition: nutrition,
            days: _range == 1 ? 7 : 30,
          ),
        ] else if (summary.calories == 0) ...[
          const _StatsEmptyCard(),
        ] else ...[
          _SoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phân bố dinh dưỡng',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(132, 132),
                            painter: _MacroPiePainter(
                              proteinPercent: summary.proteinPercent,
                              carbsPercent: summary.carbsPercent,
                              fatPercent: summary.fatPercent,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${summary.calories}',
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Text(
                                'kcal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          _LegendRow(
                            color: AppTheme.primary,
                            label: 'Protein',
                            percent: summary.proteinPercent,
                          ),
                          const SizedBox(height: 12),
                          _LegendRow(
                            color: AppTheme.blue,
                            label: 'Carb',
                            percent: summary.carbsPercent,
                          ),
                          const SizedBox(height: 12),
                          _LegendRow(
                            color: AppTheme.orange,
                            label: 'Fat',
                            percent: summary.fatPercent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MacroCard(
                  label: 'Protein',
                  value: '${summary.protein.toStringAsFixed(0)} g',
                  color: AppTheme.primary,
                  background: AppTheme.lightGreen,
                  icon: Icons.egg_alt_rounded,
                  percent: summary.proteinPercent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MacroCard(
                  label: 'Carb',
                  value: '${summary.carbs.toStringAsFixed(0)} g',
                  color: AppTheme.blue,
                  background: AppTheme.lightBlue,
                  icon: Icons.bakery_dining_rounded,
                  percent: summary.carbsPercent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MacroCard(
                  label: 'Fat',
                  value: '${summary.fat.toStringAsFixed(0)} g',
                  color: AppTheme.orange,
                  background: AppTheme.lightOrange,
                  icon: Icons.opacity_rounded,
                  percent: summary.fatPercent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Theo bữa ăn',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'Mục tiêu ${summary.calorieGoal} kcal',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SlotBar(nutrition: nutrition, total: summary.calories),
                const SizedBox(height: 14),
                for (final slot in MealSlot.values)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _slotColor(slot),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            slot.label,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${nutrition.mealCalories(slot)} kcal',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_range == 0 && summary.calories > 0) ...[
          const SizedBox(height: 16),
          _InsightCard(summary: summary),
        ],
        if (_range == 0) ...[
          const SizedBox(height: 16),
          _WaterDayStatsCard(nutrition: nutrition),
        ],
      ],
    ),
    );
  }
}

/// Khối hiển thị khi ngày đang xem chưa có món nào.
class _StatsEmptyCard extends StatelessWidget {
  const _StatsEmptyCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        children: [
          const _HungryBowl(size: 96),
          const SizedBox(height: 12),
          const Text(
            'Bụng đang réo kìa! Bạn đã ăn gì chưa?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thêm món ăn để xem biểu đồ phân bố chất dinh dưỡng và calo theo từng bữa.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: () => _openAddFood(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Thêm món ăn'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Biểu đồ cột calo [days] ngày kết thúc ở ngày đang xem (7 = tuần, 30 =
/// tháng) kèm đường nét đứt "Mục tiêu". Bấm vào một cột để xem ngày đó.
class _WeekChartCard extends StatefulWidget {
  const _WeekChartCard({
    super.key,
    required this.nutrition,
    this.days = 7,
  });

  final NutritionRepository nutrition;
  final int days;

  @override
  State<_WeekChartCard> createState() => _WeekChartCardState();
}

class _WeekChartCardState extends State<_WeekChartCard> {
  List<DayCalories> _data = const [];
  String _lastKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _WeekChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  void _refresh() {
    final n = widget.nutrition;
    final key =
        '${widget.days}-${n.selectedDay.millisecondsSinceEpoch}-${n.summary.calories}-${n.todayEntries.length}';
    if (key == _lastKey) return;
    _lastKey = key;
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    n.caloriesLastDays(user.id, n.selectedDay, days: widget.days).then((data) {
      if (mounted) setState(() => _data = data);
    });
  }

  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final n = widget.nutrition;
    final goal = n.summary.calorieGoal;
    final compact = widget.days > 7;
    final withData = _data.where((d) => d.calories > 0).toList();
    final average = withData.isEmpty
        ? 0
        : (withData.fold<int>(0, (a, d) => a + d.calories) / withData.length)
            .round();
    final overDays = withData.where((d) => d.calories > goal).length;
    final okDays = withData.length - overDays;

    var maxValue = goal;
    for (final d in _data) {
      if (d.calories > maxValue) maxValue = d.calories;
    }
    if (maxValue <= 0) maxValue = 1;

    const chartHeight = 112.0;
    const labelArea = 22.0;
    final lineBottom = labelArea + chartHeight * (goal / maxValue);

    return _SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  compact ? '30 ngày gần nhất' : '7 ngày gần nhất',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (withData.isEmpty)
                const Text(
                  'Chưa có dữ liệu',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight + 44,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < _data.length; i++)
                      Expanded(
                        child: _WeekBar(
                          data: _data[i],
                          maxValue: maxValue,
                          chartHeight: chartHeight,
                          goal: goal,
                          compact: compact,
                          selected: _data[i].day == n.selectedDay,
                          label: compact
                              ? ((_data.length - 1 - i) % 5 == 0
                                  ? '${_data[i].day.day}'
                                  : '')
                              : _weekdays[_data[i].day.weekday - 1],
                          onTap: () => n.selectDay(_data[i].day),
                        ),
                      ),
                  ],
                ),
                if (goal > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: lineBottom,
                    child: IgnorePointer(
                      child: CustomPaint(
                        size: const Size(double.infinity, 1),
                        painter: _DashedLinePainter(
                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                if (goal > 0)
                  Positioned(
                    left: 0,
                    bottom: lineBottom + 2,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Mục tiêu $goal',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RangeStat(
                  label: 'Trung bình',
                  value: '$average kcal',
                  color: AppTheme.textPrimary,
                ),
              ),
              Expanded(
                child: _RangeStat(
                  label: 'Đạt mục tiêu',
                  value: '$okDays ngày',
                  color: AppTheme.primary,
                ),
              ),
              Expanded(
                child: _RangeStat(
                  label: 'Vượt mục tiêu',
                  value: '$overDays ngày',
                  color: overDays > 0 ? AppTheme.orange : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Đường nét đứt là mục tiêu. Cột cam là ngày vượt mục tiêu. Bấm vào cột để xem ngày đó.',
            style: TextStyle(
              fontSize: 10.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeStat extends StatelessWidget {
  const _RangeStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.data,
    required this.maxValue,
    required this.chartHeight,
    required this.goal,
    required this.selected,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final DayCalories data;
  final int maxValue;
  final double chartHeight;
  final int goal;
  final bool selected;
  final bool compact;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final over = goal > 0 && data.calories > goal;
    final base = over ? AppTheme.orange : AppTheme.primary;
    final barHeight = data.calories <= 0
        ? 3.0
        : (chartHeight * data.calories / maxValue).clamp(6.0, chartHeight);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!compact && data.calories > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${data.calories}',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color:
                      selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ),
          Container(
            width: compact ? 5 : 18,
            height: barHeight,
            decoration: BoxDecoration(
              color: data.calories <= 0
                  ? AppTheme.textSecondary.withValues(alpha: 0.2)
                  : base.withValues(alpha: selected ? 1 : 0.55),
              borderRadius: BorderRadius.circular(compact ? 3 : 6),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 16,
            child: OverflowBox(
              maxWidth: 40,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 0 : 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: selected && !compact
                      ? AppTheme.primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 9 : 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SlotBar extends StatelessWidget {
  const _SlotBar({required this.nutrition, required this.total});

  final NutritionRepository nutrition;
  final int total;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    if (total > 0) {
      for (final slot in MealSlot.values) {
        final kcal = nutrition.mealCalories(slot);
        if (kcal <= 0) continue;
        if (parts.isNotEmpty) parts.add(const SizedBox(width: 3));
        parts.add(
          Expanded(
            flex: kcal,
            child: Container(color: _slotColor(slot)),
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 14,
        child: parts.isEmpty
            ? Container(color: AppTheme.background)
            : Row(children: parts),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.summary});

  final NutritionSummary summary;

  @override
  Widget build(BuildContext context) {
    final String text;
    final IconData icon;
    final Color color;

    if (summary.calories == 0) {
      text = 'Thêm món ăn đầu tiên để xem phân tích dinh dưỡng của bạn.';
      icon = Icons.tips_and_updates_rounded;
      color = AppTheme.blue;
    } else if (summary.calorieProgress >= 1 &&
        summary.remainingCalories < 0) {
      text = 'Bạn đã vượt mục tiêu calo hôm nay. Cân nhắc bữa nhẹ cho phần còn lại.';
      icon = Icons.warning_amber_rounded;
      color = AppTheme.orange;
    } else if (summary.proteinPercent < 0.15) {
      text = 'Protein còn thấp. Thử thêm trứng, đậu phụ hoặc ức gà vào bữa tới.';
      icon = Icons.egg_alt_rounded;
      color = AppTheme.primary;
    } else if (summary.fatPercent > 0.4) {
      text = 'Chất béo hơi cao. Ưu tiên món luộc, hấp hoặc canh cho bữa tiếp theo.';
      icon = Icons.opacity_rounded;
      color = AppTheme.orange;
    } else {
      text = 'Tỉ lệ dinh dưỡng khá cân đối. Tiếp tục phát huy nhé!';
      icon = Icons.thumb_up_alt_rounded;
      color = AppTheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.92),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ba thẻ số liệu nhóm chất.
class _MacroCard extends StatelessWidget {
  const _MacroCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    required this.icon,
    required this.percent,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;
  final IconData icon;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      radius: 18,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '${(percent * 100).round()}% calo',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng chú thích cho biểu đồ tròn.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          '${(percent * 100).round()}%',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Biểu đồ tròn tỉ lệ các nhóm chất, vẽ bằng [CustomPaint].
class _MacroPiePainter extends CustomPainter {
  _MacroPiePainter({
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });

  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.17;
    final arcRect = rect.deflate(strokeWidth / 2);
    final total = proteinPercent + carbsPercent + fatPercent;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Chưa có dữ liệu: vẽ một vòng xám nhạt thay vì biểu đồ rỗng.
    if (total <= 0) {
      canvas.drawArc(
        arcRect,
        0,
        6.28319,
        false,
        paint..color = AppTheme.background,
      );
      return;
    }

    const gap = 0.05;
    var currentAngle = -1.5708 + gap / 2;

    void drawSlice(double percent, Color color) {
      if (percent <= 0) return;
      final sweep = (percent / total) * 6.28319;
      canvas.drawArc(
        arcRect,
        currentAngle,
        (sweep - gap).clamp(0.01, 6.28319).toDouble(),
        false,
        paint..color = color,
      );
      currentAngle += sweep;
    }

    drawSlice(proteinPercent, AppTheme.primary);
    drawSlice(carbsPercent, AppTheme.blue);
    drawSlice(fatPercent, AppTheme.orange);
  }

  @override
  bool shouldRepaint(covariant _MacroPiePainter oldDelegate) {
    return oldDelegate.proteinPercent != proteinPercent ||
        oldDelegate.carbsPercent != carbsPercent ||
        oldDelegate.fatPercent != fatPercent;
  }
}

/// Mở màn hình thêm món ăn.
Future<void> _openAddFood(BuildContext context, {MealSlot? slot}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AddFoodScreen(initialSlot: slot ?? MealSlot.breakfast),
    ),
  );
}


/// Hộp thoại nhập calo. Tự giữ TextEditingController để không bị hủy sớm
/// khi hộp thoại còn đang chạy hiệu ứng đóng.
class _KcalDialog extends StatefulWidget {
  const _KcalDialog({required this.initial});

  final int initial;

  @override
  State<_KcalDialog> createState() => _KcalDialogState();
}

class _KcalDialogState extends State<_KcalDialog> {
  late final TextEditingController _c =
      TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = int.tryParse(_c.text.trim());
    if (v == null || v < 0 || v > 5000) {
      setState(() => _error = 'Nhập số từ 0 đến 5000.');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Chỉnh calo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              suffixText: 'kcal',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Protein, carb và fat sẽ tự điều chỉnh theo cùng tỉ lệ.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        TextButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}

/// Bọc một danh sách cuộn: hiện nút tròn "lên đầu trang" khi đã cuộn xa.
class _ScrollTopView extends StatefulWidget {
  const _ScrollTopView({required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<_ScrollTopView> createState() => _ScrollTopViewState();
}

class _ScrollTopViewState extends State<_ScrollTopView> {
  final _scroll = ScrollController();
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 400;
      if (show != _show) setState(() => _show = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.builder(_scroll),
        Positioned(
          right: 16,
          bottom: 16,
          child: IgnorePointer(
            ignoring: !_show,
            child: AnimatedScale(
              scale: _show ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Lên đầu trang',
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                onPressed: () => _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                ),
                child: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Nhập liệu nhanh: giỏ món, combo, ăn lại, vuốt xóa, sửa món, uống nước
// ---------------------------------------------------------------------------

void _showToast(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(text),
      ),
    );
}

/// 1 -> "1", 1.5 -> "1,5" (số hiển thị trên nút giỏ).
String _portionNumber(double p) {
  return p % 1 == 0 ? '${p.toInt()}' : p.toStringAsFixed(1).replaceAll('.', ',');
}

String _portionText(double p) => '${_portionNumber(p)} phần';

String _liters(int ml) {
  final l = ml / 1000;
  final text = ml % 100 == 0 ? l.toStringAsFixed(1) : l.toStringAsFixed(2);
  return text.replaceAll('.', ',');
}

/// Thẻ nước uống: hiện tiến độ trong ngày. Bấm vào thẻ (hoặc nút "Thêm") để
/// mở màn hình nước uống riêng, nơi chọn lượng nước cần thêm.
class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.nutrition});

  final NutritionRepository nutrition;

  Future<void> _openScreen(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WaterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context, listen: false).currentUser;
    final goal = NutritionRepository.waterGoalFor(user?.weightKg ?? 55);
    final ml = nutrition.waterMl;
    final progress = (ml / goal).clamp(0.0, 1.0).toDouble();
    final done = ml >= goal;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openScreen(context),
      child: _SoftCard(
        padding: const EdgeInsets.all(14),
        radius: 20,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                color: AppTheme.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nước uống',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_liters(ml)} / ${_liters(goal)} L${done ? ' · Đạt mục tiêu' : ''}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppTheme.lightBlue,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppTheme.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 2),
                  Text(
                    'Thêm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
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

/// Thống kê nước của một ngày (tab Thống kê, chế độ Ngày).
class _WaterDayStatsCard extends StatelessWidget {
  const _WaterDayStatsCard({required this.nutrition});

  final NutritionRepository nutrition;

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context, listen: false).currentUser;
    final goal = NutritionRepository.waterGoalFor(user?.weightKg ?? 55);
    final ml = nutrition.waterMl;
    final progress = (ml / goal).clamp(0.0, 1.0).toDouble();
    final percent = (ml * 100 / goal).round();
    final remain = goal - ml;
    final glasses = (remain / 250).ceil();

    final tip = ml == 0
        ? 'Chưa ghi nhận ly nước nào. Uống một ly để bắt đầu nhé.'
        : remain <= 0
            ? 'Đã đạt mục tiêu nước. Giữ nhịp này nhé!'
            : 'Còn thiếu ${_liters(remain)} L, khoảng $glasses ly nữa.';

    return _SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: AppTheme.blue,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Nước uống',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                'Mục tiêu ${_liters(goal)} L',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _liters(ml),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  'L',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.lightBlue,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.blue),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tip,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Biểu đồ cột nước [days] ngày kết thúc ở ngày đang xem (tab Thống kê, chế độ
/// Tuần/Tháng) kèm đường nét đứt mục tiêu. Bấm vào cột để xem ngày đó.
class _WaterChartCard extends StatefulWidget {
  const _WaterChartCard({
    super.key,
    required this.nutrition,
    this.days = 7,
  });

  final NutritionRepository nutrition;
  final int days;

  @override
  State<_WaterChartCard> createState() => _WaterChartCardState();
}

class _WaterChartCardState extends State<_WaterChartCard> {
  List<DayWater> _data = const [];
  String _lastKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _WaterChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  void _refresh() {
    final n = widget.nutrition;
    final key =
        '${widget.days}-${n.selectedDay.millisecondsSinceEpoch}-${n.waterMl}';
    if (key == _lastKey) return;
    _lastKey = key;
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    n.waterLastDays(user.id, n.selectedDay, days: widget.days).then((data) {
      if (mounted) setState(() => _data = data);
    });
  }

  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final n = widget.nutrition;
    final user = AuthScope.of(context, listen: false).currentUser;
    final goal = NutritionRepository.waterGoalFor(user?.weightKg ?? 55);
    final compact = widget.days > 7;
    final withData = _data.where((d) => d.ml > 0).toList();
    final total = withData.fold<int>(0, (a, d) => a + d.ml);
    final average = withData.isEmpty ? 0 : (total / withData.length).round();
    final okDays = withData.where((d) => d.ml >= goal).length;

    var maxValue = goal;
    for (final d in _data) {
      if (d.ml > maxValue) maxValue = d.ml;
    }
    if (maxValue <= 0) maxValue = 1;

    const chartHeight = 112.0;
    const labelArea = 22.0;
    final lineBottom = labelArea + chartHeight * (goal / maxValue);

    return _SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: AppTheme.blue,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  compact ? 'Nước uống 30 ngày' : 'Nước uống 7 ngày',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (withData.isEmpty)
                const Text(
                  'Chưa có dữ liệu',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight + 44,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < _data.length; i++)
                      Expanded(
                        child: _WaterBar(
                          data: _data[i],
                          maxValue: maxValue,
                          chartHeight: chartHeight,
                          goal: goal,
                          compact: compact,
                          selected: _data[i].day == n.selectedDay,
                          label: compact
                              ? ((_data.length - 1 - i) % 5 == 0
                                  ? '${_data[i].day.day}'
                                  : '')
                              : _weekdays[_data[i].day.weekday - 1],
                          onTap: () => n.selectDay(_data[i].day),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: lineBottom,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DashedLinePainter(
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: lineBottom + 2,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Mục tiêu ${_liters(goal)} L',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RangeStat(
                  label: 'Trung bình',
                  value: '${_liters(average)} L',
                  color: AppTheme.textPrimary,
                ),
              ),
              Expanded(
                child: _RangeStat(
                  label: 'Đạt mục tiêu',
                  value: '$okDays ngày',
                  color: AppTheme.blue,
                ),
              ),
              Expanded(
                child: _RangeStat(
                  label: 'Tổng cộng',
                  value: '${_liters(total)} L',
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Đường nét đứt là mục tiêu. Cột đậm là ngày đạt mục tiêu. Bấm vào cột để xem ngày đó.',
            style: TextStyle(
              fontSize: 10.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterBar extends StatelessWidget {
  const _WaterBar({
    required this.data,
    required this.maxValue,
    required this.chartHeight,
    required this.goal,
    required this.selected,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final DayWater data;
  final int maxValue;
  final double chartHeight;
  final int goal;
  final bool selected;
  final bool compact;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reached = data.ml >= goal;
    final barHeight = data.ml <= 0
        ? 3.0
        : (chartHeight * data.ml / maxValue).clamp(6.0, chartHeight);
    final alpha = reached ? 1.0 : (selected ? 0.85 : 0.45);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!compact && data.ml > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                _liters(data.ml),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color:
                      selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ),
          Container(
            width: compact ? 5 : 18,
            height: barHeight,
            decoration: BoxDecoration(
              color: data.ml <= 0
                  ? AppTheme.textSecondary.withValues(alpha: 0.2)
                  : AppTheme.blue.withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(compact ? 3 : 6),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 16,
            child: OverflowBox(
              maxWidth: 40,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 0 : 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: selected && !compact
                      ? AppTheme.blue.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 9 : 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? AppTheme.blue : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng món trong thẻ bữa ăn: vuốt sang trái để xóa, chạm để sửa.
class _SwipeEntryRow extends StatelessWidget {
  const _SwipeEntryRow({
    required this.entry,
    required this.color,
    required this.nutrition,
  });

  final MealEntry entry;
  final Color color;
  final NutritionRepository nutrition;

  void _remove(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final goal = nutrition.summary.calorieGoal;
    final removed = entry;
    nutrition.removeEntry(
      userId: removed.userId,
      entryId: removed.id,
      calorieGoal: goal,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text('Đã xóa ${removed.foodName}.'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () =>
                nutrition.restoreEntry(entry: removed, calorieGoal: goal),
          ),
        ),
      );
  }

  Future<void> _edit(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditEntrySheet(entry: entry, nutrition: nutrition),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _remove(context),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppTheme.danger,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Xóa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: () => _edit(context),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${entry.foodName} · ${entry.portionLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.calories} kcal',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet sửa một dòng nhật ký: đổi sang món khác và/hoặc đổi khẩu phần.
class _EditEntrySheet extends StatefulWidget {
  const _EditEntrySheet({required this.entry, required this.nutrition});

  final MealEntry entry;
  final NutritionRepository nutrition;

  @override
  State<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<_EditEntrySheet> {
  final _controller = TextEditingController();
  late double _portion = widget.entry.portion;
  FoodItem? _picked;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FoodItem> get _results {
    final q = _controller.text.trim();
    if (q.isEmpty && widget.nutrition.frequentFoods.isNotEmpty) {
      return widget.nutrition.frequentFoods;
    }
    return widget.nutrition.search(keyword: q).take(40).toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final n = widget.nutrition;
    await n.replaceEntryFood(
      entry: widget.entry,
      food: _picked ?? n.foodFromEntry(widget.entry),
      portion: _portion,
      calorieGoal: n.summary.calorieGoal,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final results = _results;
    final changed = _picked != null || _portion != widget.entry.portion;

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + media.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Sửa món · ${widget.entry.slot.label}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _picked == null
                  ? 'Đang là: ${widget.entry.foodName}'
                  : 'Đổi thành: ${_picked!.name} · ${_picked!.calories} kcal/phần',
              style: TextStyle(
                fontSize: 12.5,
                color: _picked == null
                    ? AppTheme.textSecondary
                    : AppTheme.primary,
                fontWeight:
                    _picked == null ? FontWeight.normal : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Khẩu phần',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textPrimary)),
                const Spacer(),
                IconButton(
                  onPressed: _portion > 0.5
                      ? () => setState(() => _portion -= 0.5)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    _portionText(_portion),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _portion += 0.5),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm món khác để thay thế...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final food = results[i];
                  final selected = _picked?.id == food.id;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    selected: selected,
                    selectedTileColor: AppTheme.lightGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(food.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle:
                        Text('${food.calories} kcal · ${food.servingLabel}'),
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppTheme.primary)
                        : null,
                    onTap: () => setState(() => _picked = food),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: (!changed || _saving) ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Lưu thay đổi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại đặt tên combo. Tự giữ TextEditingController để không bị hủy sớm.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Lưu thành combo'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Ví dụ: Bữa sáng quen thuộc',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _QuickLabel extends StatelessWidget {
  const _QuickLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.trailing,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final String trailing;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ "Bữa sáng hôm qua": một chạm để chép nguyên bữa.
class _RepeatMealCard extends StatelessWidget {
  const _RepeatMealCard({
    required this.title,
    required this.description,
    required this.calories,
    required this.color,
    required this.onRepeat,
  });

  final String title;
  final String description;
  final int calories;
  final Color color;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      radius: 18,
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title · $calories kcal',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onRepeat,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            child: const Text('Ăn lại'),
          ),
        ],
      ),
    );
  }
}

/// Thanh giỏ món nằm sát đáy màn hình thực đơn.
class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.count,
    required this.calories,
    required this.slot,
    required this.onOpen,
    required this.onCommit,
  });

  final int count;
  final int calories;
  final MealSlot slot;
  final VoidCallback onOpen;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary,
      elevation: 8,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_basket_rounded,
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$count món · $calories kcal',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Chạm để xem giỏ',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onCommit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              child: Text('Thêm vào ${slot.label.toLowerCase()}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet xem giỏ: chỉnh số phần, chọn bữa, lưu combo, "Thêm tất cả vào bữa".
class _CartSheet extends StatefulWidget {
  const _CartSheet({required this.nutrition, required this.initialSlot});

  final NutritionRepository nutrition;
  final MealSlot initialSlot;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  late MealSlot _slot = widget.initialSlot;

  Future<void> _saveCombo() async {
    final user = AuthScope.of(context, listen: false).currentUser;
    final items = widget.nutrition.cart;
    if (user == null || items.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: _slot.label),
    );
    if (name == null) return;
    await widget.nutrition.saveCombo(
      userId: user.id,
      name: name,
      items: items,
    );
    _showToast(messenger, 'Đã lưu combo "${name.isEmpty ? 'Combo của tôi' : name}".');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ListenableBuilder(
      listenable: widget.nutrition,
      builder: (context, _) {
        final cart = widget.nutrition.cart;
        return Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Giỏ món (${cart.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (cart.isNotEmpty)
                      TextButton(
                        onPressed: widget.nutrition.clearCart,
                        child: const Text('Xóa hết'),
                      ),
                  ],
                ),
                if (cart.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Giỏ đang trống. Bấm + cạnh món để thêm.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in cart)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.food.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${item.calories} kcal · ${_portionText(item.portion)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    widget.nutrition.setCartPortion(
                                  item.food.id,
                                  item.portion - 0.5,
                                ),
                                icon: Icon(
                                  item.portion <= 0.5
                                      ? Icons.delete_outline_rounded
                                      : Icons.remove_circle_outline_rounded,
                                  color: item.portion <= 0.5
                                      ? AppTheme.danger
                                      : null,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    widget.nutrition.setCartPortion(
                                  item.food.id,
                                  item.portion + 0.5,
                                ),
                                icon: const Icon(
                                    Icons.add_circle_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _ChipRow(
                  children: [
                    for (final slot in MealSlot.values)
                      _FilterPill(
                        label: slot.label,
                        icon: _slotIcon(slot),
                        selected: _slot == slot,
                        color: _slotColor(slot),
                        onTap: () => setState(() => _slot = slot),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: cart.isEmpty ? null : _saveCombo,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('Lưu combo'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton(
                          onPressed: cart.isEmpty
                              ? null
                              : () => Navigator.of(context).pop(_slot),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                          ),
                          child: Text(
                              'Thêm tất cả vào ${_slot.label.toLowerCase()}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Thẩm mỹ: vòng calo đổi màu, nhảy số, minh hoạ trống, banner danh mục
// ---------------------------------------------------------------------------

/// Màu vòng tiến độ: trắng khi trong mục tiêu, cam khi vượt nhẹ, đỏ khi vượt
/// nhiều (trên 115%).
Color _ringColorFor(int percent) {
  if (percent > 115) return const Color(0xFFFF6B5E);
  if (percent > 100) return const Color(0xFFFFC857);
  return Colors.white;
}

/// Số "nhảy" mượt tới giá trị mới mỗi khi [value] đổi. Lần dựng đầu hiện ngay.
class _AnimatedNumber extends StatelessWidget {
  const _AnimatedNumber({
    required this.value,
    required this.style,
    this.suffix = '',
  });

  final int value;
  final TextStyle style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Lời nhắn dễ thương cho từng bữa khi chưa có món nào.
class _EmptyMealHint extends StatelessWidget {
  const _EmptyMealHint({required this.slot});

  final MealSlot slot;

  String get _message {
    switch (slot) {
      case MealSlot.breakfast:
        return 'Bụng đang réo kìa! Bạn ăn sáng chưa?';
      case MealSlot.lunch:
        return 'Trưa rồi mà bụng vẫn trống. Ăn gì chưa nè?';
      case MealSlot.dinner:
        return 'Bữa tối đang chờ bạn đó. Ăn gì chưa nè?';
      case MealSlot.snack:
        return 'Thèm chút gì nhẹ nhàng không nào?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          const _HungryBowl(size: 84),
          const SizedBox(height: 2),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tô phở có mặt cười đang "réo": lắc nhẹ vài giây, chạm để lắc lại.
class _HungryBowl extends StatefulWidget {
  const _HungryBowl({this.size = 84});

  final double size;

  @override
  State<_HungryBowl> createState() => _HungryBowlState();
}

class _HungryBowlState extends State<_HungryBowl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    _wobble();
  }

  // Lắc hữu hạn số lần để không giữ khung hình chạy mãi.
  void _wobble() => _controller.repeat(reverse: true, count: 8);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _wobble,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Transform.rotate(
            angle: (t - 0.5) * 0.14,
            child: CustomPaint(
              size: Size(widget.size, widget.size * 0.9),
              painter: _HungryBowlPainter(t),
            ),
          );
        },
      ),
    );
  }
}

class _HungryBowlPainter extends CustomPainter {
  _HungryBowlPainter(this.t);

  final double t;

  static const double _pi = 3.141592653589793;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final rimY = h * 0.45;

    // Sóng âm "grừ grừ" hai bên tô.
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.028
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.orange.withValues(alpha: 0.3 + 0.6 * t);
    for (final r in [0.42, 0.5]) {
      final rect = Rect.fromCircle(center: Offset(cx, h * 0.6), radius: w * r);
      canvas.drawArc(rect, 2.75, 0.7, false, wave);
      canvas.drawArc(rect, -0.35, 0.7, false, wave);
    }

    // Đũa gác trên tô.
    final stick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9A7A58);
    canvas.drawLine(Offset(cx + w * 0.02, rimY), Offset(cx + w * 0.3, h * 0.06), stick);
    canvas.drawLine(Offset(cx + w * 0.1, rimY), Offset(cx + w * 0.37, h * 0.12), stick);

    // Thân tô.
    final bowlRect = Rect.fromLTRB(
      cx - w * 0.34,
      rimY - h * 0.42,
      cx + w * 0.34,
      rimY + h * 0.42,
    );
    final body = Path()
      ..moveTo(cx - w * 0.34, rimY)
      ..arcTo(bowlRect, _pi, -_pi, false)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFF6A95A));

    // Mặt nước dùng.
    final broth = Rect.fromCenter(
      center: Offset(cx, rimY),
      width: w * 0.68,
      height: h * 0.13,
    );
    canvas.drawOval(broth, Paint()..color = const Color(0xFFFFE6BF));
    canvas.drawOval(
      broth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02
        ..color = const Color(0xFFE08A3C),
    );

    // Hơi nóng.
    final steam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.12);
    for (final dx in [-0.14, 0.0]) {
      final x = cx + w * dx - w * 0.06;
      final path = Path()
        ..moveTo(x, rimY - h * 0.07)
        ..cubicTo(x - w * 0.04, rimY - h * 0.15, x + w * 0.04,
            rimY - h * 0.2, x, rimY - h * (0.27 + 0.03 * t));
      canvas.drawPath(path, steam);
    }

    // Mặt: mắt, má hồng, miệng đang réo.
    final dark = Paint()..color = const Color(0xFF5A3A22);
    canvas.drawCircle(Offset(cx - w * 0.12, rimY + h * 0.17), w * 0.03, dark);
    canvas.drawCircle(Offset(cx + w * 0.12, rimY + h * 0.17), w * 0.03, dark);
    final blush = Paint()..color = const Color(0xFFE77D98).withValues(alpha: 0.5);
    canvas.drawCircle(Offset(cx - w * 0.21, rimY + h * 0.23), w * 0.04, blush);
    canvas.drawCircle(Offset(cx + w * 0.21, rimY + h * 0.23), w * 0.04, blush);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, rimY + h * 0.27),
        width: w * 0.11,
        height: h * (0.05 + 0.05 * t),
      ),
      Paint()..color = const Color(0xFF7A3B2E),
    );
  }

  @override
  bool shouldRepaint(covariant _HungryBowlPainter old) => old.t != t;
}

/// Ba banner ảnh bo góc chọn danh mục: Món Việt, Món Tây, Đồ uống.
///
/// Ảnh ưu tiên `assets/images/food/cat_<tên>.jpg` (thả ảnh thật vào là app tự
/// dùng); nếu chưa có thì dùng ảnh nhóm món có sẵn, rồi mới tới nền màu.
class _CategoryTiles extends StatelessWidget {
  const _CategoryTiles({required this.selected, required this.onTap});

  final _Source selected;
  final ValueChanged<_Source> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CategoryTile(
            label: 'Món Việt',
            asset: 'cat_vietnamese',
            fallbackAsset: 'food_mon_nuoc',
            color: AppTheme.orange,
            selected: selected == _Source.vietnam,
            onTap: () => onTap(_Source.vietnam),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CategoryTile(
            label: 'Món Tây',
            asset: 'cat_world',
            fallbackAsset: 'food_tay',
            color: AppTheme.blue,
            selected: selected == _Source.world,
            onTap: () => onTap(_Source.world),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CategoryTile(
            label: 'Đồ uống',
            asset: 'cat_drink',
            fallbackAsset: 'food_drink',
            color: AppTheme.primary,
            selected: selected == _Source.drink,
            onTap: () => onTap(_Source.drink),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.asset,
    required this.fallbackAsset,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String asset;
  final String fallbackAsset;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: _cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/$asset.jpg',
                fit: BoxFit.cover,
                cacheWidth: 500,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/$fallbackAsset.jpg',
                  fit: BoxFit.cover,
                  cacheWidth: 500,
                  errorBuilder: (_, __, ___) => ColoredBox(color: color),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: selected ? 0.35 : 0.6),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
