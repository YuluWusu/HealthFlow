import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../data/auth_scope.dart';
import '../data/nutrition_repository.dart';
import '../models/meal_combo.dart';
import '../models/nutrition.dart';
import '../models/nutrition_goals.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../utils/meal_suggester.dart';
import 'barcode_scanner_screen.dart';
import 'nutrition_goal_sheet.dart';
import 'recipe_builder_screen.dart';
import 'report_export_sheet.dart';

// Các thẻ mới của tab "Hôm nay": macro, xơ/đường/natri, gợi ý bữa, thêm nhanh,
// chuỗi ngày + huy hiệu và lối tắt công cụ.

const List<BoxShadow> _shadow = [
  BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 8)),
];

/// Khung thẻ trắng mờ giống các thẻ khác của màn hình Dinh dưỡng, kèm khoảng
/// cách phía dưới để thẻ bị ẩn thì không để lại khoảng trống.
class NutritionCard extends StatelessWidget {
  const NutritionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.bottom = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _shadow,
        ),
        child: child,
      ),
    );
  }
}

String _n(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
}

String _thousands(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Buổi nên gợi ý lúc này: xem hôm nay thì theo giờ, ngày khác thì buổi đầu
/// tiên còn trống.
MealSlot suggestedSlot(NutritionRepository nutrition) {
  if (nutrition.isToday) {
    final h = DateTime.now().hour;
    if (h < 10) return MealSlot.breakfast;
    if (h < 14) return MealSlot.lunch;
    if (h < 17) return MealSlot.snack;
    return MealSlot.dinner;
  }
  for (final slot in MealSlot.values) {
    if (!nutrition.todayEntries.any((e) => e.slot == slot)) return slot;
  }
  return MealSlot.breakfast;
}

void _toast(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(text),
        action: action,
      ),
    );
}

// ---------------------------------------------------------------------------
// 1 + 10. Mục tiêu macro và chế độ ăn
// ---------------------------------------------------------------------------

class MacroGoalsCard extends StatelessWidget {
  const MacroGoalsCard({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).currentUser;
    final healthGoal = user?.healthGoal ?? 'Giữ dáng';
    final mode = nutrition.effectiveDietMode(healthGoal);
    final targets = nutrition.macroTargets(healthGoal);
    final s = nutrition.summary;
    final custom = nutrition.macroConfig != null;

    return NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mục tiêu macro',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => showNutritionGoalSheet(context, nutrition),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        custom ? '${mode.label} · tự đặt' : mode.label,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.tune_rounded,
                          size: 14, color: AppTheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GoalBar(
            label: 'Đạm',
            value: s.protein,
            target: targets.proteinG.toDouble(),
            unit: 'g',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 10),
          _GoalBar(
            label: 'Carb',
            value: s.carbs,
            target: targets.carbsG.toDouble(),
            unit: 'g',
            color: AppTheme.blue,
            warnWhenOver: true,
          ),
          const SizedBox(height: 10),
          _GoalBar(
            label: 'Béo',
            value: s.fat,
            target: targets.fatG.toDouble(),
            unit: 'g',
            color: AppTheme.orange,
            warnWhenOver: true,
          ),
        ],
      ),
    );
  }
}

/// Một thanh tiến độ "đã ăn / mục tiêu".
class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    this.warnWhenOver = false,
    this.isLimit = false,
    this.footnote,
  });

  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;

  /// Vượt mục tiêu thì đổi sang màu cảnh báo.
  final bool warnWhenOver;

  /// `true` nếu mục tiêu là mức **tối đa** (đường, natri): ghi "tối đa".
  final bool isLimit;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : value / target;
    final over = warnWhenOver && ratio > 1.0;
    final barColor = over ? AppTheme.danger : color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: barColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              '${_thousands(value)} / ${isLimit ? 'tối đa ' : ''}${_thousands(target)} $unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: over ? AppTheme.danger : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: ratio.clamp(0.0, 1.0).toDouble()),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              backgroundColor: barColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 3),
          Text(
            footnote!,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Chất xơ, đường, natri + cảnh báo mặn/ngọt
// ---------------------------------------------------------------------------

class NutrientBalanceCard extends StatelessWidget {
  const NutrientBalanceCard({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  Widget build(BuildContext context) {
    final s = nutrition.summary;
    if (nutrition.todayEntries.isEmpty) return const SizedBox.shrink();

    final user = AuthScope.of(context).currentUser;
    final limits = nutrition.nutrientLimits(user?.healthGoal ?? 'Giữ dáng');

    final warnings = <String>[];
    if (s.sodium > limits.sodiumMaxMg) {
      warnings.add(
        'Hôm nay hơi mặn: ${_thousands(s.sodium)} mg natri, vượt mức ${_thousands(limits.sodiumMaxMg)} mg.',
      );
    }
    if (s.sugar > limits.sugarMaxG) {
      warnings.add(
        'Hôm nay hơi ngọt: ${_n(s.sugar)} g đường, vượt mức ${_n(limits.sugarMaxG)} g.',
      );
    }

    return NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chất xơ · Đường · Natri',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _GoalBar(
            label: 'Chất xơ',
            value: s.fiber,
            target: limits.fiberMinG,
            unit: 'g',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 10),
          _GoalBar(
            label: 'Đường',
            value: s.sugar,
            target: limits.sugarMaxG,
            unit: 'g',
            color: AppTheme.pink,
            warnWhenOver: true,
            isLimit: true,
          ),
          const SizedBox(height: 10),
          _GoalBar(
            label: 'Natri',
            value: s.sodium,
            target: limits.sodiumMaxMg,
            unit: 'mg',
            color: AppTheme.purple,
            warnWhenOver: true,
            isLimit: true,
          ),
          for (final w in warnings) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.lightOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppTheme.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Đường và natri của món Việt là số ước tính từ thành phần.',
            style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Gợi ý bữa theo calo còn lại
// ---------------------------------------------------------------------------

class MealSuggestionCard extends StatelessWidget {
  const MealSuggestionCard({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  Future<void> _add(
    BuildContext context,
    MealSuggestion suggestion,
    MealSlot slot,
  ) async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    await nutrition.addFoods(
      userId: user.id,
      items: suggestion.items,
      slot: slot,
      calorieGoal: nutrition.summary.calorieGoal,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'Đã thêm ${suggestion.title} vào ${slot.label.toLowerCase()}.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).currentUser;
    final healthGoal = user?.healthGoal ?? 'Giữ dáng';
    final s = nutrition.summary;
    final remaining = s.remainingCalories;

    if (remaining <= 0 && nutrition.todayEntries.isNotEmpty) {
      return NutritionCard(
        child: Row(
          children: [
            const Text('✅', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                nutrition.isToday
                    ? 'Bạn đã đủ calo hôm nay. Nghỉ ngơi nhé!'
                    : 'Ngày này đã đủ calo.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final suggestions = nutrition.mealSuggestions(healthGoal);
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final slot = suggestedSlot(nutrition);
    final proteinGap =
        nutrition.macroTargets(healthGoal).proteinG - s.protein;

    return NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gợi ý cho ${slot.label.toLowerCase()}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Còn $remaining kcal'
            '${proteinGap >= 10 ? ' · thiếu ${proteinGap.round()} g đạm' : ''}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          for (final suggestion in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            suggestion.reason,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _add(context, suggestion, slot),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('+ Thêm'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Yêu thích / Gần đây / Hay ăn: thêm một chạm
// ---------------------------------------------------------------------------

class QuickAddCard extends StatefulWidget {
  const QuickAddCard({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  State<QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends State<QuickAddCard> {
  // 0 = Yêu thích, 1 = Gần đây, 2 = Hay ăn. null: tự chọn tab đầu có dữ liệu.
  int? _tab;

  List<FoodItem> _foods(int tab) {
    final n = widget.nutrition;
    switch (tab) {
      case 0:
        return n.favoriteFoods;
      case 1:
        return n.recentFoods;
      default:
        return n.frequentFoods;
    }
  }

  Future<void> _add(FoodItem food) async {
    final user = AuthScope.of(context, listen: false).currentUser;
    if (user == null) return;
    final n = widget.nutrition;
    final slot = suggestedSlot(n);
    final goal = n.summary.calorieGoal;
    HapticFeedback.selectionClick();
    final entry = await n.addFood(
      userId: user.id,
      food: food,
      slot: slot,
      calorieGoal: goal,
    );
    if (!mounted) return;
    _toast(
      context,
      'Đã thêm ${food.name} vào ${slot.label.toLowerCase()}.',
      action: SnackBarAction(
        label: 'Hoàn tác',
        onPressed: () => n.removeEntry(
          userId: user.id,
          entryId: entry.id,
          calorieGoal: goal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.nutrition;
    var tab = _tab;
    if (tab == null) {
      tab = n.favoriteFoods.isNotEmpty ? 0 : (n.recentFoods.isNotEmpty ? 1 : 2);
    }
    final foods = _foods(tab);
    const labels = ['Yêu thích', 'Gần đây', 'Hay ăn'];

    if (n.favoriteFoods.isEmpty &&
        n.recentFoods.isEmpty &&
        n.frequentFoods.isEmpty) {
      return const SizedBox.shrink();
    }

    return NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thêm nhanh',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                ChoiceChip(
                  label: Text(labels[i]),
                  selected: tab == i,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _tab = i),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tab == i ? Colors.white : AppTheme.textPrimary,
                  ),
                  selectedColor: AppTheme.primary,
                  backgroundColor: const Color(0xFFF1F4F2),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (foods.isEmpty)
            Text(
              tab == 0
                  ? 'Chưa có món yêu thích. Mở một món và bấm ♥ để lưu.'
                  : 'Chưa có dữ liệu.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final food in foods)
                  _QuickChip(
                    food: food,
                    favorite: n.isFavorite(food.id),
                    onAdd: () => _add(food),
                    onToggleFavorite: () => n.toggleFavorite(food),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.food,
    required this.favorite,
    required this.onAdd,
    required this.onToggleFavorite,
  });

  final FoodItem food;
  final bool favorite;
  final VoidCallback onAdd;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            onTap: onAdd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(
                  '${food.name} · ${food.calories} kcal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          InkResponse(
            onTap: onToggleFavorite,
            radius: 18,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 10, 6),
              child: Icon(
                favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 17,
                color: favorite ? AppTheme.danger : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Chuỗi ngày, huy hiệu và chúc mừng khi đạt mục tiêu
// ---------------------------------------------------------------------------

class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  Widget build(BuildContext context) {
    final a = nutrition.achievements;
    if (a.badges.isEmpty) return const SizedBox.shrink();

    final streakText = a.currentStreak == 0
        ? 'Ghi một bữa hôm nay để bắt đầu chuỗi'
        : '${a.currentStreak} ngày liên tiếp';

    return NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(a.currentStreak > 0 ? '🔥' : '🌱',
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streakText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kỷ lục ${a.bestStreak} ngày · đạt mục tiêu ${a.goalDays} ngày',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final b in a.badges)
                GestureDetector(
                  onTap: () => _toast(
                    context,
                    b.unlocked
                        ? '${b.title}: ${b.description} ✓'
                        : '${b.title}: ${b.description} (${(b.progress * 100).round()}%)',
                  ),
                  child: Opacity(
                    opacity: b.unlocked ? 1 : 0.35,
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: b.unlocked
                            ? AppTheme.lightOrange
                            : const Color(0xFFE9ECEA),
                        shape: BoxShape.circle,
                      ),
                      child: Text(b.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Không vẽ gì, chỉ lắng nghe: khi hôm nay vừa đạt mục tiêu calo thì phát âm
/// thanh thành công và hiện lời chúc mừng đúng một lần.
class GoalCelebrationListener extends StatefulWidget {
  const GoalCelebrationListener({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  State<GoalCelebrationListener> createState() =>
      _GoalCelebrationListenerState();
}

class _GoalCelebrationListenerState extends State<GoalCelebrationListener> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.nutrition.takePendingCelebration()) {
        AudioService().playSuccess();
        HapticFeedback.mediumImpact();
        _toast(context, '🎉 Tuyệt vời! Bạn đã đạt mục tiêu calo hôm nay.');
      }
    });
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Lối tắt công cụ: mục tiêu, món tự nấu, mã vạch, báo cáo
// ---------------------------------------------------------------------------

class NutritionToolsCard extends StatelessWidget {
  const NutritionToolsCard({super.key, required this.nutrition});

  final NutritionRepository nutrition;

  @override
  Widget build(BuildContext context) {
    return NutritionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ToolTile(
                  icon: Icons.flag_rounded,
                  label: 'Mục tiêu &\nchế độ ăn',
                  color: AppTheme.primary,
                  onTap: () => showNutritionGoalSheet(context, nutrition),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToolTile(
                  icon: Icons.soup_kitchen_rounded,
                  label: 'Món\ntự nấu',
                  color: AppTheme.orange,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RecipeBuilderScreen(nutrition: nutrition),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ToolTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Quét\nmã vạch',
                  color: AppTheme.blue,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BarcodeScannerScreen(nutrition: nutrition),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToolTile(
                  icon: Icons.ios_share_rounded,
                  label: 'Xuất báo cáo\nPDF / CSV',
                  color: AppTheme.purple,
                  onTap: () => showReportExportSheet(context, nutrition),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
