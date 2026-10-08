import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../data/usda_food_service.dart';
import '../data/vietnam_food_source.dart';
import '../models/nutrition.dart';
import '../theme/app_theme.dart';
import 'add_food_screen.dart';

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
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: const Text(
            'Dinh dưỡng',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TabBar(
                dividerColor: Colors.transparent,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
                indicator: BoxDecoration(
                  color: AppTheme.lightGreen,
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
              physics: const ClampingScrollPhysics(),
              children: [
                _TodayTab(nutrition: app.nutrition),
                _MenuTab(nutrition: app.nutrition),
                _StatsTab(nutrition: app.nutrition),
              ],
            );
          },
        ),
      ),
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
        color: Colors.white,
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
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(action!),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
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
      builder: (scroll) => ListView(
        controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _DayNavigator(nutrition: nutrition),
        const SizedBox(height: 8),
        _EnergyCard(
          summary: summary,
          title: nutrition.isToday
              ? 'Tổng calo hôm nay'
              : nutrition.isFutureDay
                  ? 'Calo dự kiến ${_shortDay(nutrition.selectedDay)}'
                  : 'Tổng calo ${_shortDay(nutrition.selectedDay)}',
        ),
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
      ],
    ),
    );
  }
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
          color: AppTheme.textSecondary,
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
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDay(day),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
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
              foregroundColor: AppTheme.primary,
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
          color: AppTheme.textSecondary,
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
                    Text(
                      '${summary.calories}',
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
                        color: Colors.white.withValues(alpha: 0.18),
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
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: summary.calorieProgress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(104, 104),
                          painter: _RingPainter(progress: value),
                        ),
                        Text(
                          '${summary.caloriePercent}%',
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
  _RingPainter({required this.progress});

  final double progress;

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
      ..color = Colors.white;
    canvas.drawArc(arcRect, -1.5708, 6.28319 * progress.clamp(0.0, 1.0), false, bar);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
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
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
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
                      const SizedBox(width: 4),
                      InkResponse(
                        onTap: () => _confirmRemove(context, entry),
                        radius: 18,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppTheme.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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

  /// Xóa một món khỏi nhật ký, có hỏi lại trước khi xóa.
  Future<void> _confirmRemove(BuildContext context, MealEntry entry) async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Xóa món ăn'),
        content: Text(
          'Bỏ "${entry.foodName}" khỏi ${entry.slot.label.toLowerCase()}?',
        ),
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

    if (confirmed != true) return;
    await nutrition.removeEntry(
      userId: user.id,
      entryId: entry.id,
      calorieGoal: user.dailyCalorieGoal,
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Thực đơn (tìm món Việt Nam từ Excel + quốc tế từ USDA)
// ---------------------------------------------------------------------------

enum _Source { all, vietnam, world }

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
  bool get _wantsUsda => _source != _Source.vietnam && _query.length >= 2;

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
      if (source == _Source.world) {
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
        .where((food) => food.category != FoodCategory.vietnamese);
    final names = offline.map((f) => f.name.toLowerCase()).toSet();
    return [
      ...offline,
      ..._usda.where((f) => !names.contains(f.name.toLowerCase())),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final showVietnam = _source != _Source.world;
    final showWorld = _source != _Source.vietnam;
    final vietnamese = showVietnam ? _vietnamese : const <FoodItem>[];
    final world = showWorld ? _world : const <FoodItem>[];
    final groups = _groups;

    final list = ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
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
        _SegmentedPills(
          labels: const ['Tất cả', 'Món Việt', 'Món Tây'],
          selected: _Source.values.indexOf(_source),
          onChanged: (i) => _setSource(_Source.values[i]),
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
              onAdd: () => _quickAdd(context, food, _slot),
            ),
        ],
        if (showWorld) ...[
          const SizedBox(height: 10),
          _ListHeader(
            icon: Icons.public_rounded,
            title: 'Món Tây & nguyên liệu · USDA',
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
          else if (_query.length < 2)
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
          if (_query.length >= 2 && !_loading && _error == null && world.isEmpty)
            const _InfoBox(
              icon: Icons.search_off_rounded,
              text:
                  'USDA không có kết quả. Thử tên món bằng tiếng Anh, ví dụ "chicken breast".',
            ),
          for (final food in world)
            _FoodRow(
              food: food,
              onTap: () => _openFoodSheet(context, food, _slot),
              onAdd: () => _quickAdd(context, food, _slot),
            ),
        ],
      ],
    );

    return Stack(
      children: [
        list,
        Positioned(
          right: 16,
          bottom: 16,
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
      ],
    );
  }

  String _addedMessage(FoodItem food, MealSlot slot) {
    final base = 'Đã thêm ${food.name} vào ${slot.label.toLowerCase()}';
    if (widget.nutrition.isToday) return '$base.';
    return '$base · ${_formatDay(widget.nutrition.selectedDay)}.';
  }

  Future<void> _quickAdd(
    BuildContext context,
    FoodItem food,
    MealSlot slot,
  ) async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);

    await widget.nutrition.addFood(
      userId: user.id,
      food: food,
      slot: slot,
      calorieGoal: user.dailyCalorieGoal,
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            _addedMessage(food, slot),
          ),
        ),
      );
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
        color: Colors.white,
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
        color: Colors.white,
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
          color: selected ? color.withValues(alpha: 0.14) : Colors.white,
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
              color: AppTheme.textPrimary,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
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
        color: Colors.white.withValues(alpha: 0.7),
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
  });

  final FoodItem food;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final extra = food is CatalogFood ? food as CatalogFood : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
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
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _foodTint(food),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
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
                  color: AppTheme.lightGreen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAdd,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.add_rounded,
                        color: AppTheme.primary,
                        size: 22,
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
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _foodTint(food),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            _foodIcon(food),
                            color: _foodColor(food),
                            size: 29,
                          ),
                        ),
                        const SizedBox(width: 14),
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

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.nutrition});

  final NutritionRepository nutrition;

  @override
  Widget build(BuildContext context) {
    final summary = nutrition.summary;

    return _ScrollTopView(
      builder: (scroll) => ListView(
        controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            nutrition.isToday
                ? 'Thống kê hôm nay'
                : 'Thống kê ${_formatDay(nutrition.selectedDay)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
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
                          color: AppTheme.blue,
                          label: 'Carb',
                          percent: summary.carbsPercent,
                        ),
                        const SizedBox(height: 12),
                        _LegendRow(
                          color: AppTheme.primary,
                          label: 'Protein',
                          percent: summary.proteinPercent,
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroCard(
                label: 'Carb',
                value: '${summary.carbs.toStringAsFixed(0)} g',
                color: AppTheme.blue,
                background: AppTheme.lightBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroCard(
                label: 'Fat',
                value: '${summary.fat.toStringAsFixed(0)} g',
                color: AppTheme.orange,
                background: AppTheme.lightOrange,
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
        const SizedBox(height: 16),
        _InsightCard(summary: summary),
      ],
    ),
    );
  }
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
        color: color.withValues(alpha: 0.1),
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
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

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
            child: Icon(Icons.circle, size: 12, color: color),
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

    drawSlice(carbsPercent, AppTheme.blue);
    drawSlice(proteinPercent, AppTheme.primary);
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
