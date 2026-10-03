import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../models/nutrition.dart';
import '../theme/app_theme.dart';
import 'add_food_screen.dart';

/// Màn hình 6 trong bản thiết kế: module Dinh dưỡng.
///
/// Ba thẻ: Hôm nay (tổng năng lượng và các bữa), Thực đơn (nhóm món theo
/// buổi), Thống kê (tỉ lệ các nhóm chất).
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Dinh dưỡng',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 13.5),
            tabs: [
              Tab(text: 'Hôm nay'),
              Tab(text: 'Thực đơn'),
              Tab(text: 'Thống kê'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: app.nutrition,
          builder: (context, _) {
            return TabBarView(
              children: [
                _TodayTab(nutrition: app.nutrition),
                _MealsTab(nutrition: app.nutrition),
                _StatsTab(nutrition: app.nutrition),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tab 1: tổng năng lượng trong ngày và danh sách các bữa ăn.
class _TodayTab extends StatelessWidget {
  final NutritionRepository nutrition;

  const _TodayTab({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final summary = nutrition.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        _EnergyCard(summary: summary),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bữa ăn trong ngày',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _openAddFood(context, nutrition),
              child: const Text(
                'Thêm món',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final slot in MealSlot.values)
          _MealCard(
            slot: slot,
            description: nutrition.mealDescription(slot),
            calories: nutrition.mealCalories(slot),
            entries: nutrition.todayEntries
                .where((entry) => entry.slot == slot)
                .toList(),
            nutrition: nutrition,
          ),
      ],
    );
  }
}

/// Tab 2: gợi ý món ăn theo từng bữa, lấy từ danh mục.
class _MealsTab extends StatelessWidget {
  final NutritionRepository nutrition;

  const _MealsTab({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final suggestions = {
      MealSlot.breakfast: nutrition.search(category: FoodCategory.vietnamese),
      MealSlot.lunch: nutrition.search(category: FoodCategory.asian),
      MealSlot.dinner: nutrition.search(category: FoodCategory.vietnamese),
      MealSlot.snack: nutrition.search(category: FoodCategory.drink),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        for (final entry in suggestions.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Gợi ý ${entry.key.label.toLowerCase()}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          for (final food in entry.value.take(3))
            _FoodRow(
              food: food,
              onTap: () => _openFoodDetail(context, nutrition, food),
              onAdd: () => _addFood(context, nutrition, food, entry.key),
            ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

/// Tab 3: tỉ lệ các nhóm chất và số liệu tổng hợp.
class _StatsTab extends StatelessWidget {
  final NutritionRepository nutrition;

  const _StatsTab({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final summary = nutrition.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng calo nạp vào',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${summary.calories}',
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 5, bottom: 5),
                    child: Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'So với mục tiêu: ${summary.calorieGoal} kcal',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: summary.calorieProgress,
                  minHeight: 8,
                  backgroundColor: AppTheme.lightGreen,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
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
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _MacroPiePainter(
                        proteinPercent: summary.proteinPercent,
                        carbsPercent: summary.carbsPercent,
                        fatPercent: summary.fatPercent,
                      ),
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
                        const SizedBox(height: 10),
                        _LegendRow(
                          color: AppTheme.primary,
                          label: 'Protein',
                          percent: summary.proteinPercent,
                        ),
                        const SizedBox(height: 10),
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
      ],
    );
  }
}

/// Thẻ tổng năng lượng màu xanh ở đầu tab Hôm nay.
class _EnergyCard extends StatelessWidget {
  final NutritionSummary summary;

  const _EnergyCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final remaining = summary.remainingCalories;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng calo hôm nay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${summary.calories}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 6),
                child: Text(
                  '/ ${summary.calorieGoal} kcal',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
              const Spacer(),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFFD36A),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: summary.calorieProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${summary.caloriePercent}% mục tiêu',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11.5,
                ),
              ),
              Text(
                remaining >= 0 ? 'Còn $remaining kcal' : 'Vượt ${-remaining} kcal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thẻ một bữa ăn kèm danh sách món đã thêm.
class _MealCard extends StatelessWidget {
  final MealSlot slot;
  final String description;
  final int calories;
  final List<MealEntry> entries;
  final NutritionRepository nutrition;

  const _MealCard({
    required this.slot,
    required this.description,
    required this.calories,
    required this.entries,
    required this.nutrition,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconFor(slot), color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
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
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant_menu_rounded,
                      size: 15,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.foodName} · ${entry.portionLabel}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.calories} kcal',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _confirmRemove(context, entry),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppTheme.danger,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () => _openAddFood(context, nutrition, slot: slot),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Thêm món vào ${slot.label.toLowerCase()}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
    );
  }

  static IconData _iconFor(MealSlot slot) {
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

  /// Xóa một món khỏi nhật ký, có hỏi lại trước khi xóa.
  Future<void> _confirmRemove(BuildContext context, MealEntry entry) async {
    final auth = AuthScope.of(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa món ăn'),
        content: Text('Bỏ "${entry.foodName}" khỏi ${entry.slot.label.toLowerCase()}?'),
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

/// Một dòng món ăn trong tab Thực đơn.
class _FoodRow extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _FoodRow({
    required this.food,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.lightOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppTheme.orange,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${food.calories} kcal / ${food.servingLabel}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppTheme.primary,
                  size: 26,
                ),
                tooltip: 'Thêm ${food.name}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ba thẻ số liệu nhóm chất.
class _MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
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
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng chú thích cho biểu đồ tròn.
class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double percent;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.percent,
  });

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
  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;

  _MacroPiePainter({
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final strokeWidth = size.width * 0.26;
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

    const startAngle = -1.5708; // Bắt đầu từ đỉnh vòng tròn.
    var currentAngle = startAngle;

    void drawSlice(double percent, Color color) {
      if (percent <= 0) return;
      final sweep = (percent / total) * 6.28319;
      canvas.drawArc(arcRect, currentAngle, sweep, false, paint..color = color);
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
Future<void> _openAddFood(
  BuildContext context,
  NutritionRepository nutrition, {
  MealSlot? slot,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AddFoodScreen(initialSlot: slot ?? MealSlot.breakfast),
    ),
  );
}

/// Mở màn hình chi tiết món ăn.
Future<void> _openFoodDetail(
  BuildContext context,
  NutritionRepository nutrition,
  FoodItem food,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FoodDetailScreen(food: food),
    ),
  );
}

/// Thêm nhanh một món vào bữa chỉ định.
Future<void> _addFood(
  BuildContext context,
  NutritionRepository nutrition,
  FoodItem food,
  MealSlot slot,
) async {
  final auth = AuthScope.of(context, listen: false);
  final user = auth.currentUser;
  if (user == null) return;

  final messenger = ScaffoldMessenger.of(context);

  await nutrition.addFood(
    userId: user.id,
    food: food,
    slot: slot,
    calorieGoal: user.dailyCalorieGoal,
  );

  messenger.showSnackBar(
    SnackBar(content: Text('Đã thêm ${food.name} vào ${slot.label.toLowerCase()}.')),
  );
}
